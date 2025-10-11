<#
.SYNOPSIS
    Automated Windows 11 User Environment Setup Script

.DESCRIPTION
    This PowerShell script automates the setup of a new user account in Windows 11 Pro,
    including installation and configuration of required development tools, applications,
    and environment settings for the Symphony Core infrastructure team.

.PARAMETER NewUsername
    The username for the new Windows user account

.PARAMETER UserFullName
    The full name of the user

.PARAMETER SetupProfile
    The type of setup profile (Developer, Admin, Standard)

.PARAMETER SkipApplications
    Skip application installation (useful for testing)

.PARAMETER DryRun
    Simulate the setup without making actual changes

.EXAMPLE
    .\New-WindowsUserEnvironment.ps1 -NewUsername "rohit" -UserFullName "Rohit Anand" -SetupProfile "Developer"

.EXAMPLE
    .\New-WindowsUserEnvironment.ps1 -NewUsername "testuser" -SetupProfile "Standard" -DryRun

.NOTES
    Version:        1.0
    Author:         Symphony Core Infrastructure Team
    Creation Date:  2025-10-01
    Purpose:        Standardized user environment setup and migration risk mitigation

    Requirements:
    - Windows 11 Pro
    - Administrator privileges
    - Internet connection
    - PowerShell 5.1 or higher

.LINK
    https://github.com/symphonycore/sc-infrastructure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$NewUsername,

    [Parameter(Mandatory = $false)]
    [string]$UserFullName = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Developer", "Admin", "Standard")]
    [string]$SetupProfile = "Developer",

    [Parameter(Mandatory = $false)]
    [switch]$SkipApplications,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Requires Administrator privileges
