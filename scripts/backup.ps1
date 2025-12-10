#Requires -Version 5.1
<#
.SYNOPSIS
    Backup script for ra-infrastructure database.

.DESCRIPTION
    Creates database backups with local storage and optional Google Drive upload.
    - Daily backups: Local storage with 7-day retention
    - Weekly backups: Uploads to Google Drive with 4-week retention

.PARAMETER Type
    Backup type: 'daily' or 'weekly'. Required.

.PARAMETER Verify
    Run integrity check after backup by restoring to temp database.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER BackupDir
    Override default backup directory (D:\Backups\ra-infrastructure).

.EXAMPLE
    .\backup.ps1 -Type daily

.EXAMPLE
    .\backup.ps1 -Type daily -Verify

.EXAMPLE
    .\backup.ps1 -Type weekly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("daily", "weekly")]
    [string]$Type,

    [switch]$Verify,
    [switch]$Force,

    [string]$BackupDir = "D:\Backups\ra-infrastructure"
)

$ErrorActionPreference = "Stop"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:LogDir = Join-Path $script:RepoRoot "logs"
$script:LogFile = Join-Path $script:LogDir "backup.log"
$script:ConfigFile = Join-Path $script:RepoRoot "config\monitoring.env"

# Database settings
$script:DbContainer = "inventory-db"
$script:DbName = "inventory"
$script:DbUser = "inventory"

# Retention settings (6 months)
$script:DailyRetentionDays = 30      # ~1 month of daily backups locally
$script:WeeklyRetentionWeeks = 26    # 6 months of weekly backups on Google Drive

# rclone settings
$script:RcloneRemote = "gdrive"
$script:RcloneRemotePath = "ra-infrastructure-backup"

# Find rclone in common locations and add to PATH if needed
function Find-Rclone {
    # Check if already in PATH
    $rclone = Get-Command rclone -ErrorAction SilentlyContinue
    if ($rclone) {
        return $rclone.Source
    }

    # Common installation locations
    $locations = @(
        # Winget installation
        (Get-ChildItem "C:\Users\$env:USERNAME\AppData\Local\Microsoft\WinGet\Packages\Rclone*" -ErrorAction SilentlyContinue |
            Get-ChildItem -Filter "rclone.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName),
        # Scoop
        "C:\Users\$env:USERNAME\scoop\apps\rclone\current\rclone.exe",
        # Chocolatey
        "C:\ProgramData\chocolatey\bin\rclone.exe",
        # Manual install
        "C:\rclone\rclone.exe"
    )

    foreach ($loc in $locations) {
        if ($loc -and (Test-Path $loc -ErrorAction SilentlyContinue)) {
            # Add directory to PATH for this session
            $dir = Split-Path $loc -Parent
            $env:PATH = "$dir;$env:PATH"
            return $loc
        }
    }

    return $null
}

# Initialize rclone path
$script:RclonePath = Find-Rclone

# Ensure directories exist
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

    Add-Content -Path $script:LogFile -Value $logEntry

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

function Send-BackupAlert {
    param(
        [string]$Subject,
        [string]$Body
    )

    $config = Get-EmailConfig
    if (-not $config) {
        Write-Log "Cannot send email - no config file" -Level WARNING
        return
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
            Subject    = $subject
            Body       = $body
            SmtpServer = $smtpServer
            Port       = $smtpPort
            UseSsl     = $true
            Credential = $credential
        }

        Send-MailMessage @mailParams
        Write-Log "Alert email sent" -Level SUCCESS
    }
    catch {
        Write-Log "Failed to send email: $_" -Level ERROR
    }
}

#endregion

#region Backup Functions

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level INFO

    # Check Docker is running
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Docker is not running" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Docker is not installed or not in PATH" -Level ERROR
        return $false
    }

    # Check container is running
    $state = docker inspect --format='{{.State.Running}}' $script:DbContainer 2>&1
    if ($LASTEXITCODE -ne 0 -or $state -ne "true") {
        Write-Log "Container '$script:DbContainer' is not running" -Level ERROR
        return $false
    }

    # Check backup directory
    if (-not (Test-Path $BackupDir)) {
        Write-Log "Creating backup directory: $BackupDir" -Level INFO
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    $dailyDir = Join-Path $BackupDir "daily"
    if (-not (Test-Path $dailyDir)) {
        New-Item -ItemType Directory -Path $dailyDir -Force | Out-Null
    }

    # For weekly, check rclone
    if ($Type -eq "weekly") {
        try {
            $rcloneVersion = rclone version 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "rclone is not installed" -Level ERROR
                return $false
            }

            # Check if remote is configured
            $remotes = rclone listremotes 2>&1
            if ($remotes -notlike "*${script:RcloneRemote}:*") {
                Write-Log "rclone remote '$script:RcloneRemote' not configured" -Level ERROR
                Write-Log "Run 'rclone config' to set up Google Drive" -Level INFO
                return $false
            }
        }
        catch {
            Write-Log "rclone check failed: $_" -Level ERROR
            return $false
        }
    }

    Write-Log "Prerequisites check passed" -Level SUCCESS
    return $true
}

