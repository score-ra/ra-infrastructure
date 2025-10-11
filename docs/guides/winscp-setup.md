# WinSCP Setup and Integration Guide

Complete setup guide for integrating WinSCP with Symphony Core Infrastructure for secure file transfers and remote server management.

## Table of Contents

1. [Installation](#installation)
2. [Initial Configuration](#initial-configuration)
3. [Environment Setup](#environment-setup)
4. [SSH Key Configuration](#ssh-key-configuration)
5. [Session Management](#session-management)
6. [Automation Scripts](#automation-scripts)
7. [Security Best Practices](#security-best-practices)
8. [Troubleshooting](#troubleshooting)

## Installation

### Install WinSCP

1. **Download WinSCP:**
   - Visit https://winscp.net/eng/downloads.php
   - Download the latest stable version (recommended: Installation package)

2. **Install WinSCP:**
   ```bash
   # Run the installer with admin privileges
   # Choose "Full installation" to include PowerShell integration
   ```

3. **Install PowerShell Module (for automation):**
   ```powershell
   # Option 1: Install during WinSCP installation (recommended)
   # Option 2: Manual installation
   Import-Module "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
   ```

### Verify Installation

```powershell
# Test PowerShell module
Import-Module WinSCP
Get-Command -Module WinSCP
```

## Initial Configuration

### Project Structure Integration

The WinSCP integration adds these directories to your infrastructure:

```
sc-infrastructure/
├── scripts/
│   ├── file-transfer/           # WinSCP automation scripts
│   │   ├── winscp-deploy.ps1    # Deployment automation
│   │   ├── winscp-backup.ps1    # Backup operations
│   │   ├── winscp-sync.ps1      # Configuration sync
│   │   ├── deployment.log       # Deployment history
│   │   └── sync.log             # Sync operation history
│   └── winscp/                  # WinSCP configurations
│       ├── sessions/            # Saved session files
│       ├── profiles/            # Connection profiles
│       └── templates/           # Configuration templates
├── environments/
│   ├── {env}/
│   │   ├── ssh-keys/           # SSH private keys (gitignored)
│   │   └── .env                # Enhanced with WinSCP settings
└── backups/                    # Local backup storage
```

## Environment Setup

### Enhanced Environment Configuration

Add these settings to your environment files (`environments/{env}/.env`):

```env
# WinSCP/SFTP Configuration
DEPLOY_HOST=your-server.example.com
DEPLOY_USER=deployment_user
SSH_KEY_PATH=./environments/production/ssh-keys/deploy_key
SSH_HOST_KEY_FINGERPRINT=ssh-rsa 2048 xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx

# Remote paths
REMOTE_BASE_PATH=/opt/symphony-core
REMOTE_BACKUP_PATH=/opt/symphony-core/backups

# WinSCP logging
WINSCP_LOG_PATH=./scripts/file-transfer/logs
```

### Environment-Specific Examples

#### Development Environment
```env
# environments/development/.env
DEPLOY_HOST=dev.symphony-core.local
DEPLOY_USER=devuser
SSH_KEY_PATH=./environments/development/ssh-keys/dev_key
REMOTE_BASE_PATH=/home/devuser/symphony-core
```

#### Staging Environment
```env
# environments/staging/.env
DEPLOY_HOST=staging.symphony-core.com
DEPLOY_USER=stage_deploy
SSH_KEY_PATH=./environments/staging/ssh-keys/staging_key
REMOTE_BASE_PATH=/opt/symphony-core-staging
```

#### Production Environment
```env
# environments/production/.env
DEPLOY_HOST=prod.symphony-core.com
DEPLOY_USER=prod_deploy
SSH_KEY_PATH=./environments/production/ssh-keys/prod_key
REMOTE_BASE_PATH=/opt/symphony-core
# Additional security settings for production
```

## SSH Key Configuration

### Generate SSH Keys

```bash
# Generate environment-specific SSH key pairs
ssh-keygen -t rsa -b 4096 -C "symphony-core-deployment" -f ./environments/production/ssh-keys/prod_key

# Set appropriate permissions
chmod 600 ./environments/production/ssh-keys/prod_key
chmod 644 ./environments/production/ssh-keys/prod_key.pub
```

### Deploy Public Keys

```bash
# Copy public key to target server
ssh-copy-id -i ./environments/production/ssh-keys/prod_key.pub user@server

# Or manually append to authorized_keys
cat ./environments/production/ssh-keys/prod_key.pub | ssh user@server "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### Get SSH Host Key Fingerprint

```bash
# Get server fingerprint for configuration
ssh-keyscan -t rsa your-server.com | ssh-keygen -lf -
```

## Session Management

### Create Environment Session

1. **Copy Template:**
   ```powershell
   Copy-Item scripts\winscp\templates\session-template.ini scripts\winscp\sessions\production.ini
   ```

2. **Configure Session:**
   Edit `scripts\winscp\sessions\production.ini` with your environment values:
   ```ini
   [Session]
   Name=SymphonyCore-Production
   HostName=prod.symphony-core.com
   UserName=prod_deploy
   PrivateKeyFile=C:\path\to\sc-infrastructure\environments\production\ssh-keys\prod_key
   SshHostKeyFingerprint=ssh-rsa 2048 xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
   ```

3. **Import Session to WinSCP:**
   - Open WinSCP GUI
   - Go to Tools → Import Sites
   - Select your `.ini` file

## Automation Scripts

### Deployment Script

Deploy application components to remote servers:

```powershell
# Deploy all components to production
.\scripts\file-transfer\winscp-deploy.ps1 -Environment production -DeployType all

# Deploy only Docker Compose files to staging
.\scripts\file-transfer\winscp-deploy.ps1 -Environment staging -DeployType docker-compose

# Dry run deployment to development
.\scripts\file-transfer\winscp-deploy.ps1 -Environment development -DeployType all -DryRun
```

### Backup Script

Manage backups between local and remote systems:

```powershell
# Upload full backup to production
.\scripts\file-transfer\winscp-backup.ps1 -Operation upload -Environment production -BackupType all -Compress

# Download database backup from staging
.\scripts\file-transfer\winscp-backup.ps1 -Operation download -Environment staging -BackupType database

# Sync backup directories
.\scripts\file-transfer\winscp-backup.ps1 -Operation sync -Environment production -BackupType all
```

### Configuration Sync Script

Synchronize configuration files:

```powershell
# Push local configs to production
.\scripts\file-transfer\winscp-sync.ps1 -Environment production -SyncDirection push -SyncType configs

# Pull remote scripts to local development
.\scripts\file-transfer\winscp-sync.ps1 -Environment development -SyncDirection pull -SyncType scripts

# Bi-directional sync with delete obsolete files
.\scripts\file-transfer\winscp-sync.ps1 -Environment staging -SyncDirection both -SyncType all -DeleteObsolete
```

## Security Best Practices

### SSH Key Security

1. **Use Different Keys per Environment:**
   ```
   environments/
   ├── development/ssh-keys/dev_key
   ├── staging/ssh-keys/staging_key
   └── production/ssh-keys/prod_key
   ```

2. **Key Rotation:**
   ```bash
   # Schedule regular key rotation
   # Generate new key → Deploy to server → Update scripts → Remove old key
   ```

3. **Restrict Key Usage:**
   ```bash
   # Server-side: ~/.ssh/authorized_keys
   command="/usr/local/bin/deployment-only.sh",restrict ssh-rsa AAAAB3...
   ```

### Connection Security

1. **Use SSH Host Key Verification:**
   - Always specify `SSH_HOST_KEY_FINGERPRINT` in environment config
   - Verify fingerprint matches server's actual key

2. **Connection Timeouts:**
   - Set reasonable connection timeouts (15-30 seconds)
   - Use connection retry logic in scripts

3. **Logging:**
   ```powershell
   # Enable detailed logging for troubleshooting
   $sessionOptions.DebugLogPath = ".\logs\winscp-debug.log"
   ```

### File Transfer Security

1. **Verify Transfers:**
   ```powershell
   # Always check transfer results
   if ($transferResult.IsSuccess) {
       Write-Host "Transfer successful"
   } else {
       Write-Error "Transfer failed"
   }
   ```

2. **Sensitive Data Handling:**
   ```powershell
   # Never transfer sensitive files in plain text
   # Use compression and encryption for backup files
   ```

## Common Workflows

### Deploy New Application Version

```powershell
# Complete deployment workflow
# 1. Deploy docker-compose files
.\scripts\file-transfer\winscp-deploy.ps1 -Environment production -DeployType docker-compose

# 2. Deploy updated scripts
.\scripts\file-transfer\winscp-deploy.ps1 -Environment production -DeployType scripts

# 3. Sync configuration changes
.\scripts\file-transfer\winscp-sync.ps1 -Environment production -SyncDirection push -SyncType configs

# 4. Create backup before restart
.\scripts\file-transfer\winscp-backup.ps1 -Operation upload -Environment production -BackupType database -Compress
```

### Setup New Environment

```powershell
# 1. Create environment configuration
Copy-Item environments\shared\.env.template environments\newenv\.env
# Edit environments\newenv\.env with environment-specific values

# 2. Generate SSH keys
ssh-keygen -t rsa -b 4096 -f environments\newenv\ssh-keys\deploy_key

# 3. Deploy public key to server
ssh-copy-id -i environments\newenv\ssh-keys\deploy_key.pub user@server

# 4. Initial deployment
.\scripts\file-transfer\winscp-deploy.ps1 -Environment newenv -DeployType all
```

## Troubleshooting

### Common Issues

1. **Connection Refused:**
   ```
   Error: SSH connection failed
   Solutions:
   - Verify server is running and accessible
   - Check firewall settings on server
   - Verify SSH service is running on target port
   ```

2. **Authentication Failed:**
   ```
   Error: Authentication failed
   Solutions:
   - Verify SSH key permissions (600 for private key)
   - Check public key is in server's authorized_keys
   - Verify SSH key path in environment config
   ```

3. **Host Key Verification Failed:**
   ```
   Error: Host key fingerprint mismatch
   Solutions:
   - Get current server fingerprint: ssh-keyscan -t rsa server
   - Update SSH_HOST_KEY_FINGERPRINT in environment config
   ```

4. **Transfer Interrupted:**
   ```
   Error: Transfer failed or incomplete
   Solutions:
   - Check network connectivity
   - Verify sufficient disk space on both ends
   - Increase timeout values in scripts
   ```

### Debug Mode

Enable detailed logging for troubleshooting:

```powershell
# Add to script for debugging
$sessionOptions.DebugLogPath = ".\logs\debug.log"
$sessionOptions.DebugLogLevel = 1  # 0=None, 1=Normal, 2=Verbose

# View logs
Get-Content .\logs\debug.log -Tail 50
```

### Log Analysis

```powershell
# Check deployment logs
Get-Content .\scripts\file-transfer\deployment.log

# Check sync logs
Get-Content .\scripts\file-transfer\sync.log

# Filter recent errors
Get-Content .\logs\winscp.log | Where-Object { $_ -match "ERROR" } | Select-Object -Last 10
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Deploy with WinSCP
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Production
        shell: pwsh
        run: |
          .\scripts\file-transfer\winscp-deploy.ps1 -Environment production -DeployType all
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

---

This setup provides secure, automated file transfer capabilities integrated with your Symphony Core Infrastructure, following Windows-native patterns and PowerShell automation principles.