#Requires -RunAsAdministrator

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$Global:Config = @{
    ScriptVersion     = "1.0.0"
    SetupDate         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    LogPath           = "$env:SystemDrive\Logs\UserSetup"
    LogFile           = "UserSetup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    BackupPath        = "$env:SystemDrive\Backups\UserSetup"
    TempPath          = "$env:TEMP\UserSetup"
    RestorePointName  = "Pre-UserSetup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

# Application definitions by profile
$Global:Applications = @{
    Developer = @{
        Essential = @(
            @{Name = "Git"; Package = "Git.Git"; Type = "WinGet" }
            @{Name = "Visual Studio Code"; Package = "Microsoft.VisualStudioCode"; Type = "WinGet" }
            @{Name = "Windows Terminal"; Package = "Microsoft.WindowsTerminal"; Type = "WinGet" }
            @{Name = "PowerShell 7"; Package = "Microsoft.PowerShell"; Type = "WinGet" }
            @{Name = "Docker Desktop"; Package = "Docker.DockerDesktop"; Type = "WinGet" }
            @{Name = "Node.js LTS"; Package = "OpenJS.NodeJS.LTS"; Type = "WinGet" }
            @{Name = "Python 3"; Package = "Python.Python.3.12"; Type = "WinGet" }
        )
        Optional  = @(
            @{Name = "Azure CLI"; Package = "Microsoft.AzureCLI"; Type = "WinGet" }
            @{Name = "AWS CLI"; Package = "Amazon.AWSCLI"; Type = "WinGet" }
            @{Name = "Google Cloud SDK"; Package = "Google.CloudSDK"; Type = "WinGet" }
            @{Name = "Postman"; Package = "Postman.Postman"; Type = "WinGet" }
            @{Name = "DBeaver"; Package = "dbeaver.dbeaver"; Type = "WinGet" }
            @{Name = "WinSCP"; Package = "WinSCP.WinSCP"; Type = "WinGet" }
            @{Name = "7-Zip"; Package = "7zip.7zip"; Type = "WinGet" }
            @{Name = "Notepad++"; Package = "Notepad++.Notepad++"; Type = "WinGet" }
        )
        Extensions = @(
            @{Name = "MSYS2"; Package = "MSYS2.MSYS2"; Type = "WinGet" }
            @{Name = "Chocolatey"; Type = "Script"; Script = "Install-Chocolatey" }
        )
    }
    Admin     = @{
        Essential = @(
            @{Name = "Windows Terminal"; Package = "Microsoft.WindowsTerminal"; Type = "WinGet" }
            @{Name = "PowerShell 7"; Package = "Microsoft.PowerShell"; Type = "WinGet" }
            @{Name = "Git"; Package = "Git.Git"; Type = "WinGet" }
            @{Name = "Visual Studio Code"; Package = "Microsoft.VisualStudioCode"; Type = "WinGet" }
        )
        Optional  = @(
            @{Name = "7-Zip"; Package = "7zip.7zip"; Type = "WinGet" }
            @{Name = "WinSCP"; Package = "WinSCP.WinSCP"; Type = "WinGet" }
            @{Name = "Notepad++"; Package = "Notepad++.Notepad++"; Type = "WinGet" }
        )
    }
    Standard  = @{
        Essential = @(
            @{Name = "Windows Terminal"; Package = "Microsoft.WindowsTerminal"; Type = "WinGet" }
            @{Name = "7-Zip"; Package = "7zip.7zip"; Type = "WinGet" }
        )
        Optional  = @(
            @{Name = "Notepad++"; Package = "Notepad++.Notepad++"; Type = "WinGet" }
        )
    }
}

# Environment variables to configure
$Global:EnvironmentVariables = @{
    User   = @{
        "HOME"        = "C:\Users\$NewUsername"
        "EDITOR"      = "code"
        "VISUAL"      = "code"
    }
    System = @{
        # Add system-wide variables if needed
    }
}

# Git configuration
$Global:GitConfig = @{
    UserEmail = ""  # Will be prompted if needed
    UserName  = ""  # Will be prompted if needed
    Settings  = @{
        "core.autocrlf"           = "true"
        "core.editor"             = "code --wait"
        "pull.rebase"             = "false"
        "init.defaultBranch"      = "main"
        "credential.helper"       = "manager-core"
    }
}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

function Initialize-Logging {
    if (-not (Test-Path $Global:Config.LogPath)) {
        New-Item -Path $Global:Config.LogPath -ItemType Directory -Force | Out-Null
    }
    $Global:LogFilePath = Join-Path $Global:Config.LogPath $Global:Config.LogFile

    Write-Log "=" 80
    Write-Log "Windows 11 User Environment Setup Script v$($Global:Config.ScriptVersion)"
    Write-Log "Setup Date: $($Global:Config.SetupDate)"
    Write-Log "Target User: $NewUsername"
    Write-Log "Setup Profile: $SetupProfile"
    Write-Log "Dry Run: $DryRun"
    Write-Log "=" 80
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [int]$Repeat = 0
    )

    if ($Repeat -gt 0) {
        $Message = $Message * $Repeat
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    Add-Content -Path $Global:LogFilePath -Value $logMessage
    Write-Host $logMessage
}

function Write-Success {
    param([string]$Message)
    Write-Log "[SUCCESS] $Message"
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Log "[WARNING] $Message"
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorLog {
    param([string]$Message)
    Write-Log "[ERROR] $Message"
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Log ""
    Write-Log ">>> $Message"
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

function Test-Prerequisites {
    Write-Step "Running pre-flight checks..."

    $issues = @()

    # Check Windows version
    $osInfo = Get-CimInstance Win32_OperatingSystem
    if ($osInfo.Caption -notlike "*Windows 11*") {
        $issues += "This script requires Windows 11. Current OS: $($osInfo.Caption)"
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1 or higher required. Current version: $($PSVersionTable.PSVersion)"
    }

    # Check admin privileges (already enforced by #Requires)
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $issues += "Script must be run with Administrator privileges"
    }

    # Check internet connectivity
    try {
        $null = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
    }
    catch {
        $issues += "Internet connection required for package installation"
    }

    # Check if username already exists
    try {
        $existingUser = Get-LocalUser -Name $NewUsername -ErrorAction SilentlyContinue
        if ($existingUser) {
            $issues += "User '$NewUsername' already exists"
        }
    }
    catch {
        # User doesn't exist - this is good
    }

    # Check disk space (require at least 10GB free)
    $drive = Get-PSDrive -Name C
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    if ($freeSpaceGB -lt 10) {
        $issues += "Insufficient disk space. Available: ${freeSpaceGB}GB, Required: 10GB"
    }

    if ($issues.Count -gt 0) {
        Write-ErrorLog "Pre-flight checks failed:"
        foreach ($issue in $issues) {
            Write-ErrorLog "  - $issue"
        }
        return $false
    }

    Write-Success "All pre-flight checks passed"
    return $true
}

# =============================================================================
# BACKUP AND RESTORE POINT
# =============================================================================

function New-SystemBackup {
    Write-Step "Creating system restore point..."

    if ($DryRun) {
        Write-Log "[DRY RUN] Would create restore point: $($Global:Config.RestorePointName)"
        return $true
    }

    try {
        # Enable System Restore if not already enabled
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

        # Create restore point
        Checkpoint-Computer -Description $Global:Config.RestorePointName -RestorePointType MODIFY_SETTINGS
        Write-Success "System restore point created: $($Global:Config.RestorePointName)"
        return $true
    }
    catch {
        Write-Warning "Failed to create system restore point: $_"
        Write-Warning "Continuing without restore point..."
        return $false
    }
}

function Backup-CurrentUserProfile {
    param([string]$CurrentUser)

    Write-Step "Backing up current user profile configuration..."

    $backupRoot = Join-Path $Global:Config.BackupPath $CurrentUser

    if ($DryRun) {
        Write-Log "[DRY RUN] Would backup profile to: $backupRoot"
        return $true
    }

    if (-not (Test-Path $backupRoot)) {
        New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null
    }

    try {
        # Backup registry keys
        $regBackup = Join-Path $backupRoot "UserShellFolders.reg"
        reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" $regBackup /y | Out-Null
        Write-Log "Backed up registry: $regBackup"

        # Backup environment variables
        $envBackup = Join-Path $backupRoot "EnvironmentVariables.xml"
        Get-ChildItem Env: | Export-Clixml -Path $envBackup
        Write-Log "Backed up environment variables: $envBackup"

        # Save user account info
        $userInfo = Get-LocalUser -Name $CurrentUser | Select-Object *
        $userInfoFile = Join-Path $backupRoot "UserAccountInfo.xml"
        $userInfo | Export-Clixml -Path $userInfoFile
        Write-Log "Backed up user account info: $userInfoFile"

        Write-Success "Profile backup completed: $backupRoot"
        return $true
    }
    catch {
        Write-ErrorLog "Failed to backup profile: $_"
        return $false
    }
}

# =============================================================================
# USER ACCOUNT MANAGEMENT
# =============================================================================

function New-UserAccount {
    Write-Step "Creating new user account: $NewUsername"

    if ($DryRun) {
        Write-Log "[DRY RUN] Would create user: $NewUsername"
        Write-Log "[DRY RUN] Full Name: $UserFullName"
        Write-Log "[DRY RUN] Groups: Administrators, docker-users, Users"
        return $true
    }

    try {
        # Prompt for password
        $password = Read-Host "Enter password for user '$NewUsername'" -AsSecureString
        $passwordConfirm = Read-Host "Confirm password" -AsSecureString

        $pwd1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        $pwd2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordConfirm))

        if ($pwd1 -ne $pwd2) {
            Write-ErrorLog "Passwords do not match"
            return $false
        }

        # Create user
        $newUserParams = @{
            Name                     = $NewUsername
            Password                 = $password
            FullName                 = if ($UserFullName) { $UserFullName } else { $NewUsername }
            Description              = "Created by automated setup script on $($Global:Config.SetupDate)"
            PasswordNeverExpires     = $true
            UserMayNotChangePassword = $false
            AccountNeverExpires      = $true
        }

        New-LocalUser @newUserParams | Out-Null
        Write-Success "User account created: $NewUsername"

        # Add to groups
        Add-LocalGroupMember -Group "Administrators" -Member $NewUsername
        Write-Log "Added to group: Administrators"

        Add-LocalGroupMember -Group "Users" -Member $NewUsername
        Write-Log "Added to group: Users"

        # Add to docker-users if it exists
        try {
            Add-LocalGroupMember -Group "docker-users" -Member $NewUsername -ErrorAction SilentlyContinue
            Write-Log "Added to group: docker-users"
        }
        catch {
            Write-Warning "docker-users group not found (Docker Desktop may not be installed)"
        }

        Write-Success "User groups configured"
        return $true
    }
    catch {
        Write-ErrorLog "Failed to create user account: $_"
        return $false
    }
}

