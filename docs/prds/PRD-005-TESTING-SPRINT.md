# PRD-005 Testing Sprint

## Overview

This document provides a structured testing sprint for human and Claude Code to validate all PRD-005 Infrastructure Operations features.

| Field | Value |
|-------|-------|
| **PRD** | PRD-005 |
| **Sprint Type** | Testing & Validation |
| **Estimated Duration** | 2-3 hours |
| **Prerequisites** | All scripts created, SMTP configured |

---

## Test Results Summary

| Test | Status | Date | Notes |
|------|--------|------|-------|
| Health Check - All Pass | PASS | 2025-11-27 | All 4 checks pass |
| Health Check - Failure Detection | PASS | 2025-11-27 | Correctly detects stopped container |
| Email Alert - SMTP Connection | PARTIAL | 2025-11-27 | Logic works, needs Gmail app password verification |
| Daily Backup | PASS | 2025-11-27 | Created 15KB compressed dump |
| Restore from Backup | PASS | 2025-11-27 | Restored with verification |
| Weekly Backup (Google Drive) | NOT TESTED | - | Requires rclone setup |
| Task Scheduler Installation | NOT TESTED | - | Requires admin privileges |
| DR Test | NOT TESTED | - | See DR Testing section |

---

## Sprint 1: Automated Tests (Claude Code)

These tests can be run by Claude Code without human intervention.

### Test 1.1: Health Check - Normal Operation
```powershell
# Run health check with all services running
.\scripts\health-check.ps1 -SkipEmail
```
**Expected:** All 4 checks pass (Docker, container running, container healthy, DB connection)

**Result:** ✅ PASS

### Test 1.2: Health Check - Failure Detection
```powershell
# Stop database container
docker stop inventory-db

# Run health check
.\scripts\health-check.ps1 -SkipEmail

# Restart container
docker start inventory-db
```
**Expected:** Detects container not running, exits with code 1

**Result:** ✅ PASS

