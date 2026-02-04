#Requires -Version 5.1
<#
.SYNOPSIS
    Health check script for ra-infrastructure services.

.DESCRIPTION
    Monitors the health of Docker containers and database connectivity.
    Sends email alerts on failure with rate limiting.

.PARAMETER SkipEmail
    Skip sending email notifications.

.PARAMETER Verbose
    Show detailed output.

.EXAMPLE
    .\health-check.ps1

.EXAMPLE
    .\health-check.ps1 -SkipEmail
#>

[CmdletBinding()]
param(
    [switch]$SkipEmail
)

$ErrorActionPreference = "Continue"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

# Load centralized infrastructure config
. "$PSScriptRoot\Load-InfraConfig.ps1"
$script:LogDir = Join-Path $RepoRoot "logs"
$script:LogFile = Join-Path $script:LogDir "health-check.log"
$script:StateFile = Join-Path $script:LogDir ".health-check-state.json"
$script:ConfigFile = Join-Path $RepoRoot "config\monitoring.env"

# Ensure logs directory exists
if (-not (Test-Path $script:LogDir)) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
}

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to log file
    Add-Content -Path $script:LogFile -Value $logEntry

    # Write to console with colors
    $colors = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
    }

    $symbols = @{
        "INFO"    = "[*]"
        "SUCCESS" = "[+]"
        "WARNING" = "[!]"
        "ERROR"   = "[X]"
    }

    Write-Host "$($symbols[$Level]) $Message" -ForegroundColor $colors[$Level]
}

#endregion

#region State Management

function Get-CheckState {
    if (Test-Path $script:StateFile) {
        try {
            return Get-Content $script:StateFile -Raw | ConvertFrom-Json
        }
        catch {
            return @{}
        }
    }
    return @{}
}

function Save-CheckState {
    param([hashtable]$State)

    $State | ConvertTo-Json | Set-Content $script:StateFile
}

function Get-LastAlertTime {
    param([string]$CheckName)

    $state = Get-CheckState
    if ($state.$CheckName) {
        return [DateTime]::Parse($state.$CheckName)
    }
    return $null
}

function Set-LastAlertTime {
    param([string]$CheckName)

    $state = Get-CheckState
    if ($state -is [PSCustomObject]) {
        $state = @{}
    }
    $state[$CheckName] = (Get-Date).ToString("o")
    Save-CheckState $state
}

function Clear-AlertState {
    param([string]$CheckName)

    $state = Get-CheckState
    if ($state -is [PSCustomObject]) {
        $hashtable = @{}
        $state.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
        $state = $hashtable
    }
    if ($state.ContainsKey($CheckName)) {
        $state.Remove($CheckName)
        Save-CheckState $state
    }
}

#endregion

#region Email Functions

function Get-EmailConfig {
    if (-not (Test-Path $script:ConfigFile)) {
        Write-Log "Email config not found: $script:ConfigFile" -Level WARNING
        return $null
    }

    $config = @{}
    Get-Content $script:ConfigFile | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.*)$") {
            $config[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }

    return $config
}

function Send-AlertEmail {
    param(
        [string]$Subject,
        [string]$Body,
        [string]$CheckName,
        [switch]$IsRecovery
    )

    if ($SkipEmail) {
        Write-Log "Email skipped (SkipEmail flag set)" -Level INFO
        return
    }

    $config = Get-EmailConfig
    if (-not $config) {
        Write-Log "Cannot send email - no config" -Level WARNING
        return
    }

    # Rate limiting (skip for recovery emails)
    if (-not $IsRecovery) {
        $rateLimitMinutes = if ($config.ALERT_RATE_LIMIT_MINUTES) { [int]$config.ALERT_RATE_LIMIT_MINUTES } else { 15 }
        $lastAlert = Get-LastAlertTime -CheckName $CheckName

        if ($lastAlert) {
            $elapsed = (Get-Date) - $lastAlert
            if ($elapsed.TotalMinutes -lt $rateLimitMinutes) {
                Write-Log "Rate limited: last alert for '$CheckName' was $([int]$elapsed.TotalMinutes) minutes ago" -Level INFO
                return
            }
        }
    }

    try {
        $smtpServer = $config.SMTP_HOST
        $smtpPort = [int]$config.SMTP_PORT
        $smtpUser = $config.SMTP_USER
        $smtpPassword = $config.SMTP_PASSWORD
        $alertEmail = $config.ALERT_EMAIL

        if (-not ($smtpServer -and $smtpUser -and $smtpPassword -and $alertEmail)) {
            Write-Log "Incomplete email configuration" -Level WARNING
            return
        }

        $securePassword = ConvertTo-SecureString $smtpPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)

        $mailParams = @{
            From       = $smtpUser
            To         = $alertEmail
            Subject    = $Subject
            Body       = $Body
            SmtpServer = $smtpServer
            Port       = $smtpPort
            UseSsl     = $true
            Credential = $credential
        }

        Send-MailMessage @mailParams
        Write-Log "Email sent: $Subject" -Level SUCCESS

        if (-not $IsRecovery) {
            Set-LastAlertTime -CheckName $CheckName
        }
        else {
            Clear-AlertState -CheckName $CheckName
        }
    }
    catch {
        Write-Log "Failed to send email: $_" -Level ERROR
    }
}

