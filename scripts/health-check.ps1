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
            }
        }

        Write-Log "Docker Desktop is running (${duration}ms)" -Level SUCCESS
        return @{
            Name     = "DockerDesktop"
            Success  = $true
            Message  = "Docker Desktop is running"
            Duration = $duration
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
        }
    }
}

function Test-ContainerRunning {
    param([string]$ContainerName)

    Write-Log "Checking container '$ContainerName'..." -Level INFO

    $startTime = Get-Date

    try {
        $state = docker inspect --format='{{.State.Running}}' $ContainerName 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($LASTEXITCODE -ne 0 -or $state -ne "true") {
            Write-Log "Container '$ContainerName' is not running (${duration}ms)" -Level ERROR
            return @{
                Name     = "Container_$ContainerName"
                Success  = $false
                Message  = "Container '$ContainerName' is not running"
                Duration = $duration
            }
        }

        Write-Log "Container '$ContainerName' is running (${duration}ms)" -Level SUCCESS
        return @{
            Name     = "Container_$ContainerName"
            Success  = $true
            Message  = "Container '$ContainerName' is running"
            Duration = $duration
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Write-Log "Container check failed: $_ (${duration}ms)" -Level ERROR
        return @{
            Name     = "Container_$ContainerName"
            Success  = $false
            Message  = "Container check failed: $_"
            Duration = $duration
        }
    }
}

function Test-ContainerHealth {
    param([string]$ContainerName)

    Write-Log "Checking health of '$ContainerName'..." -Level INFO

    $startTime = Get-Date

    try {
        $health = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Health check failed for '$ContainerName' (${duration}ms)" -Level ERROR
            return @{
                Name     = "Health_$ContainerName"
                Success  = $false
                Message  = "Could not get health status"
                Duration = $duration
            }
        }

        if ($health -ne "healthy") {
            Write-Log "Container '$ContainerName' is unhealthy: $health (${duration}ms)" -Level ERROR
            return @{
                Name     = "Health_$ContainerName"
                Success  = $false
                Message  = "Container health status: $health"
                Duration = $duration
            }
        }

        Write-Log "Container '$ContainerName' is healthy (${duration}ms)" -Level SUCCESS
        return @{
            Name     = "Health_$ContainerName"
            Success  = $true
            Message  = "Container is healthy"
            Duration = $duration
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Write-Log "Health check failed: $_ (${duration}ms)" -Level ERROR
        return @{
            Name     = "Health_$ContainerName"
            Success  = $false
            Message  = "Health check failed: $_"
            Duration = $duration
        }
    }
}

function Test-DatabaseConnection {
    Write-Log "Checking database connection..." -Level INFO

    $startTime = Get-Date

    try {
        $result = docker exec inventory-db psql -U inventory -d inventory -c "SELECT 1" 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Database connection failed (${duration}ms)" -Level ERROR
            return @{
                Name     = "DatabaseConnection"
                Success  = $false
                Message  = "Database connection failed"
                Duration = $duration
            }
        }

        Write-Log "Database connection successful (${duration}ms)" -Level SUCCESS
        return @{
            Name     = "DatabaseConnection"
            Success  = $true
            Message  = "Database accepts connections"
            Duration = $duration
        }
    }
    catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Write-Log "Database check failed: $_ (${duration}ms)" -Level ERROR
        return @{
            Name     = "DatabaseConnection"
            Success  = $false
            Message  = "Database check failed: $_"
            Duration = $duration
        }
    }
}

#endregion

#region Main

function Invoke-HealthChecks {
    Write-Log "Starting health checks..." -Level INFO
    Write-Log "=" * 50 -Level INFO

    $results = @()
    $previousState = Get-CheckState

    # Check 1: Docker Desktop
    $results += Test-DockerDesktop
    if (-not $results[-1].Success) {
        # If Docker is down, skip remaining checks
        Write-Log "Docker not running - skipping remaining checks" -Level WARNING
        return $results
    }

    # Check 2: inventory-db container running
    $results += Test-ContainerRunning -ContainerName "inventory-db"
    if (-not $results[-1].Success) {
        return $results
    }

    # Check 3: inventory-db health
    $results += Test-ContainerHealth -ContainerName "inventory-db"

    # Check 4: Database connection
    $results += Test-DatabaseConnection

    # Check 5: pgAdmin container (optional - warning only)
    $pgadminResult = Test-ContainerRunning -ContainerName "inventory-pgadmin"
    if (-not $pgadminResult.Success) {
        Write-Log "pgAdmin container not running (optional)" -Level WARNING
    }
    # Don't add to results as it's optional

    return $results
}

function Send-Alerts {
    param([array]$Results)

    $hostname = $env:COMPUTERNAME
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    foreach ($result in $Results) {
        if (-not $result.Success) {
            $subject = "[ALERT] ra-infrastructure - $($result.Name) Failed"
            $body = @"
Health Check Alert

Host: $hostname
Time: $timestamp
Check: $($result.Name)
Status: FAILED
Message: $($result.Message)
Duration: $($result.Duration)ms

Suggested Actions:
1. Check Docker Desktop is running
2. Run: docker-compose -f docker/docker-compose.yml ps
3. Check logs: docker-compose -f docker/docker-compose.yml logs

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
    Write-Host "=" * 50
    Write-Host "  Health Check Summary"
    Write-Host "=" * 50
    Write-Host ""

    $allPassed = $true

    foreach ($result in $Results) {
        $status = if ($result.Success) { "OK" } else { "FAILED" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        Write-Host ("  {0,-30} [{1}]" -f $result.Name, $status) -ForegroundColor $color

        if (-not $result.Success) {
            $allPassed = $false
        }
    }

    Write-Host ""

    if ($allPassed) {
        Write-Log "All health checks passed" -Level SUCCESS
    }
    else {
        Write-Log "One or more health checks failed" -Level ERROR
    }

    return $allPassed
}

# Main execution
function Main {
    $startTime = Get-Date

    Write-Host ""
    Write-Host "=" * 50
    Write-Host "  ra-infrastructure Health Check"
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "=" * 50
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
