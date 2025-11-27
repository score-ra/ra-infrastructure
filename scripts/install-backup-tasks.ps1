#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the backup scheduled tasks.

.DESCRIPTION
    Creates Windows Task Scheduler tasks for:
    - Daily backup at 2:00 AM
    - Weekly backup on Sundays at 3:00 AM

.PARAMETER Uninstall
    Remove the scheduled tasks instead of installing them.

.PARAMETER DailyOnly
    Only install/uninstall the daily backup task.

.PARAMETER WeeklyOnly
    Only install/uninstall the weekly backup task.

.EXAMPLE
    .\install-backup-tasks.ps1

.EXAMPLE
    .\install-backup-tasks.ps1 -Uninstall

.EXAMPLE
    .\install-backup-tasks.ps1 -DailyOnly
#>

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$DailyOnly,
    [switch]$WeeklyOnly
)

$ErrorActionPreference = "Stop"

$DailyTaskName = "ra-infrastructure-backup-daily"
$WeeklyTaskName = "ra-infrastructure-backup-weekly"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $script:RepoRoot "scripts\backup.ps1"

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

function Install-DailyBackupTask {
    Write-Status "Installing daily backup task..." -Type Info

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $DailyTaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Status "Task already exists. Removing old task..." -Type Warning
        Unregister-ScheduledTask -TaskName $DailyTaskName -Confirm:$false
    }

    # Create action
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Type daily -Verify"

    # Create trigger - daily at 2:00 AM
    $trigger = New-ScheduledTaskTrigger -Daily -At "2:00 AM"

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -WakeToRun

    # Create principal
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType S4U `
        -RunLevel Limited

    try {
        Register-ScheduledTask `
            -TaskName $DailyTaskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "Daily database backup for ra-infrastructure. Runs at 2:00 AM with verification."

        Write-Status "Task '$DailyTaskName' installed successfully" -Type Success
    }
    catch {
        Write-Status "Failed to install task: $_" -Type Error
        return $false
    }

    return $true
}

function Install-WeeklyBackupTask {
    Write-Status "Installing weekly backup task..." -Type Info

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $WeeklyTaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Status "Task already exists. Removing old task..." -Type Warning
        Unregister-ScheduledTask -TaskName $WeeklyTaskName -Confirm:$false
    }

    # Create action
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Type weekly -Verify"

    # Create trigger - Sundays at 3:00 AM
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "3:00 AM"

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -WakeToRun

    # Create principal
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType S4U `
        -RunLevel Limited

    try {
        Register-ScheduledTask `
            -TaskName $WeeklyTaskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "Weekly database backup for ra-infrastructure. Runs Sundays at 3:00 AM with Google Drive upload."

        Write-Status "Task '$WeeklyTaskName' installed successfully" -Type Success
    }
    catch {
        Write-Status "Failed to install task: $_" -Type Error
        return $false
    }

    return $true
}

function Uninstall-BackupTask {
    param([string]$TaskName)

    Write-Status "Uninstalling task '$TaskName'..." -Type Info

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
    }
}

# Main
Write-Host ""
Write-Host "=" * 50
Write-Host "  Backup Tasks Installer"
Write-Host "=" * 50
Write-Host ""

# Verify script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Status "Backup script not found: $ScriptPath" -Type Error
    exit 1
}

$installDaily = -not $WeeklyOnly
$installWeekly = -not $DailyOnly

if ($Uninstall) {
    if ($installDaily) {
        Uninstall-BackupTask -TaskName $DailyTaskName
    }
    if ($installWeekly) {
        Uninstall-BackupTask -TaskName $WeeklyTaskName
    }
}
else {
    $success = $true

    if ($installDaily) {
        if (-not (Install-DailyBackupTask)) {
            $success = $false
        }
    }

    if ($installWeekly) {
        if (-not (Install-WeeklyBackupTask)) {
            $success = $false
        }
    }

    if ($success) {
        Write-Host ""
        Write-Host "Backup Schedule:"
        Write-Host "  Daily:  2:00 AM (local backup with verification)"
        Write-Host "  Weekly: Sunday 3:00 AM (Google Drive upload)"
        Write-Host ""
        Write-Host "To view tasks:"
        Write-Host "  Get-ScheduledTask -TaskName 'ra-infrastructure-backup-*'"
        Write-Host ""
        Write-Host "To run manually:"
        Write-Host "  .\backup.ps1 -Type daily"
        Write-Host "  .\backup.ps1 -Type weekly"
        Write-Host ""
        Write-Host "To uninstall:"
        Write-Host "  .\install-backup-tasks.ps1 -Uninstall"
    }
    else {
        exit 1
    }
}