# =============================================================================
# PACKAGE MANAGEMENT
# =============================================================================

function Initialize-PackageManagers {
    Write-Step "Initializing package managers..."

    # Check WinGet
    try {
        $wingetVersion = winget --version
        Write-Success "WinGet is available: $wingetVersion"
    }
    catch {
        Write-ErrorLog "WinGet is not available. Please install App Installer from Microsoft Store."
        return $false
    }

    # Accept WinGet source agreements
    if (-not $DryRun) {
        winget source update | Out-Null
    }

    return $true
}

function Install-Application {
    param(
        [hashtable]$App
    )

    Write-Log "Installing: $($App.Name)..."

    if ($DryRun) {
        Write-Log "[DRY RUN] Would install: $($App.Name) ($($App.Package))"
        return $true
    }

    try {
        switch ($App.Type) {
            "WinGet" {
                $result = winget install --id $App.Package --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Installed: $($App.Name)"
                    return $true
                }
                else {
                    Write-Warning "Installation may have issues: $($App.Name) (Exit code: $LASTEXITCODE)"
                    return $false
                }
            }
            "Script" {
                & "Install-$($App.Name)"
                return $true
            }
            default {
                Write-Warning "Unknown installation type: $($App.Type)"
                return $false
            }
        }
    }
    catch {
        Write-ErrorLog "Failed to install $($App.Name): $_"
        return $false
    }
}

