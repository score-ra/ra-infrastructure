# Disaster Recovery Runbook

## Overview

| Field | Value |
|-------|-------|
| **Recovery Time Objective (RTO)** | 1 hour |
| **Recovery Point Objective (RPO)** | 24 hours (last daily backup) |
| **Last DR Test** | Not yet performed |
| **Next Scheduled Test** | TBD |

## Quick Reference

| Scenario | Recovery Time | Procedure |
|----------|---------------|-----------|
| Container stopped | 2 minutes | [Tier 1](#tier-1-service-restart) |
| Docker crashed | 5 minutes | [Tier 2](#tier-2-docker-restart) |
| Database corrupted | 30 minutes | [Tier 3](#tier-3-database-restore) |
| Volume deleted | 30 minutes | [Tier 3](#tier-3-database-restore) |
| Disk failure | 1 hour | [Tier 4](#tier-4-full-recovery) |
| PC failure | 1 hour+ | [Tier 4](#tier-4-full-recovery) |

---

## Pre-Recovery Checklist

Before starting any recovery:

- [ ] Identify the failure type
- [ ] Check backup availability: `dir D:\Backups\ra-infrastructure\daily\`
- [ ] Note the timestamp of last known good state
- [ ] Notify dependent teams/services if applicable

---

## Tier 1: Service Restart

**When to use:** Container stopped but Docker is running

**Time estimate:** 2 minutes

### Steps

1. **Check container status**
   ```powershell
   cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
   docker-compose ps
   ```

2. **Restart the stopped container**
   ```powershell
   docker-compose restart postgres
   # Or restart all
   docker-compose restart
   ```

3. **Verify health**
   ```powershell
   # Wait for healthy status
   docker-compose ps

   # Test database connection
   inv db stats
   ```

4. **Check logs if issues persist**
   ```powershell
   docker-compose logs --tail=50 postgres
   ```

### Success Criteria
- [ ] Container status: `running (healthy)`
- [ ] `inv db stats` returns data counts

---

## Tier 2: Docker Restart

**When to use:** Docker Desktop crashed or unresponsive

**Time estimate:** 5 minutes

### Steps

1. **Check Docker Desktop status**
   ```powershell
   # Check if Docker process is running
   Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
   ```

2. **Restart Docker Desktop**
   - Option A: Right-click Docker icon in system tray → Restart
   - Option B:
     ```powershell
     Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
     Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
     ```

3. **Wait for Docker to be ready** (1-2 minutes)
   ```powershell
   # Wait until Docker responds
   while (-not (docker info 2>$null)) { Start-Sleep 5; Write-Host "Waiting..." }
   Write-Host "Docker is ready"
   ```

4. **Verify containers started**
   ```powershell
   cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
   docker-compose ps
   ```

5. **If containers didn't auto-start**
   ```powershell
   docker-compose up -d
   ```

6. **Verify database health**
   ```powershell
   inv db stats
   ```

### Success Criteria
- [ ] Docker Desktop running
- [ ] Both containers: `running (healthy)`
- [ ] `inv db stats` returns data counts

---

## Tier 3: Database Restore

**When to use:** Database corruption, accidental data deletion, or volume loss

**Time estimate:** 30 minutes

### Prerequisites
- Backup file available in `D:\Backups\ra-infrastructure\daily\`
- Docker Desktop running

### Steps

1. **Stop all services**
   ```powershell
   cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
   docker-compose down
   ```

2. **Remove corrupted volume** (if applicable)
   ```powershell
   docker volume rm inventory_postgres_data
   ```

3. **Start fresh PostgreSQL container**
   ```powershell
   docker-compose up -d postgres

   # Wait for healthy status
   docker-compose ps
   ```

4. **Identify backup to restore**
   ```powershell
   # List available backups
   dir D:\Backups\ra-infrastructure\daily\ | Sort-Object LastWriteTime -Descending

   # Select the most recent (or specific date)
   $BACKUP_FILE = "D:\Backups\ra-infrastructure\daily\ra_inventory_2025-11-27.sql.gz"
   ```

5. **Restore the backup**
   ```powershell
   # Decompress backup
   gzip -dk $BACKUP_FILE

   # Get SQL file path
   $SQL_FILE = $BACKUP_FILE -replace '\.gz$', ''

   # Restore using pg_restore
   docker exec -i inventory-db pg_restore -U inventory -d ra_inventory -c < $SQL_FILE

   # Or if it's a plain SQL dump:
   # docker exec -i inventory-db psql -U inventory -d ra_inventory < $SQL_FILE

   # Clean up decompressed file
   Remove-Item $SQL_FILE
   ```

6. **Alternative: Restore using psql from host**
   ```powershell
   # Decompress
   gzip -dk $BACKUP_FILE
   $SQL_FILE = $BACKUP_FILE -replace '\.gz$', ''

   # Restore (assumes psql is in PATH)
   $env:PGPASSWORD = "inventory_dev_password"
   psql -h localhost -U inventory -d ra_inventory -f $SQL_FILE

   # Clean up
   Remove-Item $SQL_FILE
   ```

7. **Start remaining services**
   ```powershell
   docker-compose up -d
   ```

8. **Verify restoration**
   ```powershell
   # Check record counts
   inv db stats

   # Verify specific data
   inv org list
   inv device list
   ```

### Success Criteria
- [ ] All containers running and healthy
- [ ] `inv db stats` shows expected record counts
- [ ] Sample queries return expected data
- [ ] Dependent applications can connect

---

## Tier 4: Full Recovery

**When to use:** Disk failure, PC failure, or setting up on new machine

**Time estimate:** 1 hour

### Prerequisites
- Access to remote backup (Google Drive)
- Docker Desktop installed
- Git installed
- Python 3.11+ installed

### Steps

1. **Install Docker Desktop** (if not installed)
   - Download from https://www.docker.com/products/docker-desktop
   - Install and restart PC if required
   - Start Docker Desktop

2. **Clone repository**
   ```powershell
   cd c:\Users\ranand\workspace\personal\software
   git clone https://github.com/score-ra/ra-infrastructure.git
   cd ra-infrastructure
   ```

3. **Set up environment**
   ```powershell
   # Copy environment file
   cp docker/.env.example docker/.env

   # Edit with your credentials if needed
   notepad docker/.env
   ```

4. **Download backup from Google Drive**
   ```powershell
   # If rclone is configured (Shared Drive: ra-all-purpose-backup)
   rclone copy gdrive:ra-infrastructure-backup/latest_weekly.sql.gz D:\Backups\ra-infrastructure\restore\

   # Or manually download from Google Drive:
   # Shared Drive: ra-all-purpose-backup → ra-infrastructure-backup folder
   ```

5. **Start database container**
   ```powershell
   cd docker
   docker-compose up -d postgres

   # Wait for healthy
   docker-compose ps
   ```

6. **Restore from backup**
   ```powershell
   $BACKUP_FILE = "D:\Backups\ra-infrastructure\restore\latest_weekly.sql.gz"

   # Decompress
   gzip -dk $BACKUP_FILE
   $SQL_FILE = $BACKUP_FILE -replace '\.gz$', ''

   # Restore
   docker exec -i inventory-db pg_restore -U inventory -d ra_inventory -c < $SQL_FILE
   ```

7. **Start all services**
   ```powershell
   docker-compose up -d
   ```

8. **Install CLI**
   ```powershell
   cd ../cli
   pip install -e ".[dev]"
   ```

9. **Verify full recovery**
   ```powershell
   inv db stats
   inv org list
   inv site list
   inv device list
   ```

10. **Reconfigure automation**
    - Set up Windows Task Scheduler tasks for monitoring and backup
    - Configure rclone for Google Drive sync
    - Test health check script

### Success Criteria
- [ ] Repository cloned and configured
- [ ] Docker containers running and healthy
- [ ] Database restored with expected data
- [ ] CLI working (`inv db stats`)
- [ ] Monitoring and backup automation configured

---

## DR Testing Procedure

### Quarterly Test Checklist

Perform this test quarterly to ensure recovery procedures work.

**Preparation:**
- [ ] Create fresh backup before test
- [ ] Document current record counts: `inv db stats`
- [ ] Schedule 1-hour maintenance window

**Test Execution:**

1. **Simulate failure**
   ```powershell
   # Stop services
   cd docker
   docker-compose down

   # Remove database volume (simulates data loss)
   docker volume rm inventory_postgres_data
   ```

2. **Execute Tier 3 recovery**
   - Follow all steps in [Tier 3](#tier-3-database-restore)
   - Time the recovery

3. **Verify recovery**
   ```powershell
   # Compare counts to pre-test values
   inv db stats

   # Test specific queries
   inv org show <known-org-slug>
   inv device show <known-device-slug>
   ```

**Documentation:**
- [ ] Record recovery time: _____ minutes
- [ ] Record any issues encountered
- [ ] Update runbook if procedures changed
- [ ] Schedule next test date

### Test Results Log

| Date | Test Type | Recovery Time | Issues | Tester |
|------|-----------|---------------|--------|--------|
| | | | | |

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
# WARNING: Removes ALL Docker data
docker-compose down -v
docker system prune -a --volumes
```
