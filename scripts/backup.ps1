#Requires -Version 5.1
<#
.SYNOPSIS
    Backup script for ra-infrastructure database and Fasten Health.

.DESCRIPTION
    Creates database backups with local storage and optional Google Drive upload.
    - Daily backups: Local storage with 30-day retention
    - Weekly backups: Uploads to Google Drive with 6-month retention
    - Supports backing up Fasten Health (SQLite + config) alongside PostgreSQL

.PARAMETER Type
    Backup type: 'daily' or 'weekly'. Required.

.PARAMETER Verify
    Run integrity check after backup by restoring to temp database.

.PARAMETER IncludeFasten
    Also backup Fasten Health data (SQLite database, certs, config, encryption key).

.PARAMETER FastenOnly
    Only backup Fasten Health, skip ra-infrastructure database.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER BackupDir
    Override default backup directory (D:\Backups\ra-infrastructure).

.EXAMPLE
    .\backup.ps1 -Type daily

.EXAMPLE
    .\backup.ps1 -Type daily -Verify

.EXAMPLE
    .\backup.ps1 -Type daily -IncludeFasten

.EXAMPLE
    .\backup.ps1 -Type weekly -IncludeFasten

.EXAMPLE
    .\backup.ps1 -Type daily -FastenOnly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("daily", "weekly")]
    [string]$Type,

    [switch]$Verify,
    [switch]$IncludeFasten,
    [switch]$FastenOnly,
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

# Fasten Health settings
$script:FastenDeployDir = "C:\Users\ranand\workspace\personal\software\fasten-deploy"
$script:FastenHealthDir = "C:\Users\ranand\workspace\personal\software\ra-fasten-health"
$script:FastenBackupDir = "D:\Backups\fasten-health"
$script:FastenContainer = "fasten-deploy-fasten-prod-1"

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

#region Fasten Health Backup Functions

function Test-FastenPrerequisites {
    Write-Log "Checking Fasten Health prerequisites..." -Level INFO

    # Check if Fasten deploy directory exists
    if (-not (Test-Path $script:FastenDeployDir)) {
        Write-Log "Fasten deploy directory not found: $script:FastenDeployDir" -Level ERROR
        return $false
    }

    # Check if Fasten database exists
    $fastenDb = Join-Path $script:FastenDeployDir "db\fasten.db"
    if (-not (Test-Path $fastenDb)) {
        Write-Log "Fasten database not found: $fastenDb" -Level ERROR
        return $false
    }

    # Check if encryption key exists
    $encryptionKey = Join-Path $script:FastenHealthDir "config\encryption_key.txt"
    if (-not (Test-Path $encryptionKey)) {
        Write-Log "Fasten encryption key not found: $encryptionKey" -Level WARNING
        # Continue anyway - key might be stored elsewhere
    }

    # Check backup directory
    if (-not (Test-Path $script:FastenBackupDir)) {
        Write-Log "Creating Fasten backup directory: $script:FastenBackupDir" -Level INFO
        New-Item -ItemType Directory -Path $script:FastenBackupDir -Force | Out-Null
    }

    Write-Log "Fasten prerequisites check passed" -Level SUCCESS
    return $true
}