function Install-Applications {
    if ($SkipApplications) {
        Write-Warning "Skipping application installation (SkipApplications flag set)"
        return $true
    }

    Write-Step "Installing applications for profile: $SetupProfile"

    $profileApps = $Global:Applications[$SetupProfile]
    $successCount = 0
    $failCount = 0

    # Install essential applications
    Write-Log "Installing essential applications..."
    foreach ($app in $profileApps.Essential) {
        if (Install-Application -App $app) {
            $successCount++
        }
        else {
            $failCount++
        }
        Start-Sleep -Seconds 2
    }

    # Ask about optional applications
    if ($profileApps.Optional.Count -gt 0 -and -not $DryRun) {
        Write-Host "`nOptional applications available:" -ForegroundColor Cyan
        foreach ($app in $profileApps.Optional) {
            Write-Host "  - $($app.Name)"
        }

        $installOptional = Read-Host "`nInstall optional applications? (Y/N)"
        if ($installOptional -eq "Y" -or $installOptional -eq "y") {
            Write-Log "Installing optional applications..."
            foreach ($app in $profileApps.Optional) {
                if (Install-Application -App $app) {
                    $successCount++
                }
                else {
                    $failCount++
                }
                Start-Sleep -Seconds 2
            }
        }
    }

    # Install extensions
    if ($profileApps.Extensions) {
        Write-Log "Installing extensions..."
        foreach ($app in $profileApps.Extensions) {
            if (Install-Application -App $app) {
                $successCount++
            }
            else {
                $failCount++
            }
            Start-Sleep -Seconds 2
        }
    }

    Write-Log ""
    Write-Success "Application installation complete. Success: $successCount, Failed: $failCount"
    return ($failCount -eq 0)
}

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

