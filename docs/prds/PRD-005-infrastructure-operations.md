# PRD-005: Infrastructure Operations

## Overview

| Field | Value |
|-------|-------|
| **PRD Number** | PRD-005 |
| **Title** | Infrastructure Operations - Monitoring, Auto-Start, Backup & DR |
| **Status** | Implemented |
| **Created** | 2025-11-27 |
| **Implemented** | 2025-12-02 |
| **Author** | Infrastructure Team |

## Problem Statement

The ra-infrastructure database serves as the central data store for multiple repositories. Currently, there is no:
- Automated health monitoring with alerting
- Auto-recovery after system reboots
- Backup strategy for data protection
- Documented disaster recovery procedures

This creates risk of undetected downtime and potential data loss.

## Goals

1. **Monitoring**: Detect service failures within 5 minutes and notify via email
2. **Auto-Start**: Ensure services start automatically after PC reboot
3. **Backup**: Protect data with daily local and weekly remote backups
4. **Disaster Recovery**: Enable full recovery within 1 hour with documented procedures

## Non-Goals

- Real-time monitoring dashboards (future enhancement)
- Multi-region backup replication
- Automated failover to standby database
- Monitoring of external dependent services

---

## 1. MVP Monitoring

### 1.1 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| MON-01 | Check if Docker Desktop is running | P0 |
| MON-02 | Check if `inventory-db` container is running | P0 |
| MON-03 | Check if `inventory-db` container is healthy (pg_isready) | P0 |
| MON-04 | Check if database accepts connections (SELECT 1) | P0 |
| MON-05 | Check if `inventory-pgadmin` container is running | P1 |
| MON-06 | Send email notification on any failure | P0 |
| MON-07 | Run health checks every 5 minutes | P0 |
| MON-08 | Log all check results to file | P1 |

### 1.2 Health Check Script

**Location:** `scripts/health-check.ps1`

**Checks to perform:**
1. Docker Desktop process running
2. Container `inventory-db` state = running
3. Container `inventory-db` health = healthy
4. Database connection test: `psql -c "SELECT 1"`
5. Container `inventory-pgadmin` state = running (optional)

**Output:**
- Exit code 0: All checks passed
- Exit code 1: One or more checks failed
- Log entry written to `logs/health-check.log`

### 1.3 Email Notification

**Configuration:**
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<your-email>@gmail.com
SMTP_PASSWORD=<app-password>
ALERT_EMAIL=<recipient>@example.com
```

**Email Content:**
- Subject: `[ALERT] ra-infrastructure - Service Down`
- Body: Which check failed, timestamp, suggested action

**Notification Rules:**
- Send on first failure detection
- Send recovery notification when service returns
- Rate limit: Max 1 email per 15 minutes per failure type

### 1.4 Scheduling

**Windows Task Scheduler:**
- Task Name: `ra-infrastructure-health-check`
- Trigger: Every 5 minutes
- Action: Run `scripts/health-check.ps1`
- Run whether user is logged on or not

---

## 2. Auto-Start After Reboot

### 2.1 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| AUTO-01 | Docker Desktop starts on Windows login | P0 |
| AUTO-02 | Containers start when Docker is ready | P0 |
| AUTO-03 | Verify services are healthy after startup | P0 |
| AUTO-04 | Log startup events | P1 |

### 2.2 Recommended Approach

**Option A: Docker Desktop Auto-Start (Recommended)**

Docker Compose already has `restart: unless-stopped` policy. The only requirement is ensuring Docker Desktop starts on boot.

**Steps:**
1. Enable Docker Desktop auto-start:
   - Docker Desktop → Settings → General → "Start Docker Desktop when you sign in" ✓

2. Containers will auto-start because of `restart: unless-stopped` policy in docker-compose.yml

**Option B: Windows Task Scheduler (Alternative)**

Use if Docker Desktop auto-start is unreliable:
- Task Name: `ra-infrastructure-startup`
- Trigger: At system startup (with 2-minute delay)
- Action: Start Docker Desktop, then `docker-compose up -d`

### 2.3 Startup Verification Script

**Location:** `scripts/verify-startup.ps1`

**Purpose:** Run after reboot to verify all services started correctly

**Actions:**
1. Wait for Docker to be ready (max 5 minutes)
2. Check container states
3. Run health checks
4. Send notification if startup failed
5. Log results

---

## 3. MVP Backup Strategy

### 3.1 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| BAK-01 | Daily backup to local drive | P0 |
| BAK-02 | Weekly backup to Google Drive | P0 |
| BAK-03 | Retain 30 daily local backups (~1 month) | P0 |
| BAK-04 | Retain 26 weekly remote backups (~6 months) | P0 |
| BAK-05 | Backup includes full database dump | P0 |
| BAK-06 | Backup includes Docker volume data | P1 |
| BAK-07 | Verify backup integrity after creation | P0 |
| BAK-08 | Log all backup operations | P0 |
| BAK-09 | Alert on backup failure | P0 |

### 3.2 Backup Locations

**Local Backup:**
```
D:\Backups\ra-infrastructure\
├── daily\
│   ├── inventory_2025-12-10.dump.gz
│   ├── inventory_2025-12-09.dump.gz
│   └── ... (30 days retained)
└── logs\
    └── backup.log
