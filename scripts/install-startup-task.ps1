#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the startup verification scheduled task.

.DESCRIPTION
    Creates a Windows Task Scheduler task that runs the startup verification
    script when the system starts (with a 2-minute delay to allow Docker to start).

.PARAMETER Uninstall
    Remove the scheduled task instead of installing it.

.EXAMPLE
    .\install-startup-task.ps1

.EXAMPLE
    .\install-startup-task.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$TaskName = "ra-infrastructure-startup"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $script:RepoRoot "scripts\verify-startup.ps1"

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

function Install-StartupTask {
    Write-Status "Installing startup verification scheduled task..." -Type Info

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Status "Task already exists. Removing old task..." -Type Warning
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Create action - run with SendAlert flag
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -SendAlert"

    # Create trigger - at startup with 2-minute delay
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = "PT2M"  # 2-minute delay

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable

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
            -Description "Verifies ra-infrastructure services are running after system startup. Runs 2 minutes after boot."

        Write-Status "Task '$TaskName' installed successfully" -Type Success
        Write-Status "The verification will run 2 minutes after system startup" -Type Info

        Write-Host ""
        Write-Host "To view task status:"
        Write-Host "  Get-ScheduledTask -TaskName '$TaskName'"
        Write-Host ""
        Write-Host "To manually run:"
        Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
        Write-Host ""
        Write-Host "To uninstall:"
        Write-Host "  .\install-startup-task.ps1 -Uninstall"
    }
    catch {
        Write-Status "Failed to install task: $_" -Type Error
        exit 1
    }
}

function Uninstall-StartupTask {
    Write-Status "Uninstalling startup verification scheduled task..." -Type Info

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
Write-Host "  Startup Task Installer"
Write-Host "=" * 50
Write-Host ""

if ($Uninstall) {
    Uninstall-StartupTask
}
else {
    # Verify script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Status "Startup script not found: $ScriptPath" -Type Error
        exit 1
    }

    Install-StartupTask
}