function Set-EnvironmentVariables {
    Write-Step "Configuring environment variables..."

    if ($DryRun) {
        Write-Log "[DRY RUN] Would set environment variables:"
        foreach ($key in $Global:EnvironmentVariables.User.Keys) {
            Write-Log "  User: $key = $($Global:EnvironmentVariables.User[$key])"
        }
        foreach ($key in $Global:EnvironmentVariables.System.Keys) {
            Write-Log "  System: $key = $($Global:EnvironmentVariables.System[$key])"
        }
        return $true
    }

    try {
        # Set user environment variables
        foreach ($key in $Global:EnvironmentVariables.User.Keys) {
            $value = $Global:EnvironmentVariables.User[$key]
            [Environment]::SetEnvironmentVariable($key, $value, [EnvironmentVariableTarget]::User)
            Write-Log "Set user variable: $key = $value"
        }

        # Set system environment variables (if any)
        foreach ($key in $Global:EnvironmentVariables.System.Keys) {
            $value = $Global:EnvironmentVariables.System[$key]
            [Environment]::SetEnvironmentVariable($key, $value, [EnvironmentVariableTarget]::Machine)
            Write-Log "Set system variable: $key = $value"
        }

        Write-Success "Environment variables configured"
        return $true
    }
    catch {
        Write-ErrorLog "Failed to set environment variables: $_"
        return $false
    }
}

function Initialize-GitConfiguration {
    Write-Step "Configuring Git..."

    if ($DryRun) {
        Write-Log "[DRY RUN] Would configure Git with global settings"
        return $true
    }

    # Check if Git is installed
    try {
        $gitVersion = git --version
        Write-Log "Git version: $gitVersion"
    }
    catch {
        Write-Warning "Git is not installed or not in PATH. Skipping Git configuration."
        return $false
    }

    # Prompt for user info if not set
    if (-not $Global:GitConfig.UserEmail) {
        $Global:GitConfig.UserEmail = Read-Host "Enter Git user email"
    }

    if (-not $Global:GitConfig.UserName) {
        $Global:GitConfig.UserName = Read-Host "Enter Git user name"
    }

    try {
        # Set user identity
        git config --global user.email $Global:GitConfig.UserEmail
        git config --global user.name $Global:GitConfig.UserName
        Write-Log "Set Git identity: $($Global:GitConfig.UserName) <$($Global:GitConfig.UserEmail)>"

        # Set other configurations
        foreach ($key in $Global:GitConfig.Settings.Keys) {
            $value = $Global:GitConfig.Settings[$key]
            git config --global $key $value
            Write-Log "Set Git config: $key = $value"
        }

        Write-Success "Git configuration complete"
        return $true
    }
    catch {
        Write-ErrorLog "Failed to configure Git: $_"
        return $false
    }
}

function Initialize-SSHKeys {
    Write-Step "Setting up SSH keys..."

    $sshPath = Join-Path "C:\Users\$NewUsername" ".ssh"

    if ($DryRun) {
        Write-Log "[DRY RUN] Would create SSH directory: $sshPath"
        Write-Log "[DRY RUN] Would generate SSH key pair"
        return $true
    }

    # Create .ssh directory
    if (-not (Test-Path $sshPath)) {
        New-Item -Path $sshPath -ItemType Directory -Force | Out-Null
        Write-Log "Created SSH directory: $sshPath"
    }

    # Set proper permissions
    $acl = Get-Acl $sshPath
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $NewUsername, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl -Path $sshPath -AclObject $acl

    Write-Log "Set SSH directory permissions"

    # Ask if user wants to generate new key
    $generateKey = Read-Host "Generate new SSH key pair? (Y/N)"
    if ($generateKey -eq "Y" -or $generateKey -eq "y") {
        $email = Read-Host "Enter email for SSH key"
        ssh-keygen -t ed25519 -C $email -f (Join-Path $sshPath "id_ed25519")
        Write-Success "SSH key pair generated"
        Write-Host "`nPublic key:" -ForegroundColor Cyan
        Get-Content (Join-Path $sshPath "id_ed25519.pub")
    }

    return $true
}

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

function Initialize-ShellEnvironment {
    Write-Step "Configuring shell environment..."

    $profilePath = Join-Path "C:\Users\$NewUsername" "Documents\PowerShell"
    $profileFile = Join-Path $profilePath "Microsoft.PowerShell_profile.ps1"

    if ($DryRun) {
        Write-Log "[DRY RUN] Would create PowerShell profile: $profileFile"
        return $true
    }

    # Create PowerShell profile directory
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType Directory -Force | Out-Null
        Write-Log "Created PowerShell profile directory"
    }

    # Create basic profile
    $profileContent = @"