```

**Remote Backup (Google Drive):**
```
Shared Drive: ra-infrastructure-backup
    ├── inventory_2025-12-07_weekly.dump.gz
    └── ... (26 weeks / ~6 months retained)
```

### 3.3 Backup Script

**Location:** `scripts/backup.ps1`

**Parameters:**
- `-Type daily|weekly` - Backup type
- `-Verify` - Run integrity check after backup

**Daily Backup Process:**
1. Create dump inside container: `pg_dump -Fc -f /tmp/backup.dump`
2. Compress inside container: `gzip`
3. Copy to host: `D:\Backups\ra-infrastructure\daily\`
4. Verify: Copy to container, decompress, restore to temp database, query
5. Clean up backups older than 30 days
6. Log results

**Weekly Backup Process:**
1. Run daily backup first
2. Upload to Google Drive via rclone
3. Verify upload completed
4. Clean up remote backups older than 26 weeks
5. Log results

**Note:** All backup operations are performed inside the container to avoid PowerShell binary data handling issues that can corrupt dump files.

### 3.4 Google Drive Integration

**Recommended Tool:** rclone

**Why rclone over service account:**
- No GCP project setup required
- Works with personal Google accounts
- Simple OAuth browser-based setup
- Well-documented and maintained

**Setup Steps:**
1. Install rclone: `winget install rclone`
2. Configure: `rclone config`
   - Choose "Google Drive"
   - Complete OAuth in browser
   - Name remote: `gdrive`
3. Test: `rclone ls gdrive:Backups/`

**Configuration file:** `config/rclone.conf` (gitignored)

### 3.5 Backup Schedule

| Type | Frequency | Time | Retention |
|------|-----------|------|-----------|
| Daily | Every day | 2:00 AM | 30 days |
| Weekly | Every Sunday | 3:00 AM | 26 weeks (~6 months) |

**Windows Task Scheduler Tasks:**
- `ra-infrastructure-backup-daily`: Runs daily at 2:00 AM
- `ra-infrastructure-backup-weekly`: Runs Sundays at 3:00 AM

---

## 4. Disaster Recovery

### 4.1 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| DR-01 | Document full recovery procedure | P0 |
| DR-02 | Recovery Time Objective (RTO): 1 hour | P0 |
| DR-03 | Recovery Point Objective (RPO): 24 hours | P0 |
| DR-04 | Manual runbook for DR testing | P0 |
| DR-05 | Test procedure quarterly | P1 |

### 4.2 Failure Scenarios

| Scenario | Impact | Recovery Method |
|----------|--------|-----------------|
| Container crash | Service down | Restart container |
| Docker crash | All services down | Restart Docker Desktop |
| Database corruption | Data integrity | Restore from backup |
| Volume loss | All data lost | Restore from backup |
| Disk failure | All data lost | Restore from backup + reinstall |
| PC failure | Everything lost | New machine setup + restore |

### 4.3 Recovery Procedures

**Tier 1: Service Restart (< 5 minutes)**
```powershell
cd docker
docker-compose restart
inv db stats
```

**Tier 2: Container Rebuild (< 15 minutes)**
```powershell
cd docker
docker-compose down
docker-compose up -d
inv db stats
```

**Tier 3: Database Restore (< 30 minutes)**
```powershell
# Stop services
docker-compose down

# Remove corrupted volume
docker volume rm inventory_postgres_data

# Start fresh container
docker-compose up -d postgres

# Restore from backup
scripts/restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\daily\latest.sql.gz"

# Verify
inv db stats
```

**Tier 4: Full Recovery (< 1 hour)**
See separate DR Runbook document.

### 4.4 DR Testing

**Quarterly Test Procedure:**
1. Create fresh backup
2. Simulate failure (remove volume)
3. Execute Tier 3 recovery
4. Verify data integrity
5. Document results and issues

---

## 5. Implementation Plan

### Phase 1: Monitoring (Week 1)
- [ ] Create `scripts/health-check.ps1`
- [ ] Configure email notifications
- [ ] Set up Windows Task Scheduler
- [ ] Test alerting end-to-end

### Phase 2: Auto-Start (Week 1)
- [ ] Configure Docker Desktop auto-start
- [ ] Create `scripts/verify-startup.ps1`
- [ ] Test reboot recovery
- [ ] Document procedure

### Phase 3: Backup (Week 2)
- [ ] Create backup directory structure
- [ ] Create `scripts/backup.ps1`
- [ ] Install and configure rclone
- [ ] Set up scheduled tasks
- [ ] Test backup and restore

### Phase 4: DR (Week 2)
- [ ] Create DR runbook document
- [ ] Create `scripts/restore.ps1`
- [ ] Perform initial DR test
- [ ] Document lessons learned

---

## 6. File Structure

After implementation:

```
ra-infrastructure/
├── scripts/
│   ├── health-check.ps1      # Health monitoring script
│   ├── verify-startup.ps1    # Startup verification
│   ├── backup.ps1            # Backup script
│   └── restore.ps1           # Restore script
├── config/
│   ├── monitoring.env        # Email/SMTP config (gitignored)
│   └── rclone.conf           # rclone config (gitignored)
├── logs/                     # Log directory (gitignored)
│   ├── health-check.log
│   └── backup.log
└── docs/
    ├── DOCKER.md             # Docker documentation
    ├── DR-RUNBOOK.md         # Disaster recovery procedures
    └── prds/
        └── PRD-005-infrastructure-operations.md