function New-FastenBackup {
    param([switch]$StopContainer)

    $date = Get-Date -Format "yyyy-MM-dd"
    $backupDir = Join-Path $script:FastenBackupDir $date

    Write-Log "Creating Fasten Health backup..." -Level INFO
    Write-Log "Output directory: $backupDir" -Level INFO

    # Create backup directory
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

    try {
        $startTime = Get-Date

        # Optionally stop container for consistent backup
        $containerWasRunning = $false
        if ($StopContainer) {
            $state = docker inspect --format='{{.State.Running}}' $script:FastenContainer 2>&1
            if ($LASTEXITCODE -eq 0 -and $state -eq "true") {
                $containerWasRunning = $true
                Write-Log "Stopping Fasten container for consistent backup..." -Level INFO
                docker compose -f "$script:FastenDeployDir\docker-compose.yml" stop 2>&1 | Out-Null
                Start-Sleep -Seconds 2
            }
        }

        # Backup database (CRITICAL)
        Write-Log "Backing up Fasten database..." -Level INFO
        $dbBackupDir = Join-Path $backupDir "db"
        New-Item -ItemType Directory -Force -Path $dbBackupDir | Out-Null
        $dbFiles = Get-ChildItem -Path "$script:FastenDeployDir\db" -ErrorAction SilentlyContinue
        if ($dbFiles) {
            Copy-Item -Path "$script:FastenDeployDir\db\*" -Destination $dbBackupDir -Force
            $dbSize = (Get-ChildItem $dbBackupDir -Recurse | Measure-Object -Property Length -Sum).Sum
            Write-Log "Database backed up: $([math]::Round($dbSize / 1MB, 2)) MB" -Level INFO
        }
        else {
            Write-Log "No database files found" -Level WARNING
        }

        # Backup certificates
        Write-Log "Backing up certificates..." -Level INFO
        $certsBackupDir = Join-Path $backupDir "certs"
        New-Item -ItemType Directory -Force -Path $certsBackupDir | Out-Null
        $certsDir = Join-Path $script:FastenDeployDir "certs"
        if (Test-Path $certsDir) {
            Copy-Item -Path "$certsDir\*" -Destination $certsBackupDir -Force -ErrorAction SilentlyContinue
        }

        # Backup configuration files
        Write-Log "Backing up configuration..." -Level INFO
        $envFile = Join-Path $script:FastenDeployDir ".env"
        if (Test-Path $envFile) {
            Copy-Item -Path $envFile -Destination $backupDir -Force
        }
        $composeFile = Join-Path $script:FastenDeployDir "docker-compose.yml"
        if (Test-Path $composeFile) {
            Copy-Item -Path $composeFile -Destination $backupDir -Force
        }

        # Backup encryption key (CRITICAL)
        Write-Log "Backing up encryption key..." -Level INFO
        $encryptionKey = Join-Path $script:FastenHealthDir "config\encryption_key.txt"
        if (Test-Path $encryptionKey) {
            Copy-Item -Path $encryptionKey -Destination $backupDir -Force
        }
        else {
            Write-Log "Encryption key not found - backup may be incomplete" -Level WARNING
        }

        # Restart container if we stopped it
        if ($containerWasRunning) {
            Write-Log "Starting Fasten container..." -Level INFO
            docker compose -f "$script:FastenDeployDir\docker-compose.yml" start 2>&1 | Out-Null
        }

        # Create compressed archive
        $archivePath = Join-Path $script:FastenBackupDir "fasten-health_${date}.zip"
        Write-Log "Creating compressed archive..." -Level INFO
        Compress-Archive -Path "$backupDir\*" -DestinationPath $archivePath -Force

        $archiveSize = (Get-Item $archivePath).Length
        $duration = ((Get-Date) - $startTime).TotalSeconds

        Write-Log "Fasten backup completed in $([math]::Round($duration, 1)) seconds" -Level SUCCESS
        Write-Log "Archive size: $([math]::Round($archiveSize / 1MB, 2)) MB" -Level INFO

        return $archivePath
    }
    catch {
        Write-Log "Fasten backup failed: $_" -Level ERROR

        # Ensure container is running even on error
        if ($StopContainer) {
            docker compose -f "$script:FastenDeployDir\docker-compose.yml" start 2>&1 | Out-Null
        }

        return $null
    }
}

function Remove-OldFastenBackups {
    Write-Log "Cleaning up old Fasten backups (retention: $script:DailyRetentionDays days)..." -Level INFO

    $cutoffDate = (Get-Date).AddDays(-$script:DailyRetentionDays)
    $removedCount = 0

    # Clean old daily directories
    Get-ChildItem -Path $script:FastenBackupDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
        Where-Object {
            try {
                [DateTime]::ParseExact($_.Name, 'yyyy-MM-dd', $null) -lt $cutoffDate
            }
            catch { $false }
        } |
        ForEach-Object {
            Write-Log "Removing directory: $($_.Name)" -Level INFO
            Remove-Item $_.FullName -Recurse -Force
            $removedCount++
        }

    # Clean old zip files
    Get-ChildItem -Path $script:FastenBackupDir -Filter "fasten-health_*.zip" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        ForEach-Object {
            Write-Log "Removing archive: $($_.Name)" -Level INFO
            Remove-Item $_.FullName -Force
            $removedCount++
        }

    if ($removedCount -gt 0) {
        Write-Log "Removed $removedCount old Fasten backup(s)" -Level SUCCESS
    }
    else {
        Write-Log "No old Fasten backups to remove" -Level INFO
    }
}