#endregion

#region Container Configuration

# All infrastructure containers with their properties
# Critical: Failure = infrastructure down, alerts immediately
# Optional: Failure = degraded service, warning only
$script:Containers = @(
    @{
        Name        = $env:RA_POSTGRES_CONTAINER
        DisplayName = "PostgreSQL"
        Critical    = $true
        HasHealth   = $true
        TestQuery   = { docker exec $env:RA_POSTGRES_CONTAINER psql -U $env:RA_POSTGRES_USER -d $env:RA_POSTGRES_DB -c "SELECT 1" 2>&1 }
    },
    @{
        Name        = $env:RA_MYSQL_CONTAINER
        DisplayName = "MySQL"
        Critical    = $true
        HasHealth   = $true
        TestQuery   = $null  # Health check via Docker is sufficient
    },
    @{
        Name        = $env:RA_TRAEFIK_CONTAINER
        DisplayName = "Traefik Proxy"
        Critical    = $true
        HasHealth   = $false
        HttpCheck   = "http://localhost:$($env:RA_TRAEFIK_PORT)/api/overview"
    },
    @{
        Name        = $env:RA_GATUS_CONTAINER
        DisplayName = "Gatus Monitor"
        Critical    = $false
        HasHealth   = $false
        HttpCheck   = "http://localhost:$($env:RA_GATUS_PORT)/health"
    },
    @{
        Name        = $env:RA_DASHBOARD_CONTAINER
        DisplayName = "Selfwize Dashboard"
        Critical    = $false
        HasHealth   = $false
        HttpCheck   = "http://localhost:$($env:RA_DASHBOARD_PORT)"
    },
    @{
        Name        = $env:RA_PGADMIN_CONTAINER
        DisplayName = "pgAdmin"
        Critical    = $false
        HasHealth   = $false
        HttpCheck   = "http://localhost:$($env:RA_PGADMIN_PORT)"
    },
    @{
        Name        = $env:RA_SNIPEIT_CONTAINER
        DisplayName = "Snipe-IT"
        Critical    = $false
        HasHealth   = $false
        HttpCheck   = "http://localhost:$($env:RA_SNIPEIT_PORT)"
    },
    @{
        Name        = $env:RA_FASTEN_CONTAINER
        DisplayName = "Fasten Health"
        Critical    = $false
        HasHealth   = $false
    },
    @{
        Name        = $env:RA_EVENTLOG_CONTAINER
        DisplayName = "Event Log"
        Critical    = $false
        HasHealth   = $false
        HttpCheck   = "http://localhost:$($env:RA_EVENTLOG_PORT)"
    },
    @{
        Name        = $env:RA_EVENTLOG_DB_CONTAINER
        DisplayName = "Event Log DB"
        Critical    = $false
        HasHealth   = $true
        TestQuery   = $null
    }
)

#endregion

#region Health Checks

function Test-DockerDesktop {
    Write-Log "Checking Docker Desktop..." -Level INFO

    $startTime = Get-Date

    try {
        $dockerInfo = docker info 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Docker Desktop is not running (${duration}ms)" -Level ERROR
            return @{
                Name     = "DockerDesktop"
                Success  = $false
                Message  = "Docker Desktop is not running"
                Duration = $duration
                Critical = $true
            }
        }

        Write-Log "Docker Desktop is running (${duration}ms)" -Level SUCCESS
        return @{
            Name     = "DockerDesktop"
            Success  = $true
            Message  = "Docker Desktop is running"
            Duration = $duration
            Critical = $true
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Write-Log "Docker check failed: $_ (${duration}ms)" -Level ERROR
        return @{
            Name     = "DockerDesktop"
            Success  = $false
            Message  = "Docker check failed: $_"
            Duration = $duration
            Critical = $true
        }
    }
}

