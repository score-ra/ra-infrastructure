#Requires -Version 5.1
<#
.SYNOPSIS
    ra-infrastructure startup and verification script.

.DESCRIPTION
    This script verifies that all infrastructure components are ready:
    - Docker Desktop is running
    - PostgreSQL container is healthy
    - CLI is installed
    - Database migrations are applied
    - Database connection works

    Optionally sends email alerts on failure.

.PARAMETER SkipMigrations
    Skip running database migrations.

.PARAMETER SendAlert
    Send email alert if startup verification fails.

.PARAMETER Verbose
    Show detailed output.

.EXAMPLE
    .\verify-startup.ps1

.EXAMPLE
    .\verify-startup.ps1 -SkipMigrations

.EXAMPLE
    .\verify-startup.ps1 -SendAlert
#>

[CmdletBinding()]
param(
    [switch]$SkipMigrations,
    [switch]$SendAlert
)

$ErrorActionPreference = "Stop"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:DockerComposePath = Join-Path $RepoRoot "docker\docker-compose.yml"
$script:LogDir = Join-Path $script:RepoRoot "logs"
$script:LogFile = Join-Path $script:LogDir "startup.log"
$script:ConfigFile = Join-Path $script:RepoRoot "config\monitoring.env"

# Ensure logs directory exists
if (-not (Test-Path $script:LogDir)) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
}

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
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $colors = @{
        "Info"    = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error"   = "Red"
    }

    $symbols = @{
        "Info"    = "[*]"
        "Success" = "[+]"
        "Warning" = "[!]"
        "Error"   = "[X]"
    }

    Write-Host "$($symbols[$Type]) $Message" -ForegroundColor $colors[$Type]

    # Also write to log file
    $levelMap = @{ "Info" = "INFO"; "Success" = "SUCCESS"; "Warning" = "WARNING"; "Error" = "ERROR" }
    Write-Log -Message $Message -Level $levelMap[$Type]
}

#region Email Functions

function Get-EmailConfig {
    if (-not (Test-Path $script:ConfigFile)) {
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

function Send-StartupFailureAlert {
    param(
        [hashtable]$Results
    )

    if (-not $SendAlert) {
        return
    }

    $config = Get-EmailConfig
    if (-not $config) {
        Write-Status "Cannot send email - no config file" -Type Warning
        return
    }

    $hostname = $env:COMPUTERNAME
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $failedChecks = ($Results.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { "  - $($_.Key)" }) -join "`n"

    $subject = "[ALERT] ra-infrastructure - Startup Verification Failed"
    $body = @"
Startup Verification Alert

Host: $hostname
Time: $timestamp

The following checks failed:
$failedChecks

Suggested Actions:
1. Check Docker Desktop is running
2. Run: .\scripts\verify-startup.ps1
3. Check logs: logs\startup.log

--
ra-infrastructure Startup Monitor
"@

    try {
        $smtpServer = $config.SMTP_HOST
        $smtpPort = [int]$config.SMTP_PORT
        $smtpUser = $config.SMTP_USER
        $smtpPassword = $config.SMTP_PASSWORD
        $alertEmail = $config.ALERT_EMAIL

        if (-not ($smtpServer -and $smtpUser -and $smtpPassword -and $alertEmail)) {
            Write-Status "Incomplete email configuration" -Type Warning
            return
        }

        $securePassword = ConvertTo-SecureString $smtpPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)

        $mailParams = @{
            From       = $smtpUser
            To         = $alertEmail
            Subject    = $subject
            Body       = $body
            SmtpServer = $smtpServer
            Port       = $smtpPort
            UseSsl     = $true
            Credential = $credential
        }

        Send-MailMessage @mailParams
        Write-Status "Alert email sent" -Type Success
    }
    catch {
        Write-Status "Failed to send email: $_" -Type Error
    }
}

#endregion

function Test-DockerDesktop {
    Write-Status "Checking Docker Desktop..." -Type Info

    try {
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Docker Desktop is not running" -Type Error
            Write-Status "Please start Docker Desktop and try again" -Type Warning
            return $false
        }
        Write-Status "Docker Desktop is running" -Type Success
        return $true
    }
    catch {
        Write-Status "Docker is not installed or not in PATH" -Type Error
        return $false
    }
}

function Test-DockerContainers {
    Write-Status "Checking Docker containers..." -Type Info

    $composeStatus = docker-compose -f $script:DockerComposePath ps --format json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Status "No containers found, starting them..." -Type Warning
        return Start-DockerContainers
    }

    # Check if postgres container is running and healthy
    $containers = docker-compose -f $script:DockerComposePath ps --format json | ConvertFrom-Json

    if (-not $containers) {
        Write-Status "No containers found, starting them..." -Type Warning
        return Start-DockerContainers
    }

    $postgres = $containers | Where-Object { $_.Name -like "*postgres*" -or $_.Service -eq "postgres" }

    if (-not $postgres) {
        Write-Status "PostgreSQL container not found, starting..." -Type Warning
        return Start-DockerContainers
    }

    if ($postgres.State -ne "running") {
        Write-Status "PostgreSQL container not running (state: $($postgres.State)), starting..." -Type Warning
        return Start-DockerContainers
    }

    # Check health status
    $health = docker inspect --format='{{.State.Health.Status}}' inventory-db 2>&1
    if ($health -ne "healthy") {
        Write-Status "PostgreSQL container not healthy (status: $health), waiting..." -Type Warning
        return Wait-ForPostgres
    }

    Write-Status "PostgreSQL container is running and healthy" -Type Success
    return $true
}