function Send-FastenToGoogleDrive {
    param([string]$BackupFile)

    $fileName = Split-Path $BackupFile -Leaf
    $weeklyName = $fileName -replace "\.zip$", "_weekly.zip"

    Write-Log "Uploading Fasten backup to Google Drive..." -Level INFO

    try {
        $startTime = Get-Date

        rclone copy $BackupFile "${script:RcloneRemote}:${script:RcloneRemotePath}/" --progress 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Fasten rclone upload failed" -Level ERROR
            return $false
        }

        # Rename to weekly
        rclone moveto "${script:RcloneRemote}:${script:RcloneRemotePath}/$fileName" `
                     "${script:RcloneRemote}:${script:RcloneRemotePath}/$weeklyName" 2>&1

        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-Log "Fasten upload completed in $([math]::Round($duration, 1)) seconds" -Level SUCCESS

        return $true
    }
    catch {
        Write-Log "Fasten upload failed: $_" -Level ERROR
        return $false
    }
}

function Invoke-FastenDailyBackup {
    Write-Log "Starting Fasten Health DAILY backup..." -Level INFO

    # Check prerequisites
    if (-not (Test-FastenPrerequisites)) {
        return $false
    }

    # Create backup (stop container for consistent SQLite backup)
    $backupFile = New-FastenBackup -StopContainer
    if (-not $backupFile) {
        return $false
    }

    # Cleanup old backups
    Remove-OldFastenBackups

    return $true
}

function Invoke-FastenWeeklyBackup {
    Write-Log "Starting Fasten Health WEEKLY backup..." -Level INFO

    # First run daily backup
    $dailySuccess = Invoke-FastenDailyBackup
    if (-not $dailySuccess) {
        return $false
    }

    # Get the backup file we just created
    $latestBackup = Get-ChildItem -Path $script:FastenBackupDir -Filter "fasten-health_*.zip" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latestBackup) {
        Write-Log "No Fasten backup file found to upload" -Level ERROR
        return $false
    }

    # Upload to Google Drive
    $uploaded = Send-FastenToGoogleDrive -BackupFile $latestBackup.FullName
    if (-not $uploaded) {
        return $false
    }

    return $true
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

    # Determine what we're backing up
    $backupTargets = @()
    if ($FastenOnly) {
        $backupTargets += "Fasten Health"
    }
    else {
        $backupTargets += "ra-infrastructure"
        if ($IncludeFasten) {
            $backupTargets += "Fasten Health"
        }
    }
    $targetList = $backupTargets -join " + "

    Write-Host ""
    Write-Host "=" * 60
    Write-Host "  Consolidated Backup"
    Write-Host "  Targets: $targetList"
    Write-Host "  Type: $Type"
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "=" * 60
    Write-Host ""

    Write-Log "=" * 60 -Level INFO
    Write-Log "Backup started - Type: $Type, Targets: $targetList" -Level INFO

    $infraSuccess = $true
    $fastenSuccess = $true

    # Check prerequisites for ra-infrastructure (unless FastenOnly)
    if (-not $FastenOnly) {
        if (-not (Test-Prerequisites)) {
            $body = @"
Backup Failed

Type: $Type
Targets: $targetList
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Error: ra-infrastructure prerequisites check failed

Please check:
1. Docker is running
2. Container '$script:DbContainer' is running
3. rclone is configured (for weekly backups)

--
Consolidated Backup
"@
            Send-BackupAlert -Subject "[ALERT] Backup Failed - ra-infrastructure" -Body $body
            $infraSuccess = $false
        }
        else {
            # Run ra-infrastructure backup
            $infraSuccess = switch ($Type) {
                "daily" { Invoke-DailyBackup }
                "weekly" { Invoke-WeeklyBackup }
            }
        }
    }

    # Run Fasten Health backup if requested
    if ($IncludeFasten -or $FastenOnly) {
        Write-Log "" -Level INFO
        Write-Log "=" * 40 -Level INFO
        $fastenSuccess = switch ($Type) {
            "daily" { Invoke-FastenDailyBackup }
            "weekly" { Invoke-FastenWeeklyBackup }
        }
    }

    $duration = ((Get-Date) - $startTime).TotalSeconds

    # Determine overall success
    $overallSuccess = $true
    $failedTargets = @()

    if (-not $FastenOnly -and -not $infraSuccess) {
        $overallSuccess = $false
        $failedTargets += "ra-infrastructure"
    }
    if (($IncludeFasten -or $FastenOnly) -and -not $fastenSuccess) {
        $overallSuccess = $false
        $failedTargets += "Fasten Health"
    }

    if ($overallSuccess) {
        Write-Log "" -Level INFO
        Write-Log "All backups completed successfully in $([math]::Round($duration, 1)) seconds" -Level SUCCESS
        exit 0
    }
    else {
        $failedList = $failedTargets -join ", "
        Write-Log "" -Level INFO
        Write-Log "Backup failed for: $failedList (after $([math]::Round($duration, 1)) seconds)" -Level ERROR

        $body = @"
Backup Failed

Type: $Type
Failed Targets: $failedList
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duration: $([math]::Round($duration, 1)) seconds

Check logs at: $script:LogFile

--
Consolidated Backup
"@
        Send-BackupAlert -Subject "[ALERT] Backup Failed - $failedList" -Body $body
        exit 1
    }
}

Main

#endregion