function Test-ContainerRunning {
    param(
        [string]$ContainerName,
        [string]$DisplayName,
        [bool]$Critical = $true
    )

    $label = if ($DisplayName) { $DisplayName } else { $ContainerName }
    Write-Log "Checking container '$label'..." -Level INFO

    $startTime = Get-Date

    try {
        $state = docker inspect --format='{{.State.Running}}' $ContainerName 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($LASTEXITCODE -ne 0 -or $state -ne "true") {
            $level = if ($Critical) { "ERROR" } else { "WARNING" }
            Write-Log "Container '$label' is not running (${duration}ms)" -Level $level
            return @{
                Name     = $label
                Success  = $false
                Message  = "Container is not running"
                Duration = $duration
                Critical = $Critical
            }
        }

        Write-Log "Container '$label' is running (${duration}ms)" -Level SUCCESS
        return @{
            Name     = $label
            Success  = $true
            Message  = "Container is running"
            Duration = $duration
            Critical = $Critical
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        $level = if ($Critical) { "ERROR" } else { "WARNING" }
        Write-Log "Container check failed: $_ (${duration}ms)" -Level $level
        return @{
            Name     = $label
            Success  = $false
            Message  = "Container check failed: $_"
            Duration = $duration
            Critical = $Critical
        }
    }
}

function Test-ContainerHealth {
    param(
        [string]$ContainerName,
        [string]$DisplayName,
        [bool]$Critical = $true
    )

    $label = if ($DisplayName) { $DisplayName } else { $ContainerName }
    Write-Log "Checking health of '$label'..." -Level INFO

    $startTime = Get-Date

    try {
        $health = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($LASTEXITCODE -ne 0) {
            $level = if ($Critical) { "ERROR" } else { "WARNING" }
            Write-Log "Health check failed for '$label' (${duration}ms)" -Level $level
            return @{
                Name     = "${label} Health"
                Success  = $false
                Message  = "Could not get health status"
                Duration = $duration
                Critical = $Critical
            }
        }

        if ($health -ne "healthy") {
            $level = if ($Critical) { "ERROR" } else { "WARNING" }
            Write-Log "Container '$label' is unhealthy: $health (${duration}ms)" -Level $level
            return @{
                Name     = "${label} Health"
                Success  = $false
                Message  = "Health status: $health"
                Duration = $duration
                Critical = $Critical
            }
        }

        Write-Log "Container '$label' is healthy (${duration}ms)" -Level SUCCESS
        return @{
            Name     = "${label} Health"
            Success  = $true
            Message  = "Container is healthy"
            Duration = $duration
            Critical = $Critical
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        $level = if ($Critical) { "ERROR" } else { "WARNING" }
        Write-Log "Health check failed: $_ (${duration}ms)" -Level $level
        return @{
            Name     = "${label} Health"
            Success  = $false
            Message  = "Health check failed: $_"
            Duration = $duration
            Critical = $Critical
        }
    }
}

function Test-HttpEndpoint {
    param(
        [string]$Url,
        [string]$DisplayName,
        [bool]$Critical = $false,
        [int]$TimeoutSeconds = 10
    )

    Write-Log "Checking HTTP endpoint '$DisplayName'..." -Level INFO

    $startTime = Get-Date

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
            Write-Log "HTTP endpoint '$DisplayName' is responsive (${duration}ms)" -Level SUCCESS
            return @{
                Name     = "${DisplayName} HTTP"
                Success  = $true
                Message  = "HTTP $($response.StatusCode)"
                Duration = $duration
                Critical = $Critical
            }
        }
        else {
            $level = if ($Critical) { "ERROR" } else { "WARNING" }
            Write-Log "HTTP endpoint '$DisplayName' returned $($response.StatusCode) (${duration}ms)" -Level $level
            return @{
                Name     = "${DisplayName} HTTP"
                Success  = $false
                Message  = "HTTP $($response.StatusCode)"
                Duration = $duration
                Critical = $Critical
            }
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        $level = if ($Critical) { "ERROR" } else { "WARNING" }
        Write-Log "HTTP check failed for '$DisplayName': $_ (${duration}ms)" -Level $level
        return @{
            Name     = "${DisplayName} HTTP"
            Success  = $false
            Message  = "HTTP check failed: $_"
            Duration = $duration
            Critical = $Critical
        }
    }
}

function Test-DatabaseQuery {
    param(
        [scriptblock]$Query,
        [string]$DisplayName,
        [bool]$Critical = $true
    )

    Write-Log "Testing database query for '$DisplayName'..." -Level INFO

    $startTime = Get-Date

    try {
        $result = & $Query
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($LASTEXITCODE -ne 0) {
            $level = if ($Critical) { "ERROR" } else { "WARNING" }
            Write-Log "Database query failed for '$DisplayName' (${duration}ms)" -Level $level
            return @{
                Name     = "${DisplayName} Query"
                Success  = $false
                Message  = "Database query failed"
                Duration = $duration
                Critical = $Critical
            }
        }

        Write-Log "Database query successful for '$DisplayName' (${duration}ms)" -Level SUCCESS
        return @{
            Name     = "${DisplayName} Query"
            Success  = $true
            Message  = "Database accepts queries"
            Duration = $duration
            Critical = $Critical
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        $level = if ($Critical) { "ERROR" } else { "WARNING" }
        Write-Log "Database query failed: $_ (${duration}ms)" -Level $level
        return @{
            Name     = "${DisplayName} Query"
            Success  = $false
            Message  = "Database query failed: $_"
            Duration = $duration
            Critical = $Critical
        }
    }
}

#endregion

#region Main

function Invoke-HealthChecks {
    Write-Log "Starting health checks..." -Level INFO
    Write-Log "=" * 50 -Level INFO

    $results = @()

    # Check 1: Docker Desktop (prerequisite for all other checks)
    $results += Test-DockerDesktop
    if (-not $results[-1].Success) {
        Write-Log "Docker not running - skipping remaining checks" -Level WARNING
        return $results
    }

    # Check all configured containers
    foreach ($container in $script:Containers) {
        # Check if container is running
        $runResult = Test-ContainerRunning `
            -ContainerName $container.Name `
            -DisplayName $container.DisplayName `
            -Critical $container.Critical

        $results += $runResult

        # Skip further checks for this container if not running
        if (-not $runResult.Success) {
            continue
        }

        # Check Docker health status if container has healthcheck
        if ($container.HasHealth) {
            $results += Test-ContainerHealth `
                -ContainerName $container.Name `
                -DisplayName $container.DisplayName `
                -Critical $container.Critical
        }

        # Run database query test if defined
        if ($container.TestQuery) {
            $results += Test-DatabaseQuery `
                -Query $container.TestQuery `
                -DisplayName $container.DisplayName `
                -Critical $container.Critical
        }

        # Check HTTP endpoint if defined
        if ($container.HttpCheck) {
            $results += Test-HttpEndpoint `
                -Url $container.HttpCheck `
                -DisplayName $container.DisplayName `
                -Critical $container.Critical
        }
    }

    return $results
}

function Send-Alerts {
    param([array]$Results)

    $hostname = $env:COMPUTERNAME
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    foreach ($result in $Results) {
        # Only send alerts for critical services
        if (-not $result.Critical) {
            continue
        }

        if (-not $result.Success) {
            $subject = "[CRITICAL] ra-infrastructure - $($result.Name) Failed"
            $body = @"
CRITICAL Health Check Alert

Host: $hostname
Time: $timestamp
Check: $($result.Name)
Status: FAILED
Message: $($result.Message)
Duration: $($result.Duration)ms
Severity: CRITICAL

Suggested Actions:
1. Check Docker Desktop is running
2. Run: docker-compose -f docker/docker-compose.yml ps
3. Check logs: docker-compose -f docker/docker-compose.yml logs
4. Run health check: .\scripts\health-check.ps1 -SkipEmail

--
ra-infrastructure Health Monitor
"@
            Send-AlertEmail -Subject $subject -Body $body -CheckName $result.Name
        }
        else {
            # Check if this was previously failing - send recovery email
            $state = Get-CheckState
            $checkKey = $result.Name
            if ($state.$checkKey) {
                $subject = "[RECOVERY] ra-infrastructure - $($result.Name) Recovered"
                $body = @"
Health Check Recovery

Host: $hostname
Time: $timestamp
Check: $($result.Name)
Status: RECOVERED
Message: $($result.Message)

The service has recovered and is now healthy.

--
ra-infrastructure Health Monitor
"@
                Send-AlertEmail -Subject $subject -Body $body -CheckName $result.Name -IsRecovery
            }
        }
    }
}

function Show-Summary {
    param([array]$Results)

    Write-Host ""
    Write-Host "=" * 60
    Write-Host "  Health Check Summary"
    Write-Host "=" * 60
    Write-Host ""

    $criticalPassed = $true
    $allPassed = $true
    $criticalCount = 0
    $optionalCount = 0
    $criticalFailed = 0
    $optionalFailed = 0

    # Group results by criticality
    $criticalResults = $Results | Where-Object { $_.Critical -eq $true }
    $optionalResults = $Results | Where-Object { $_.Critical -eq $false }

    # Display critical services
    if ($criticalResults) {
        Write-Host "  CRITICAL SERVICES" -ForegroundColor White
        Write-Host "  -----------------" -ForegroundColor DarkGray
        foreach ($result in $criticalResults) {
            $criticalCount++
            $status = if ($result.Success) { "OK" } else { "FAILED" }
            $color = if ($result.Success) { "Green" } else { "Red" }
            $duration = if ($result.Duration) { " ($([int]$result.Duration)ms)" } else { "" }
            Write-Host ("  {0,-35} [{1}]{2}" -f $result.Name, $status, $duration) -ForegroundColor $color

            if (-not $result.Success) {
                $criticalPassed = $false
                $allPassed = $false
                $criticalFailed++
            }
        }
        Write-Host ""
    }

    # Display optional services
    if ($optionalResults) {
        Write-Host "  OPTIONAL SERVICES" -ForegroundColor White
        Write-Host "  -----------------" -ForegroundColor DarkGray
        foreach ($result in $optionalResults) {
            $optionalCount++
            $status = if ($result.Success) { "OK" } else { "WARN" }
            $color = if ($result.Success) { "Green" } else { "Yellow" }
            $duration = if ($result.Duration) { " ($([int]$result.Duration)ms)" } else { "" }
            Write-Host ("  {0,-35} [{1}]{2}" -f $result.Name, $status, $duration) -ForegroundColor $color

            if (-not $result.Success) {
                $allPassed = $false
                $optionalFailed++
            }
        }
        Write-Host ""
    }

    # Summary line
    Write-Host "=" * 60
    $totalChecks = $Results.Count
    $passedChecks = ($Results | Where-Object { $_.Success }).Count

    if ($criticalPassed -and $allPassed) {
        Write-Host "  RESULT: ALL CHECKS PASSED ($passedChecks/$totalChecks)" -ForegroundColor Green
        Write-Log "All $totalChecks health checks passed" -Level SUCCESS
    }
    elseif ($criticalPassed) {
        Write-Host "  RESULT: DEGRADED - $optionalFailed optional service(s) down ($passedChecks/$totalChecks passed)" -ForegroundColor Yellow
        Write-Log "Infrastructure operational but degraded: $optionalFailed optional service(s) failed" -Level WARNING
    }
    else {
        Write-Host "  RESULT: CRITICAL FAILURE - $criticalFailed critical service(s) down ($passedChecks/$totalChecks passed)" -ForegroundColor Red
        Write-Log "CRITICAL: $criticalFailed critical service(s) failed" -Level ERROR
    }
    Write-Host "=" * 60
    Write-Host ""

    # Return $true only if all critical services are healthy
    return $criticalPassed
}

# Main execution
function Main {
    $startTime = Get-Date

    $containerCount = $script:Containers.Count
    $criticalCount = ($script:Containers | Where-Object { $_.Critical }).Count
    $optionalCount = $containerCount - $criticalCount

    Write-Host ""
    Write-Host "=" * 60
    Write-Host "  ra-infrastructure Health Check"
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "  Checking $containerCount containers ($criticalCount critical, $optionalCount optional)"
    Write-Host "=" * 60
    Write-Host ""

    # Run health checks
    $results = Invoke-HealthChecks

    # Send alerts for failures
    Send-Alerts -Results $results

    # Show summary
    $success = Show-Summary -Results $results

    $duration = ((Get-Date) - $startTime).TotalSeconds
    Write-Log "Health check completed in $([math]::Round($duration, 2)) seconds" -Level INFO

    if ($success) {
        exit 0
    }
    else {
        exit 1
    }
}

Main

#endregion