# PowerShell Profile for $NewUsername
# Created: $($Global:Config.SetupDate)
# Generated by: New-WindowsUserEnvironment.ps1

# Set prompt
function prompt {
    `$path = Get-Location
    Write-Host "PS " -NoNewline -ForegroundColor Green
    Write-Host "`$path" -NoNewline -ForegroundColor Cyan
    Write-Host " >" -NoNewline -ForegroundColor Green
    return " "
}

# Aliases
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name vim -Value notepad

# Environment
`$env:EDITOR = "code"

# Welcome message
Write-Host "Welcome to PowerShell, $NewUsername!" -ForegroundColor Cyan
Write-Host "Profile loaded from: `$PROFILE" -ForegroundColor Gray

"@

    Set-Content -Path $profileFile -Value $profileContent
    Write-Success "PowerShell profile created: $profileFile"

    # Configure MSYS2 if installed
    $msys2Path = "C:\msys64"
    if (Test-Path $msys2Path) {
        Write-Log "MSYS2 detected. Configuring..."

        $bashrcPath = Join-Path "C:\Users\$NewUsername" ".bashrc"
        $bashrcContent = @"
# .bashrc for $NewUsername
# Created: $($Global:Config.SetupDate)

# Set HOME
export HOME="/c/Users/$NewUsername"

# Aliases
alias ll='ls -la'
alias gs='git status'
alias gp='git pull'

# Prompt
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '

"@
        Set-Content -Path $bashrcPath -Value $bashrcContent
        Write-Log "Created .bashrc: $bashrcPath"
    }

    return $true
}

# =============================================================================
# VERIFICATION
# =============================================================================