```

---

## 7. Success Metrics

| Metric | Target |
|--------|--------|
| Service uptime | 99.5% (excluding planned maintenance) |
| Alert delivery time | < 10 minutes from failure |
| Backup success rate | 100% |
| Recovery time (tested) | < 1 hour |
| DR tests completed | Quarterly |

---

## 8. Open Questions

1. ~~Notification method~~ → Email
2. ~~Google Drive auth method~~ → rclone with OAuth
3. ~~Local backup location~~ → `D:\Backups\ra-infrastructure\`
4. ~~Google Drive folder path~~ → Shared Drive `ra-all-purpose-backup` / `ra-infrastructure-backup/`
5. SMTP credentials → To be configured during implementation

---

## Appendix A: Configuration Templates

### monitoring.env
```ini
# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
ALERT_EMAIL=recipient@example.com

# Alert Settings
ALERT_RATE_LIMIT_MINUTES=15
```

### Scheduled Task XML (health-check)
```xml
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4">
  <Triggers>
    <TimeTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
      </Repetition>
      <StartBoundary>2025-01-01T00:00:00</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -File "C:\path\to\scripts\health-check.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
```

---

## Appendix B: Backup and DR Best Practices

*Requirements summary for ra-infrastructure personal organization*

### Core Principles

1. **Data must survive any single point of failure**
   - Local disk failure should not cause data loss
   - Remote backup ensures geographic redundancy

2. **Recovery must be achievable by a novice user**
   - Documentation assumes no prior technical knowledge
   - Step-by-step instructions with expected outputs
   - Troubleshooting guidance for common errors

3. **Automation over manual processes**
   - Scheduled backups run without human intervention
   - Health monitoring detects failures automatically
   - Email alerts notify on problems

### Backup Strategy

| Requirement | Implementation |
|-------------|----------------|
| **Daily local backups** | Compressed database dumps stored on local drive |
| **Weekly remote backups** | Upload to Google Drive Shared Drive |
| **30-day local retention** | Automatic cleanup of old daily backups (~1 month) |
| **26-week remote retention** | Automatic cleanup of old weekly backups (6 months) |
| **Backup verification** | Integrity check after each backup |
| **Failure alerting** | Email notification on backup failure |

### Disaster Recovery Requirements

| Metric | Target |
|--------|--------|
| **Recovery Time Objective (RTO)** | 1 hour maximum |
| **Recovery Point Objective (RPO)** | 24 hours (last daily backup) |
| **DR Testing Frequency** | Quarterly |

### Recovery Scenarios Covered

| Scenario | Recovery Method | Target Time |
|----------|-----------------|-------------|
| Container stopped | Restart container | 2 minutes |
| Docker crashed | Restart Docker Desktop | 5 minutes |
| Database corrupted | Restore from backup | 30 minutes |
| Volume deleted | Restore from backup | 30 minutes |
| Disk failure | Full recovery from remote backup | 1 hour |
| PC failure | New machine setup + restore | 1 hour |

### Documentation Requirements

| Requirement | Purpose |
|-------------|---------|
| **Novice-friendly language** | User may not know technical terms |
| **Download links for all tools** | User shouldn't have to search |
| **Expected output after commands** | User knows if step succeeded |
| **Troubleshooting section** | User can self-resolve common issues |
| **Glossary of terms** | User can look up unfamiliar concepts |
| **Manual + automated options** | Flexibility for different situations |

### Infrastructure Components

| Component | Purpose | Storage Location |
|-----------|---------|------------------|
| Database dumps | Primary data backup | `D:\Backups\ra-infrastructure\daily\` |
| Remote backups | Geographic redundancy | Google Drive: `ra-infrastructure-backup` |
| Backup scripts | Automation | `scripts/backup.ps1`, `restore.ps1` |
| Health monitoring | Failure detection | `scripts/health-check.ps1` |
| DR Runbook | Recovery procedures | `docs/DR-RUNBOOK.md` |
| Task Scheduler | Automated execution | Windows Task Scheduler |

### What Gets Backed Up

| Data | Included | Method |
|------|----------|--------|
| PostgreSQL database | Yes | `pg_dump` to compressed file |
| Database schema | Yes | Included in pg_dump |
| Docker container config | Yes | In Git repository |
| Application code | Yes | In Git repository |
| Docker images | No | Re-downloaded from Docker Hub |
| pgAdmin settings | No | Reconfigurable, not critical |