function Start-DockerContainers {
    Write-Status "Starting Docker containers..." -Type Info

    docker-compose -f $script:DockerComposePath up -d

    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to start Docker containers" -Type Error
        return $false
    }

    return Wait-ForPostgres
}

function Wait-ForPostgres {
    Write-Status "Waiting for PostgreSQL to be ready..." -Type Info

    $maxAttempts = 30
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        $health = docker inspect --format='{{.State.Health.Status}}' inventory-db 2>&1

        if ($health -eq "healthy") {
            Write-Status "PostgreSQL is ready" -Type Success
            return $true
        }

        $attempt++
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    Write-Status "PostgreSQL did not become healthy within timeout" -Type Error
    return $false
}

function Test-PythonEnvironment {
    Write-Status "Checking Python environment..." -Type Info

    try {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Python is not installed or not in PATH" -Type Error
            return $false
        }

        # Check Python version is 3.11+
        if ($pythonVersion -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]

            if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 11)) {
                Write-Status "Python 3.11+ required, found: $pythonVersion" -Type Error
                return $false
            }
        }

        Write-Status "Python version: $pythonVersion" -Type Success
        return $true
    }
    catch {
        Write-Status "Error checking Python: $_" -Type Error
        return $false
    }
}

function Test-CLIInstalled {
    Write-Status "Checking CLI installation..." -Type Info

    try {
        $invVersion = inv --help 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "CLI (inv) is not installed" -Type Warning
            Write-Status "Installing CLI in editable mode..." -Type Info
            return Install-CLI
        }

        Write-Status "CLI (inv) is installed" -Type Success
        return $true
    }
    catch {
        Write-Status "CLI (inv) is not installed" -Type Warning
        return Install-CLI
    }
}

function Install-CLI {
    $cliPath = Join-Path $script:RepoRoot "cli"

    Push-Location $cliPath
    try {
        pip install -e ".[dev]" 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Status "Failed to install CLI" -Type Error
            return $false
        }

        Write-Status "CLI installed successfully" -Type Success
        return $true
    }
    finally {
        Pop-Location
    }
}

function Test-DatabaseConnection {
    Write-Status "Checking database connection..." -Type Info

    try {
        $result = inv db stats 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Status "Database connection failed" -Type Error
            Write-Status $result -Type Error
            return $false
        }

        Write-Status "Database connection successful" -Type Success
        return $true
    }
    catch {
        Write-Status "Error connecting to database: $_" -Type Error
        return $false
    }
}

function Invoke-Migrations {
    if ($SkipMigrations) {
        Write-Status "Skipping migrations (--SkipMigrations)" -Type Info
        return $true
    }

    Write-Status "Running database migrations..." -Type Info

    try {
        $result = inv db migrate 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Status "Migration failed" -Type Error
            Write-Status $result -Type Error
            return $false
        }

        Write-Status "Migrations applied successfully" -Type Success
        return $true
    }
    catch {
        Write-Status "Error running migrations: $_" -Type Error
        return $false
    }
}

function Show-Summary {
    param([hashtable]$Results)

    Write-Host ""
    Write-Host "=" * 50
    Write-Host "  ra-infrastructure Startup Summary"
    Write-Host "=" * 50
    Write-Host ""

    foreach ($key in $Results.Keys | Sort-Object) {
        $status = if ($Results[$key]) { "OK" } else { "FAILED" }
        $color = if ($Results[$key]) { "Green" } else { "Red" }
        Write-Host ("  {0,-30} [{1}]" -f $key, $status) -ForegroundColor $color
    }

    Write-Host ""

    $allPassed = ($Results.Values | Where-Object { -not $_ }).Count -eq 0

    if ($allPassed) {
        Write-Status "All checks passed! Environment is ready." -Type Success
        Write-Host ""
        Write-Host "Quick commands:"
        Write-Host "  inv db stats     - Show database statistics"
        Write-Host "  inv org list     - List organizations"
        Write-Host "  inv device list  - List devices"
        Write-Host ""
    }
    else {
        Write-Status "Some checks failed. Please fix the issues above." -Type Error
        # Send alert email if requested
        Send-StartupFailureAlert -Results $Results
    }

    return $allPassed
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "=" * 50
    Write-Host "  ra-infrastructure Startup Script"
    Write-Host "=" * 50
    Write-Host ""

    $results = @{}

    # Step 1: Check Docker Desktop
    $results["Docker Desktop"] = Test-DockerDesktop
    if (-not $results["Docker Desktop"]) {
        Show-Summary $results
        exit 1
    }

    # Step 2: Check/Start Docker containers
    $results["Docker Containers"] = Test-DockerContainers
    if (-not $results["Docker Containers"]) {
        Show-Summary $results
        exit 1
    }

    # Step 3: Check Python environment
    $results["Python Environment"] = Test-PythonEnvironment
    if (-not $results["Python Environment"]) {
        Show-Summary $results
        exit 1
    }

    # Step 4: Check/Install CLI
    $results["CLI Installation"] = Test-CLIInstalled
    if (-not $results["CLI Installation"]) {
        Show-Summary $results
        exit 1
    }

    # Step 5: Check database connection
    $results["Database Connection"] = Test-DatabaseConnection
    if (-not $results["Database Connection"]) {
        Show-Summary $results
        exit 1
    }

    # Step 6: Run migrations
    $results["Database Migrations"] = Invoke-Migrations

    # Show summary
    $success = Show-Summary $results

    if ($success) {
        exit 0
    }
    else {
        exit 1
    }
}

Main