function Test-Setup {
    Write-Step "Verifying setup..."

    $checks = @()

    # Check user exists
    try {
        $user = Get-LocalUser -Name $NewUsername
        $checks += @{Name = "User Account"; Status = $true; Message = "User exists" }
    }
    catch {
        $checks += @{Name = "User Account"; Status = $false; Message = "User not found" }
    }

    # Check user profile directory
    $profilePath = "C:\Users\$NewUsername"
    if (Test-Path $profilePath) {
        $checks += @{Name = "Profile Directory"; Status = $true; Message = $profilePath }
    }
    else {
        $checks += @{Name = "Profile Directory"; Status = $false; Message = "Not found" }
    }

    # Check group memberships
    try {
        $groups = Get-LocalGroup | Where-Object {
            (Get-LocalGroupMember -Group $_.Name | Where-Object { $_.Name -like "*$NewUsername" }).Count -gt 0
        }
        $groupNames = $groups.Name -join ", "
        $checks += @{Name = "Group Memberships"; Status = $true; Message = $groupNames }
    }
    catch {
        $checks += @{Name = "Group Memberships"; Status = $false; Message = "Could not verify" }
    }

    # Check environment variables
    $homeVar = [Environment]::GetEnvironmentVariable("HOME", [EnvironmentVariableTarget]::User)
    if ($homeVar) {
        $checks += @{Name = "HOME Variable"; Status = $true; Message = $homeVar }
    }
    else {
        $checks += @{Name = "HOME Variable"; Status = $false; Message = "Not set" }
    }

    # Display results
    Write-Log ""
    Write-Log "Setup Verification Results:"
    Write-Log "-" 80

    foreach ($check in $checks) {
        $status = if ($check.Status) { "[PASS]" } else { "[FAIL]" }
        $color = if ($check.Status) { "Green" } else { "Red" }
        Write-Host "$status $($check.Name): $($check.Message)" -ForegroundColor $color
        Write-Log "$status $($check.Name): $($check.Message)"
    }

    $passCount = ($checks | Where-Object { $_.Status }).Count
    $totalCount = $checks.Count

    Write-Log ""
    Write-Log "Verification: $passCount/$totalCount checks passed"

    return ($passCount -eq $totalCount)
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

function Invoke-Setup {
    Initialize-Logging

    Write-Host "`n"
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Windows 11 User Environment Setup                           ║" -ForegroundColor Cyan
    Write-Host "║  Version $($Global:Config.ScriptVersion)                                               ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Display setup information
    Write-Host "Setup Configuration:" -ForegroundColor Yellow
    Write-Host "  Target User:    $NewUsername" -ForegroundColor White
    Write-Host "  Full Name:      $(if ($UserFullName) { $UserFullName } else { 'Not specified' })" -ForegroundColor White
    Write-Host "  Setup Profile:  $SetupProfile" -ForegroundColor White
    Write-Host "  Dry Run:        $DryRun" -ForegroundColor White
    Write-Host "  Log File:       $($Global:LogFilePath)" -ForegroundColor White
    Write-Host ""

    if (-not $DryRun) {
        $confirm = Read-Host "Proceed with setup? (Y/N)"
        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-Warning "Setup cancelled by user"
            return
        }
    }

    # Execute setup phases
    $phases = @(
        @{Name = "Pre-flight Checks"; Function = { Test-Prerequisites } }
        @{Name = "System Backup"; Function = { New-SystemBackup } }
        @{Name = "User Account Creation"; Function = { New-UserAccount } }
        @{Name = "Package Manager Initialization"; Function = { Initialize-PackageManagers } }
        @{Name = "Application Installation"; Function = { Install-Applications } }
        @{Name = "Environment Configuration"; Function = { Set-EnvironmentVariables } }
        @{Name = "Git Configuration"; Function = { Initialize-GitConfiguration } }
        @{Name = "SSH Setup"; Function = { Initialize-SSHKeys } }
        @{Name = "Shell Environment"; Function = { Initialize-ShellEnvironment } }
        @{Name = "Verification"; Function = { Test-Setup } }
    )

    $phaseResults = @()

    foreach ($phase in $phases) {
        Write-Log ""
        Write-Log "=" 80
        Write-Log "PHASE: $($phase.Name)"
        Write-Log "=" 80

        try {
            $result = & $phase.Function
            $phaseResults += @{Name = $phase.Name; Success = $result }

            if (-not $result) {
                Write-Warning "Phase '$($phase.Name)' completed with warnings or errors"

                if (-not $DryRun) {
                    $continue = Read-Host "Continue with next phase? (Y/N)"
                    if ($continue -ne "Y" -and $continue -ne "y") {
                        Write-ErrorLog "Setup aborted by user after phase: $($phase.Name)"
                        break
                    }
                }
            }
        }
        catch {
            Write-ErrorLog "Phase '$($phase.Name)' failed with exception: $_"
            $phaseResults += @{Name = $phase.Name; Success = $false }

            if (-not $DryRun) {
                $continue = Read-Host "Continue with next phase? (Y/N)"
                if ($continue -ne "Y" -and $continue -ne "y") {
                    Write-ErrorLog "Setup aborted by user after phase failure: $($phase.Name)"
                    break
                }
            }
        }
    }

    # Summary
    Write-Log ""
    Write-Log "=" 80
    Write-Log "SETUP SUMMARY"
    Write-Log "=" 80

    foreach ($result in $phaseResults) {
        $status = if ($result.Success) { "[SUCCESS]" } else { "[FAILED]" }
        Write-Log "$status $($result.Name)"
    }

    $successCount = ($phaseResults | Where-Object { $_.Success }).Count
    $totalCount = $phaseResults.Count

    Write-Log ""
    Write-Log "Completed: $successCount/$totalCount phases successful"
    Write-Log "Log file: $($Global:LogFilePath)"

    if ($successCount -eq $totalCount) {
        Write-Success "Setup completed successfully!"
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "1. Log out of the current session" -ForegroundColor White
        Write-Host "2. Log in as user: $NewUsername" -ForegroundColor White
        Write-Host "3. Review the setup log: $($Global:LogFilePath)" -ForegroundColor White
    }
    else {
        Write-Warning "Setup completed with some failures. Please review the log file."
    }
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

try {
    Invoke-Setup
}
catch {
    Write-ErrorLog "Fatal error during setup: $_"
    Write-ErrorLog $_.ScriptStackTrace
    exit 1
}
