#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the health check scheduled task.

.DESCRIPTION
    Creates a Windows Task Scheduler task that runs the health check
    every 5 minutes.

.PARAMETER Uninstall
    Remove the scheduled task instead of installing it.

.EXAMPLE
    .\install-health-check-task.ps1

.EXAMPLE
    .\install-health-check-task.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$TaskName = "ra-infrastructure-health-check"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $script:RepoRoot "scripts\health-check.ps1"

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
}

function Install-HealthCheckTask {
    Write-Status "Installing health check scheduled task..." -Type Info

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Status "Task already exists. Removing old task..." -Type Warning
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Create action
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

    # Create trigger - every 5 minutes
    $trigger = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes 5) `
        -RepetitionDuration (New-TimeSpan -Days 9999)

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -MultipleInstances IgnoreNew

    # Create principal (run as current user)
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType S4U `
        -RunLevel Limited

    # Register the task
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "Monitors ra-infrastructure Docker containers and database health. Runs every 5 minutes."

        Write-Status "Task '$TaskName' installed successfully" -Type Success
        Write-Status "The health check will run every 5 minutes" -Type Info

        # Start the task immediately
        Write-Status "Starting initial health check..." -Type Info
        Start-ScheduledTask -TaskName $TaskName

        Write-Host ""
        Write-Host "To view task status:"
        Write-Host "  Get-ScheduledTask -TaskName '$TaskName'"
        Write-Host ""
        Write-Host "To manually run:"
        Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
        Write-Host ""
        Write-Host "To uninstall:"
        Write-Host "  .\install-health-check-task.ps1 -Uninstall"
    }
    catch {
        Write-Status "Failed to install task: $_" -Type Error
        exit 1
    }
}

function Uninstall-HealthCheckTask {
    Write-Status "Uninstalling health check scheduled task..." -Type Info

    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $existingTask) {
        Write-Status "Task '$TaskName' not found" -Type Warning
        return
    }

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Status "Task '$TaskName' removed successfully" -Type Success
    }
    catch {
        Write-Status "Failed to remove task: $_" -Type Error
        exit 1
    }
}

# Main
Write-Host ""
Write-Host "=" * 50
Write-Host "  Health Check Task Installer"
Write-Host "=" * 50
Write-Host ""

if ($Uninstall) {
    Uninstall-HealthCheckTask
}
else {
    # Verify script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Status "Health check script not found: $ScriptPath" -Type Error
        exit 1
    }

    Install-HealthCheckTask
}
