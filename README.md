# RA Infrastructure

Personal infrastructure tools and scripts for development environment management, documentation workflows, and external application administration.

## Overview

This repository contains personal tools, scripts, and documentation that support development workflows but are not specific to any particular project infrastructure. These tools were extracted from the sc-infrastructure repository during a hardening sprint to maintain clear separation of concerns.

## Repository Scope

This repository includes:
- Personal development environment setup and configuration tools
- Documentation workflow automation (Obsidian, knowledge management)
- Windows system administration scripts
- External application management (WordPress, file transfers)
- General-purpose utility scripts and guides

## Repository Structure

```
ra-infrastructure/
├── docs/                      # Personal guides and documentation
│   └── guides/                # How-to guides
│       ├── OBSIDIAN-VAULT-SETUP-GUIDE.md
│       ├── windows-powershell-remoting-setup.md
│       └── winscp-setup.md
├── scripts/                   # Personal automation scripts
│   ├── setup/                 # Environment setup scripts
│   │   ├── New-WindowsUserEnvironment.ps1
│   │   ├── Update-DownloadsFolder.ps1
│   │   └── setup-obsidian-vault.sh
│   └── file-transfer/         # File transfer and backup scripts
│       ├── wordpress-backup.ps1
│       └── wordpress-backup-simple.ps1
└── services/                  # External service configurations
    └── wordpress/             # WordPress management
```

## Contents

### Documentation Guides

#### Obsidian Vault Setup Guide
- **File:** `docs/guides/OBSIDIAN-VAULT-SETUP-GUIDE.md`
- **Purpose:** Comprehensive guide for creating new Obsidian vaults with pre-configured plugins
- **Use Cases:** Documentation workflows, knowledge management, technical writing

#### Windows PowerShell Remoting Setup
- **File:** `docs/guides/windows-powershell-remoting-setup.md`
- **Purpose:** Guide for enabling PowerShell remoting on Windows computers
- **Use Cases:** Remote Windows administration, system management

#### WinSCP Setup and Integration
- **File:** `docs/guides/winscp-setup.md`
- **Purpose:** Complete setup guide for WinSCP file transfers and remote server management
- **Use Cases:** SFTP/FTP file transfers, remote deployments, backups

### Setup Scripts

#### Windows User Environment Setup
- **File:** `scripts/setup/New-WindowsUserEnvironment.ps1`
- **Purpose:** Automated Windows 11 user account setup with development tools
- **Features:**
  - User account creation with appropriate permissions
  - Development tool installation (Git, VS Code, Docker, Node.js, Python, etc.)
  - Environment variable configuration
  - Git and SSH setup
  - Shell environment customization
- **Profiles:** Developer, Admin, Standard

#### Downloads Folder Configuration
- **File:** `scripts/setup/Update-DownloadsFolder.ps1`
- **Purpose:** Updates Windows Shell Folders registry to set Downloads folder location
- **Use Case:** Fix OneDrive-redirected Downloads folder to default Windows location

#### Obsidian Vault Automation
- **File:** `scripts/setup/setup-obsidian-vault.sh`
- **Purpose:** Automates creation of Obsidian vaults with Excalidraw and Heading Shifter plugins
- **Use Cases:** Rapid vault setup, standardized documentation environments

### File Transfer Scripts

#### WordPress Site Backup
- **File:** `scripts/file-transfer/wordpress-backup.ps1`
- **Purpose:** Downloads WordPress sites from hosting (GoHighLevel/Rocket/FTP)
- **Backup Types:** Full site, wp-content, config, uploads
- **Features:** Compression, incremental backups, transfer statistics

#### WordPress Simple Backup
- **File:** `scripts/file-transfer/wordpress-backup-simple.ps1`
- **Purpose:** Simplified version of WordPress backup script
- **Use Case:** Quick backups without complex configuration

## Usage Examples

### Setting Up a New Windows User Environment

```powershell
# Developer profile with full toolset
.\scripts\setup\New-WindowsUserEnvironment.ps1 -NewUsername "rohit" -UserFullName "Rohit Anand" -SetupProfile "Developer"

# Dry run to see what would be installed
.\scripts\setup\New-WindowsUserEnvironment.ps1 -NewUsername "testuser" -SetupProfile "Developer" -DryRun
```

### Creating a New Obsidian Vault

```bash
# Create vault with pre-configured plugins
./scripts/setup/setup-obsidian-vault.sh /c/Users/Rohit/workspace/new-documentation-vault
```

### Backing Up WordPress Site

```powershell
# Full site backup with compression
.\scripts\file-transfer\wordpress-backup.ps1 -BackupType full -Compress

# Backup only uploads directory
.\scripts\file-transfer\wordpress-backup.ps1 -BackupType uploads -LocalPath ".\backups"
```

### Enabling PowerShell Remoting

```powershell
# On target computer (run as Administrator)
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# On client computer
Enter-PSSession -ComputerName TARGET-PC -Credential (Get-Credential)
```

## Origin and History

These tools were extracted from the `sc-infrastructure` repository on 2025-10-11 during a repository hardening sprint. The goal was to maintain clear separation between:
- Project-specific infrastructure (Symphony Core) → `sc-infrastructure`
- Personal tools and general utilities → `ra-infrastructure` (this repository)

For the complete analysis and rationale, see the hardening sprint report in the sc-infrastructure repository.

## Compatibility

### Operating Systems
- **Windows:** Primary target (Windows 10/11 Pro)
- **Linux/macOS:** Some scripts (bash scripts) are cross-platform

### Requirements
- PowerShell 5.1+ (Windows scripts)
- Git Bash or compatible shell (bash scripts)
- WinSCP (file transfer scripts)
- Obsidian (vault setup scripts)

## Contributing

This is a personal repository, but contributions and suggestions are welcome. When adding new tools:

1. Ensure they are general-purpose utilities, not project-specific
2. Include comprehensive documentation
3. Follow existing script conventions and error handling
4. Test across relevant platforms/environments

## Related Repositories

- **sc-infrastructure:** Symphony Core project infrastructure management
- **ObsidianVault:** Personal knowledge management vault (if separate repo)

## License

Personal use. Individual scripts may have specific licensing depending on their origin.

## Maintenance

**Created:** 2025-10-11
**Owner:** Rohit Anand
**Purpose:** Personal development tools and general-purpose utilities
**Status:** Active

---

**Note:** This repository intentionally excludes project-specific infrastructure code to maintain clear boundaries and improve maintainability.