function New-DatabaseBackup {
    $date = Get-Date -Format "yyyy-MM-dd"
    $dailyDir = Join-Path $BackupDir "daily"
    $compressedFile = Join-Path $dailyDir "${script:DbName}_${date}.dump.gz"
    $containerDumpPath = "/tmp/backup_${date}.dump"
    $containerGzPath = "${containerDumpPath}.gz"

    Write-Log "Creating database backup..." -Level INFO
    Write-Log "Output: $compressedFile" -Level INFO

    try {
        # Create pg_dump
        $startTime = Get-Date

        # Create dump inside container (avoids PowerShell binary corruption from redirection)
        docker exec $script:DbContainer pg_dump -U $script:DbUser -Fc $script:DbName -f $containerDumpPath 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Log "pg_dump failed" -Level ERROR
            return $null
        }

        # Check file was created
        $dumpSize = docker exec $script:DbContainer stat -c%s $containerDumpPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Backup file not created in container" -Level ERROR
            return $null
        }

        Write-Log "Dump created: $([math]::Round([int64]$dumpSize / 1MB, 2)) MB" -Level INFO

        # Compress inside container
        Write-Log "Compressing backup..." -Level INFO
        docker exec $script:DbContainer gzip -f $containerDumpPath 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Compression failed" -Level ERROR
            return $null
        }

        # Copy compressed file from container to host
        docker cp "${script:DbContainer}:${containerGzPath}" $compressedFile 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to copy backup from container" -Level ERROR
            return $null
        }

        # Cleanup container files
        docker exec $script:DbContainer rm -f $containerGzPath 2>&1 | Out-Null

        $compressedSize = (Get-Item $compressedFile).Length
        $duration = ((Get-Date) - $startTime).TotalSeconds

        Write-Log "Backup completed in $([math]::Round($duration, 1)) seconds" -Level SUCCESS
        Write-Log "Compressed size: $([math]::Round($compressedSize / 1MB, 2)) MB" -Level INFO

        return $compressedFile
    }
    catch {
        Write-Log "Backup failed: $_" -Level ERROR

        # Cleanup container files
        docker exec $script:DbContainer rm -f $containerDumpPath $containerGzPath 2>&1 | Out-Null
        if (Test-Path $compressedFile) { Remove-Item $compressedFile -Force }

        return $null
    }
}

function Test-BackupIntegrity {
    param([string]$BackupFile)

    if (-not $Verify) {
        return $true
    }

    Write-Log "Verifying backup integrity..." -Level INFO

    $tempDb = "verify_backup_temp"
    $containerGzPath = "/tmp/verify_backup.dump.gz"
    $containerDumpPath = "/tmp/verify_backup.dump"

    try {
        # Copy compressed backup file directly to container (avoids PowerShell binary handling issues)
        docker cp $BackupFile "${script:DbContainer}:${containerGzPath}" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to copy backup file to container" -Level ERROR
            return $false
        }

        # Decompress inside the container using gzip
        docker exec $script:DbContainer gzip -d -k $containerGzPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to decompress backup file in container" -Level ERROR
            return $false
        }

        # Create temp database (suppress NOTICE messages from PostgreSQL by using cmd /c)
        # PostgreSQL NOTICE messages go to stderr and trigger PowerShell errors
        cmd /c "docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c `"DROP DATABASE IF EXISTS $tempDb`" 2>nul"
        cmd /c "docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c `"CREATE DATABASE $tempDb`" 2>nul"

        # Restore to temp database from file inside container
        docker exec $script:DbContainer pg_restore -U $script:DbUser -d $tempDb $containerDumpPath 2>&1 | Out-Null

        # Verify by running a query
        $null = docker exec $script:DbContainer psql -U $script:DbUser -d $tempDb -t -c "SELECT COUNT(*) FROM organizations" 2>&1
        $exitCode = $LASTEXITCODE

        # Cleanup before returning
        cmd /c "docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c `"DROP DATABASE IF EXISTS $tempDb`" 2>nul"
        docker exec $script:DbContainer rm -f $containerGzPath $containerDumpPath 2>&1 | Out-Null

        if ($exitCode -eq 0) {
            Write-Log "Backup verification passed" -Level SUCCESS
            return $true
        }
        else {
            Write-Log "Backup verification failed - could not query restored data" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Verification failed: $_" -Level ERROR

        # Cleanup on error
        cmd /c "docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c `"DROP DATABASE IF EXISTS $tempDb`" 2>nul"
        docker exec $script:DbContainer rm -f $containerGzPath $containerDumpPath 2>&1 | Out-Null

        return $false
    }
}

function Remove-OldLocalBackups {
    Write-Log "Cleaning up old local backups (retention: $script:DailyRetentionDays days)..." -Level INFO

    $dailyDir = Join-Path $BackupDir "daily"
    $cutoffDate = (Get-Date).AddDays(-$script:DailyRetentionDays)

    $oldFiles = Get-ChildItem -Path $dailyDir -Filter "*.dump.gz" |
    Where-Object { $_.LastWriteTime -lt $cutoffDate }

    if ($oldFiles) {
        foreach ($file in $oldFiles) {
            Write-Log "Removing: $($file.Name)" -Level INFO
            Remove-Item $file.FullName -Force
        }
        Write-Log "Removed $($oldFiles.Count) old backup(s)" -Level SUCCESS
    }
    else {
        Write-Log "No old backups to remove" -Level INFO
    }
}

