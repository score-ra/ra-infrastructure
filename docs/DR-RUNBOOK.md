# Disaster Recovery Runbook

This guide explains how to recover the ra-infrastructure database if something goes wrong. It's written for users who may not be familiar with technical terms - see the [Glossary](#glossary) at the end for definitions.

---

## Overview

| Field | Value |
|-------|-------|
| **Recovery Time Objective (RTO)** | 1 hour |
| **Recovery Point Objective (RPO)** | 24 hours (last daily backup) |
| **Last DR Test** | Not yet performed |
| **Next Scheduled Test** | TBD |
| **Full DR Test Status** | **PENDING** - End-to-end test on separate device required |

**What do RTO and RPO mean?**
- **RTO (1 hour)**: If everything breaks, we can get the system running again within 1 hour
- **RPO (24 hours)**: We might lose up to 24 hours of data (the time since the last backup)

---

## Quick Reference

| What Happened | How Long to Fix | What to Do |
|---------------|-----------------|------------|
| Database container stopped | 2 minutes | [Tier 1](#tier-1-service-restart) - Restart the container |
| Docker crashed | 5 minutes | [Tier 2](#tier-2-docker-restart) - Restart Docker Desktop |
| Database corrupted or deleted | 30 minutes | [Tier 3](#tier-3-database-restore) - Restore from backup |
| Hard drive failed | 1 hour | [Tier 4](#tier-4-full-recovery) - Full recovery on new machine |
| Computer died | 1 hour+ | [Tier 4](#tier-4-full-recovery) - Full recovery on new machine |

---

## Available Scripts

These PowerShell scripts automate common tasks:

| Script | What It Does |
|--------|--------------|
| `scripts\health-check.ps1` | Checks if everything is running properly |
| `scripts\verify-startup.ps1` | Verifies services after computer restart |
| `scripts\backup.ps1 -Type daily` | Creates a backup on your local drive |
| `scripts\backup.ps1 -Type weekly` | Creates a backup and uploads to Google Drive |
| `scripts\restore.ps1 -BackupFile <path>` | Restores database from a backup file |

---

## Pre-Recovery Checklist

Before starting any recovery, gather this information:

- [ ] **What broke?** (container stopped, Docker crashed, data corrupted, etc.)
- [ ] **Do we have backups?** Check: `dir D:\Backups\ra-infrastructure\daily\`
- [ ] **When was the last known working state?**
- [ ] **Does anyone else need to know?** (other systems that use this database)

---

## Tier 1: Service Restart

**When to use:** The database container stopped, but Docker Desktop is still running (you can see the Docker whale icon in your system tray)

**Time estimate:** 2 minutes

### Steps

**Step 1: Open PowerShell**

Press `Windows + X`, then click "Windows PowerShell" or "Terminal"

**Step 2: Navigate to the project folder**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
```

**Step 3: Check what's running**

```powershell
docker-compose ps
```

**What you should see:** A table showing containers. Look for `inventory-db` - if it says "Exited" instead of "Up", it needs to be restarted.

**Step 4: Restart the container**

```powershell
docker-compose restart postgres
```

**What you should see:** Messages about stopping and starting the container.

**Step 5: Verify it's working**

```powershell
docker-compose ps
```

**What you should see:** `inventory-db` should show "Up" and "(healthy)"

```powershell
inv db stats
```

**What you should see:** A table showing counts of organizations, sites, devices, etc.

**Step 6: If it still doesn't work, check the logs**

```powershell
docker-compose logs --tail=50 postgres
```

This shows the last 50 lines of log messages, which might explain what went wrong.

### Success Checklist
- [ ] Container status shows: `running (healthy)`
- [ ] `inv db stats` shows data counts (not an error)

---

## Tier 2: Docker Restart

**When to use:** Docker Desktop itself crashed or is frozen (the whale icon in system tray is unresponsive or missing)

**Time estimate:** 5 minutes

### Steps

**Step 1: Check if Docker is running**

Look in your system tray (bottom-right corner of screen, near the clock). Do you see a whale icon?

- **If yes but unresponsive:** Right-click it. If nothing happens, Docker is frozen.
- **If no whale icon:** Docker isn't running.

**Step 2: Restart Docker Desktop**

**Option A (Easiest):**
1. Right-click the whale icon in system tray
2. Click "Restart"
3. Wait 1-2 minutes

**Option B (If Option A doesn't work):**
1. Open Task Manager: Press `Ctrl + Shift + Esc`
2. Find "Docker Desktop" in the list
3. Click it, then click "End Task"
4. Open the Start Menu
5. Type "Docker Desktop" and press Enter
6. Wait 1-2 minutes for it to start

**Step 3: Wait for Docker to be ready**

The whale icon will stop animating when Docker is ready. This usually takes 1-2 minutes.

**Step 4: Check if containers started automatically**

Open PowerShell and run:

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
docker-compose ps
```

**What you should see:** Both `inventory-db` and `inventory-pgadmin` should show "Up"

**Step 5: If containers didn't start, start them manually**

```powershell
docker-compose up -d
```

**What you should see:** Messages about creating/starting containers

**Step 6: Verify everything is working**

```powershell
inv db stats
```

**What you should see:** A table showing counts of organizations, sites, devices, etc.

### Success Checklist
- [ ] Docker Desktop whale icon is visible in system tray
- [ ] Both containers show: `running (healthy)`
- [ ] `inv db stats` shows data counts

---

## Tier 3: Database Restore

**When to use:**
- Database is corrupted (queries return errors)
- Data was accidentally deleted
- The database volume was lost

**Time estimate:** 30 minutes

### Prerequisites
- You have a backup file in `D:\Backups\ra-infrastructure\daily\`
- Docker Desktop is running

### Option A: Using the Restore Script (Recommended)

This is the easiest method.

**Step 1: Open PowerShell and navigate to the project**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure
```

**Step 2: Find your backup files**

```powershell
dir D:\Backups\ra-infrastructure\daily\ | Sort-Object LastWriteTime -Descending
```

**What you should see:** A list of backup files with dates, like:
```
inventory_2025-11-27.dump.gz
inventory_2025-11-26.dump.gz
```

**Step 3: Run the restore script**

Replace the date with your most recent backup:

```powershell
.\scripts\restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\daily\inventory_2025-11-27.dump.gz"
```

**What happens:**
1. The script creates a safety backup first (in case something goes wrong)
2. It asks you to confirm - type `Y` and press Enter
3. It restores the database
4. It verifies the restoration worked

**Step 4: Verify the restoration**

```powershell
inv db stats
inv org list
```

**What you should see:** Data counts and a list of organizations

### Option B: Manual Steps

Use this if the restore script doesn't work.

**Step 1: Stop all services**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
docker-compose down
```

**Step 2: Remove the corrupted database volume** (if needed)

```powershell
docker volume rm inventory_postgres_data
```

**Note:** This deletes all data in the database. Only do this if the data is already corrupted/lost.

**Step 3: Start a fresh database container**

```powershell
docker-compose up -d postgres
```

Wait about 30 seconds, then check it's healthy:

```powershell
docker-compose ps
```

**What you should see:** `inventory-db` with status "Up" and "(healthy)"

**Step 4: Restore using the script**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure
.\scripts\restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\daily\inventory_2025-11-27.dump.gz" -Force
```

**Step 5: Start all services**

```powershell
cd docker
docker-compose up -d
```

**Step 6: Verify**

```powershell
inv db stats
inv org list
inv device list
```

### Success Checklist
- [ ] All containers running and healthy
- [ ] `inv db stats` shows expected record counts
- [ ] Data queries return expected results

---

## Tier 4: Full Recovery

**When to use:**
- Hard drive failed
- Computer died completely
- Setting up on a brand new machine

**Time estimate:** 1 hour

This section guides you through recovering everything from scratch. Follow each step carefully.

---

### Step 1: Check Prerequisites

Before starting, make sure you have access to:

- [ ] **Google Drive backup** - The `ra-infrastructure-backup` Shared Drive
- [ ] **GitHub account** - Access to the repository
- [ ] **Windows computer** - With administrator access

---

### Step 2: Install Required Software

You need to install four programs. For each one, I'll show you how to check if it's already installed.

#### 2a: Install Docker Desktop

**Check if installed:** Open PowerShell and type:
```powershell
docker --version
```

**If you see a version number** (like `Docker version 24.0.6`): Docker is installed. Skip to 2b.

**If you see an error** ("docker is not recognized"): Install Docker:

1. Open your web browser
2. Go to: https://www.docker.com/products/docker-desktop
3. Click the "Download for Windows" button
4. Run the downloaded installer
5. Follow the installation wizard (accept all defaults)
6. **Restart your computer when prompted**
7. After restart, Docker Desktop should start automatically (look for whale icon in system tray)

**Wait for Docker to be ready** - the whale icon will stop animating (takes 1-2 minutes)

#### 2b: Install Git

**Check if installed:** Open PowerShell and type:
```powershell
git --version
```

**If you see a version number** (like `git version 2.42.0`): Git is installed. Skip to 2c.

**If you see an error**: Install Git:

1. Go to: https://git-scm.com/download/win
2. Click "Click here to download" (the download starts automatically)
3. Run the installer
4. Click "Next" through all screens (the defaults are fine)
5. Click "Install"
6. **Close and reopen PowerShell** for the changes to take effect

#### 2c: Install Python

**Check if installed:** Open PowerShell and type:
```powershell
python --version
```

**If you see version 3.11 or higher** (like `Python 3.11.5`): Python is installed. Skip to 2d.

**If you see an error or an older version**: Install Python:

1. Go to: https://www.python.org/downloads/
2. Click the big yellow "Download Python 3.x.x" button
3. Run the installer
4. **IMPORTANT:** Check the box that says "Add Python to PATH"
5. Click "Install Now"
6. **Close and reopen PowerShell** for the changes to take effect

#### 2d: Install rclone (for Google Drive access)

**Check if installed:** Open PowerShell and type:
```powershell
rclone --version
```

**If you see a version number**: rclone is installed. Skip to Step 3.

**If you see an error**: Install rclone:

```powershell
winget install rclone
```

**If winget doesn't work**, download manually:
1. Go to: https://rclone.org/downloads/
2. Download "Intel/AMD - 64 Bit" for Windows
3. Extract the zip file
4. Move `rclone.exe` to a folder in your PATH (like `C:\Windows`)

---

### Step 3: Clone the Repository

This downloads all the code and scripts from GitHub.

**Step 3a: Create the workspace folder** (if it doesn't exist)

```powershell
if (-not (Test-Path "c:\Users\ranand\workspace\personal\software")) {
    New-Item -Path "c:\Users\ranand\workspace\personal\software" -ItemType Directory -Force
}
```

**Step 3b: Navigate to the folder**

```powershell
cd c:\Users\ranand\workspace\personal\software
```

**Step 3c: Clone the repository**

```powershell
git clone https://github.com/score-ra/ra-infrastructure.git
```

**What you should see:** Messages about cloning and receiving objects.

**Step 3d: Enter the project folder**

```powershell
cd ra-infrastructure
```

---

### Step 4: Set Up Environment

**Step 4a: Copy the environment template**

```powershell
Copy-Item docker\.env.example docker\.env
```

**Step 4b: Edit the environment file** (optional - only if you need custom settings)

```powershell
notepad docker\.env
```

The default settings usually work. Close Notepad when done.

---

### Step 5: Download Backup from Google Drive

You can download the backup either through your web browser (easier) or using rclone (faster for large files).

#### Option A: Download via Web Browser (Recommended for first-time users)

1. Open your web browser
2. Go to: https://drive.google.com/drive/folders/0ABnNNU5bNqUmUk9PVA
3. You'll see the `ra-infrastructure-backup` Shared Drive
4. Find the most recent backup file (it will have a date in the name, like `inventory_2025-11-27_weekly.dump.gz`)
5. Right-click the file and select "Download"
6. Save it to: `D:\Backups\ra-infrastructure\restore\`

**If the restore folder doesn't exist, create it:**

```powershell
New-Item -Path "D:\Backups\ra-infrastructure\restore" -ItemType Directory -Force
```

Then move the downloaded file to that folder.

#### Option B: Download via rclone (Faster, but requires setup)

**Step 5b-1: Configure rclone** (first time only)

```powershell
rclone config
```

Follow these prompts:
1. Type `n` for new remote, press Enter
2. Name: type `gdrive`, press Enter
3. Storage type: type `drive`, press Enter (or find the number for "Google Drive")
4. Client ID: just press Enter (leave blank)
5. Client secret: just press Enter (leave blank)
6. Scope: type `1` for full access, press Enter
7. Root folder: just press Enter (leave blank)
8. Service account: just press Enter (leave blank)
9. Advanced config: type `n`, press Enter
10. Auto config: type `y`, press Enter
11. **A browser window will open** - sign in to your Google account and allow access
12. Configure as Shared Drive: type `y`, press Enter
13. Choose the Shared Drive: find `ra-infrastructure-backup` in the list and type its number
14. Confirm: type `y`, press Enter
15. Quit config: type `q`, press Enter

**Step 5b-2: Create the restore folder**

```powershell
New-Item -Path "D:\Backups\ra-infrastructure\restore" -ItemType Directory -Force
```

**Step 5b-3: Download the backup**

First, list available backups:

```powershell
rclone ls gdrive:
```

Then download the most recent one (replace the filename with what you see):

```powershell
rclone copy gdrive:inventory_2025-11-27_weekly.dump.gz D:\Backups\ra-infrastructure\restore\
```

---

### Step 6: Start the Database

**Step 6a: Navigate to the docker folder**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
```

**Step 6b: Start the PostgreSQL container**

```powershell
docker-compose up -d postgres
```

**What you should see:** Messages about creating network and container.

**Step 6c: Wait for the database to be ready**

This takes about 30 seconds. Check the status:

```powershell
docker-compose ps
```

**What you should see:** `inventory-db` with status "Up" and "(healthy)"

If it shows "(health: starting)", wait 15 seconds and check again.

---

### Step 7: Restore the Database

**Step 7a: Navigate to the project root**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure
```

**Step 7b: Find your backup file**

```powershell
dir D:\Backups\ra-infrastructure\restore\
```

Note the exact filename.

**Step 7c: Run the restore**

```powershell
.\scripts\restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\restore\inventory_2025-11-27_weekly.dump.gz" -SkipSafetyBackup -Force
```

**Note:** We use `-SkipSafetyBackup` because on a fresh install there's no existing data to back up.

**What you should see:** Messages about restoring and verifying the database.

---

### Step 8: Start All Services

```powershell
cd docker
docker-compose up -d
```

This starts the pgAdmin web interface as well.

---

### Step 9: Install the CLI Tool

**Step 9a: Navigate to the CLI folder**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\cli
```

**Step 9b: Install the CLI**

```powershell
pip install -e ".[dev]"
```

**What you should see:** Messages about installing packages. This may take a minute.

---

### Step 10: Verify Everything Works

**Step 10a: Check database statistics**

```powershell
inv db stats
```

**What you should see:** A table showing counts of organizations, sites, zones, devices, etc.

**Step 10b: List organizations**

```powershell
inv org list
```

**What you should see:** A list of organizations in the database.

**Step 10c: List devices**

```powershell
inv device list
```

**What you should see:** A list of devices in the database.

---

### Step 11: Set Up Automation (Optional but Recommended)

After recovery, you should set up automatic backups again.

**Step 11a: Install backup tasks**

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure
.\scripts\install-backup-tasks.ps1
```

**Step 11b: Install health check task**

```powershell
.\scripts\install-health-check-task.ps1
```

**Step 11c: Verify tasks are installed**

```powershell
Get-ScheduledTask -TaskName 'ra-infrastructure*' | Format-Table TaskName, State
```

**What you should see:** Three tasks with state "Ready"

---

### Success Checklist

- [ ] Docker Desktop is running (whale icon in system tray)
- [ ] Both containers are healthy (`docker-compose ps` shows "Up (healthy)")
- [ ] Database has data (`inv db stats` shows record counts)
- [ ] CLI works (`inv org list` shows organizations)
- [ ] Backup automation is configured (optional)

---

## DR Testing Procedure

### Quarterly Test Checklist

Perform this test every 3 months to make sure recovery procedures still work.

**Preparation:**
- [ ] Create a fresh backup: `.\scripts\backup.ps1 -Type daily -Verify`
- [ ] Write down current record counts: `inv db stats`
- [ ] Set aside 1 hour for testing

**Test Execution:**

1. **Simulate failure**
   ```powershell
   cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
   docker-compose down
   docker volume rm inventory_postgres_data
   ```

2. **Start your timer** and follow [Tier 3](#tier-3-database-restore) recovery steps

3. **Verify recovery**
   ```powershell
   inv db stats
   ```
   Compare the counts to what you wrote down before.

**After the test:**
- [ ] Record how long it took: _____ minutes
- [ ] Write down any problems you encountered
- [ ] Update this document if steps need to change

### Test Results Log

| Date | Test Type | Recovery Time | Issues | Tester |
|------|-----------|---------------|--------|--------|
| | | | | |

---

## Troubleshooting

### "docker is not recognized"

**Cause:** Docker isn't installed, or PowerShell was opened before Docker was installed.

**Fix:**
1. Install Docker Desktop (see [Step 2a](#2a-install-docker-desktop))
2. Close PowerShell and open a new window

### "Container is not healthy" or "(health: starting)"

**Cause:** The database is still starting up.

**Fix:** Wait 30-60 seconds and check again. If it still shows "starting" after 2 minutes, check the logs:
```powershell
docker-compose logs postgres
```

### "Permission denied" or "Access denied"

**Cause:** You need administrator privileges.

**Fix:** Close PowerShell and reopen it as Administrator:
1. Right-click the PowerShell icon
2. Select "Run as administrator"

### "Backup file not found"

**Cause:** The file path is wrong, or the file doesn't exist.

**Fix:**
1. Check the exact filename: `dir D:\Backups\ra-infrastructure\daily\`
2. Make sure you typed the path correctly (watch for typos)

### "Cannot connect to database"

**Cause:** The database container isn't running.

**Fix:**
1. Check if Docker is running (whale icon in system tray)
2. Check container status: `docker-compose ps`
3. Start containers if needed: `docker-compose up -d`

### "rclone: command not found"

**Cause:** rclone isn't installed or isn't in your PATH.

**Fix:**
1. Install rclone: `winget install rclone`
2. Close and reopen PowerShell

### "inv: command not found"

**Cause:** The CLI tool isn't installed.

**Fix:**
```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\cli
pip install -e ".[dev]"
```

---

## Emergency Contacts

| Role | Contact | When to Contact |
|------|---------|-----------------|
| Primary Admin | TBD | Any Tier 3+ incident |
| Backup Admin | TBD | If primary unavailable |

---

## Appendix: Useful Commands

### Check Container Health
```powershell
docker inspect inventory-db --format='{{.State.Health.Status}}'
```

### View Recent Logs
```powershell
docker-compose logs --tail=100 postgres
```

### Check Disk Space
```powershell
docker system df
Get-PSDrive D
```

### List Backups
```powershell
dir D:\Backups\ra-infrastructure\daily\ | Sort-Object LastWriteTime -Descending | Select-Object -First 10
```

### Test Database Connection
```powershell
$env:PGPASSWORD = "inventory_dev_password"
psql -h localhost -U inventory -d ra_inventory -c "SELECT 1"
```

### Force Remove All Docker Resources (DANGEROUS)
```powershell
# WARNING: This deletes ALL Docker data on your computer
docker-compose down -v
docker system prune -a --volumes
```

---

## Glossary

| Term | Definition |
|------|------------|
| **Backup** | A copy of your data saved to a file, so you can restore it later if something goes wrong |
| **CLI** | Command Line Interface - a way to run programs by typing commands instead of clicking buttons |
| **Container** | A lightweight package that contains an application and everything it needs to run. Think of it as a mini virtual computer. |
| **Docker** | Software that runs containers. Docker Desktop is the Windows application for managing Docker. |
| **Docker Compose** | A tool for defining and running multiple containers together |
| **Google Drive** | Google's cloud storage service where we keep off-site backups |
| **Image** | A template for creating containers. Like a blueprint for a house. |
| **OAuth** | A secure way to grant applications access to your accounts without sharing your password |
| **pg_dump** | A PostgreSQL command that exports database contents to a file |
| **pg_restore** | A PostgreSQL command that imports database contents from a file |
| **PostgreSQL** | The database software we use to store data. Also called "Postgres". |
| **PowerShell** | Windows' command-line program where you type commands |
| **rclone** | A command-line program for syncing files with cloud storage (like Google Drive) |
| **Repository (Repo)** | A folder containing code and its history, stored on GitHub |
| **RTO** | Recovery Time Objective - how long it should take to restore service after a failure |
| **RPO** | Recovery Point Objective - how much data you might lose (time since last backup) |
| **Shared Drive** | A Google Drive folder that can be shared with multiple people |
| **System Tray** | The area in the bottom-right corner of Windows, near the clock |
| **Terminal** | Another name for PowerShell or command prompt |
| **Volume** | Storage space used by Docker containers to keep data even when containers restart |