### Test 1.3: Daily Backup
```powershell
# Ensure backup directory exists
New-Item -ItemType Directory -Path "D:\Backups\ra-infrastructure\daily" -Force

# Run daily backup
.\scripts\backup.ps1 -Type daily
```
**Expected:** Creates compressed dump file in `D:\Backups\ra-infrastructure\daily\`

**Result:** ✅ PASS - Created `inventory_2025-11-27.dump.gz` (15KB)

### Test 1.4: Backup with Verification
```powershell
.\scripts\backup.ps1 -Type daily -Verify
```
**Expected:** Creates backup and verifies by restoring to temp database

**Result:** ⏳ NOT TESTED

### Test 1.5: Restore from Backup
```powershell
# Restore from latest backup
.\scripts\restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\daily\inventory_2025-11-27.dump.gz" -Force
```
**Expected:**
- Creates safety backup in `logs/safety-backups/`
- Restores database
- Verifies record counts

**Result:** ✅ PASS - Restored with verification (1 org, 1 site, 14 zones, 3 devices, 5 networks)

---

## Sprint 2: Human-Assisted Tests

These tests require human interaction or verification.

### Test 2.1: Email Alert Verification
**Requires:** Valid Gmail App Password

**Steps:**
1. Verify Gmail App Password is correct in `config/monitoring.env`
   - Go to: https://myaccount.google.com/apppasswords
   - Create new app password for "ra-infrastructure"
   - Update `SMTP_PASSWORD` in `config/monitoring.env`

2. Stop database container:
   ```powershell
   docker stop inventory-db
   ```

3. Run health check (email should be sent):
   ```powershell
   .\scripts\health-check.ps1
   ```

4. Check email inbox for alert

5. Restart container:
   ```powershell
   docker start inventory-db
   ```

6. Run health check again (recovery email should be sent)

**Expected:** Receive failure alert email, then recovery email

**Status:** ⏳ NEEDS HUMAN - App password may need regeneration

---

### Test 2.2: Weekly Backup (Google Drive)
**Requires:** rclone configured with Google Drive

**Steps:**
1. Install rclone:
   ```powershell
   winget install rclone
   ```

2. Configure rclone:
   ```powershell
   rclone config
   # Follow prompts for Google Drive shared drive
   # Remote name: gdrive
   ```

3. Test rclone connection:
   ```powershell
   rclone ls gdrive:ra-infrastructure-backup/
   ```

4. Run weekly backup:
   ```powershell
   .\scripts\backup.ps1 -Type weekly
   ```

5. Verify file uploaded to Google Drive

**Expected:** Backup uploaded to `ra-all-purpose-backup/ra-infrastructure-backup/`

**Status:** ⏳ NEEDS HUMAN - rclone setup required

---

### Test 2.3: Task Scheduler Installation
**Requires:** Administrator privileges

**Steps:**
1. Open PowerShell as Administrator

2. Install health check task:
   ```powershell
   .\scripts\install-health-check-task.ps1
   ```

3. Verify task created:
   ```powershell
   Get-ScheduledTask -TaskName "ra-infrastructure-*"
   ```

4. Install backup tasks:
   ```powershell
   .\scripts\install-backup-tasks.ps1
   ```

5. Verify tasks:
   - Check Task Scheduler GUI
   - Verify triggers (health: every 5 min, daily backup: 2 AM, weekly: Sunday 3 AM)

**Expected:** All 3 tasks registered and visible in Task Scheduler

**Status:** ⏳ NEEDS HUMAN - Requires admin privileges

---

### Test 2.4: Startup Task Verification
**Requires:** System reboot

**Steps:**
1. Install startup task (as admin):
   ```powershell
   .\scripts\install-startup-task.ps1
   ```

2. Reboot the computer

3. After login, wait 2+ minutes

4. Check startup log:
   ```powershell
   Get-Content .\logs\startup.log -Tail 20
   ```

**Expected:** Startup verification runs automatically after login

**Status:** ⏳ NEEDS HUMAN - Requires reboot

---

## Sprint 3: Disaster Recovery Test

### Test 3.1: Full DR Test (Tier 3)

**IMPORTANT:** This test will temporarily delete data. Ensure backups exist.

**Steps:**
1. Create fresh backup:
   ```powershell
   .\scripts\backup.ps1 -Type daily -Verify
   ```

2. Record current stats:
   ```powershell
   inv db stats
   ```

3. Stop all services:
   ```powershell
   cd docker
   docker-compose down
   ```

4. Remove database volume (SIMULATES DATA LOSS):
   ```powershell
   docker volume rm inventory_postgres_data
   ```

5. Start fresh database:
   ```powershell
   docker-compose up -d postgres
   # Wait for healthy
   docker-compose ps
   ```

6. Restore from backup:
   ```powershell
   cd ..
   .\scripts\restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\daily\inventory_2025-11-27.dump.gz" -Force -SkipSafetyBackup
   ```

7. Verify restoration:
   ```powershell
   inv db stats
   inv org list
   ```

8. Start all services:
   ```powershell
   cd docker
   docker-compose up -d
   ```

**Expected:** Full recovery within 30 minutes, data matches pre-test stats

**Status:** ⏳ NEEDS HUMAN - Destructive test

---

## Test Checklist Summary

### For Claude Code (Automated):
- [x] Health check - normal operation
- [x] Health check - failure detection
- [x] Daily backup creation
- [ ] Backup with verification flag
- [x] Restore from backup

### For Human:
- [ ] Email alert delivery (needs app password verification)
- [ ] Weekly backup to Google Drive (needs rclone setup)
- [ ] Task Scheduler installation (needs admin)
- [ ] Startup task after reboot (needs reboot)
- [ ] Full DR test (destructive, needs backup first)

---

## Known Issues

1. **Gmail SMTP Authentication**: The error "5.7.0 Authentication Required" indicates the app password may need to be regenerated in Google Account settings.

2. **rclone Setup**: Weekly backup requires manual rclone configuration with Google Drive OAuth.

---

## Quick Commands Reference

```powershell
# Health check
.\scripts\health-check.ps1

# Backup
.\scripts\backup.ps1 -Type daily
.\scripts\backup.ps1 -Type weekly

# Restore
.\scripts\restore.ps1 -BackupFile "path\to\backup.dump.gz" -Force

# View logs
Get-Content .\logs\health-check.log -Tail 20
Get-Content .\logs\backup.log -Tail 20
Get-Content .\logs\startup.log -Tail 20

# Check tasks
Get-ScheduledTask -TaskName "ra-infrastructure-*"
```