function Send-ToGoogleDrive {
    param([string]$BackupFile)

    Write-Log "Uploading to Google Drive..." -Level INFO

    $fileName = Split-Path $BackupFile -Leaf
    $weeklyName = $fileName -replace "\.dump\.gz$", "_weekly.dump.gz"
    $remotePath = "${script:RcloneRemote}:${script:RcloneRemotePath}/$weeklyName"

    try {
        $startTime = Get-Date

        rclone copy $BackupFile "${script:RcloneRemote}:${script:RcloneRemotePath}/" --progress 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "rclone upload failed" -Level ERROR
            return $false
        }

        # Rename to weekly
        rclone moveto "${script:RcloneRemote}:${script:RcloneRemotePath}/$fileName" $remotePath 2>&1

        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-Log "Upload completed in $([math]::Round($duration, 1)) seconds" -Level SUCCESS

        return $true
    }
    catch {
        Write-Log "Upload failed: $_" -Level ERROR
        return $false
    }
}

function Remove-OldRemoteBackups {
    Write-Log "Cleaning up old remote backups (retention: $script:WeeklyRetentionWeeks weeks)..." -Level INFO

    try {
        $cutoffDate = (Get-Date).AddDays(-($script:WeeklyRetentionWeeks * 7))

        # List remote files
        $remoteFiles = rclone lsjson "${script:RcloneRemote}:${script:RcloneRemotePath}/" 2>&1 | ConvertFrom-Json

        foreach ($file in $remoteFiles) {
            $fileDate = [DateTime]::Parse($file.ModTime)
            if ($fileDate -lt $cutoffDate) {
                Write-Log "Removing remote: $($file.Name)" -Level INFO
                rclone delete "${script:RcloneRemote}:${script:RcloneRemotePath}/$($file.Name)" 2>&1
            }
        }

        Write-Log "Remote cleanup completed" -Level SUCCESS
    }
    catch {
        Write-Log "Remote cleanup failed: $_" -Level WARNING
    }
}

#endregion

#region Main

function Invoke-DailyBackup {
    Write-Log "Starting DAILY backup..." -Level INFO

    # Create backup
    $backupFile = New-DatabaseBackup
    if (-not $backupFile) {
        return $false
    }

    # Verify if requested
    if ($Verify) {
        $verified = Test-BackupIntegrity -BackupFile $backupFile
        if (-not $verified) {
            return $false
        }
    }

    # Cleanup old backups
    Remove-OldLocalBackups

    return $true
}

function Invoke-WeeklyBackup {
    Write-Log "Starting WEEKLY backup..." -Level INFO

    # First run daily backup
    $dailySuccess = Invoke-DailyBackup
    if (-not $dailySuccess) {
        return $false
    }

    # Get the backup file we just created
    $dailyDir = Join-Path $BackupDir "daily"
    $latestBackup = Get-ChildItem -Path $dailyDir -Filter "*.dump.gz" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

    if (-not $latestBackup) {
        Write-Log "No backup file found to upload" -Level ERROR
        return $false
    }

    # Upload to Google Drive
    $uploaded = Send-ToGoogleDrive -BackupFile $latestBackup.FullName
    if (-not $uploaded) {
        return $false
    }

    # Cleanup old remote backups
    Remove-OldRemoteBackups

    return $true
}

function Main {
    $startTime = Get-Date

    Write-Host ""
    Write-Host "=" * 50
    Write-Host "  ra-infrastructure Backup"
    Write-Host "  Type: $Type"
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "=" * 50
    Write-Host ""

    Write-Log "=" * 50 -Level INFO
    Write-Log "Backup started - Type: $Type" -Level INFO

    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        $body = @"
Backup Failed

Type: $Type
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Error: Prerequisites check failed

Please check:
1. Docker is running
2. Container '$script:DbContainer' is running
3. rclone is configured (for weekly backups)

--
ra-infrastructure Backup
"@
        Send-BackupAlert -Subject "[ALERT] ra-infrastructure - Backup Failed" -Body $body
        exit 1
    }

    # Run backup
    $success = switch ($Type) {
        "daily" { Invoke-DailyBackup }
        "weekly" { Invoke-WeeklyBackup }
    }

    $duration = ((Get-Date) - $startTime).TotalSeconds

    if ($success) {
        Write-Log "Backup completed successfully in $([math]::Round($duration, 1)) seconds" -Level SUCCESS
        exit 0
    }
    else {
        Write-Log "Backup failed after $([math]::Round($duration, 1)) seconds" -Level ERROR

        $body = @"
Backup Failed

Type: $Type
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duration: $([math]::Round($duration, 1)) seconds

Check logs at: $script:LogFile

--
ra-infrastructure Backup
"@
        Send-BackupAlert -Subject "[ALERT] ra-infrastructure - Backup Failed" -Body $body
        exit 1
    }
}

Main

#endregion
