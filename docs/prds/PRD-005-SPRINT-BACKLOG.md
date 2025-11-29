# PRD-005 Sprint Backlog: Infrastructure Operations

## Overview

| Field | Value |
|-------|-------|
| **PRD** | PRD-005 |
| **Total Story Points** | 34 |
| **Estimated Duration** | 2 sprints (2 weeks) |
| **Dependencies** | SMTP credentials, rclone setup |

---

## Sprint 1: Monitoring & Auto-Start (Week 1)

### Epic 1: Health Monitoring (13 points)

| ID | Task | Points | Priority | Dependencies |
|----|------|--------|----------|--------------|
| MON-1.1 | Create `scripts/health-check.ps1` base structure | 2 | P0 | None |
| MON-1.2 | Implement Docker Desktop check | 1 | P0 | MON-1.1 |
| MON-1.3 | Implement container running check | 1 | P0 | MON-1.1 |
| MON-1.4 | Implement container health check (pg_isready) | 1 | P0 | MON-1.1 |
| MON-1.5 | Implement database connection test (SELECT 1) | 2 | P0 | MON-1.1 |
| MON-1.6 | Implement logging to `logs/health-check.log` | 1 | P1 | MON-1.1 |
| MON-1.7 | Create `config/monitoring.env.example` | 1 | P0 | None |
| MON-1.8 | Implement email notification function | 3 | P0 | MON-1.7 |
| MON-1.9 | Add rate limiting for alerts (15 min) | 1 | P0 | MON-1.8 |
| MON-1.10 | Create Task Scheduler XML export script | 1 | P1 | MON-1.1 |

**Deliverables:**
- `scripts/health-check.ps1` - Complete health monitoring script
- `config/monitoring.env.example` - Template for email configuration
- `scripts/install-health-check-task.ps1` - Task scheduler setup

---

### Epic 2: Auto-Start & Verification (5 points)

| ID | Task | Points | Priority | Dependencies |
|----|------|--------|----------|--------------|
| AUTO-2.1 | Refactor `scripts/startup.ps1` → `scripts/verify-startup.ps1` | 2 | P0 | None |
| AUTO-2.2 | Add email notification on startup failure | 1 | P0 | MON-1.8 |
| AUTO-2.3 | Add startup logging to `logs/startup.log` | 1 | P1 | AUTO-2.1 |
| AUTO-2.4 | Create Task Scheduler task for startup verification | 1 | P0 | AUTO-2.1 |

**Deliverables:**
- `scripts/verify-startup.ps1` - Startup verification with alerting
- `scripts/install-startup-task.ps1` - Task scheduler setup

---

## Sprint 2: Backup & Restore (Week 2)

### Epic 3: Backup System (13 points)

| ID | Task | Points | Priority | Dependencies |
|----|------|--------|----------|--------------|
| BAK-3.1 | Create `scripts/backup.ps1` base structure | 2 | P0 | None |
| BAK-3.2 | Implement daily backup (pg_dump + gzip) | 2 | P0 | BAK-3.1 |
| BAK-3.3 | Implement local backup retention (7 days) | 1 | P0 | BAK-3.2 |
| BAK-3.4 | Implement backup verification (test restore) | 2 | P0 | BAK-3.2 |
| BAK-3.5 | Add backup logging to `logs/backup.log` | 1 | P0 | BAK-3.1 |
| BAK-3.6 | Implement rclone Google Drive upload | 3 | P0 | BAK-3.2 |
| BAK-3.7 | Implement remote backup retention (4 weeks) | 1 | P0 | BAK-3.6 |
| BAK-3.8 | Add email notification on backup failure | 1 | P0 | MON-1.8 |
| BAK-3.9 | Create Task Scheduler tasks (daily/weekly) | 1 | P1 | BAK-3.1 |

**Deliverables:**
- `scripts/backup.ps1` - Complete backup script with local and remote support
- `scripts/install-backup-tasks.ps1` - Task scheduler setup
- `config/rclone.conf.example` - rclone configuration template

---

### Epic 4: Restore & DR Testing (3 points)

| ID | Task | Points | Priority | Dependencies |
|----|------|--------|----------|--------------|
| DR-4.1 | Create `scripts/restore.ps1` | 2 | P0 | None |
| DR-4.2 | Update DR-RUNBOOK.md with script references | 1 | P0 | DR-4.1 |

**Deliverables:**
- `scripts/restore.ps1` - Database restore script
- Updated `docs/DR-RUNBOOK.md`

---

## File Structure After Implementation

```
ra-infrastructure/
├── scripts/
│   ├── health-check.ps1          # NEW - Health monitoring
│   ├── verify-startup.ps1        # RENAME from startup.ps1
│   ├── backup.ps1                # NEW - Backup script
│   ├── restore.ps1               # NEW - Restore script
│   ├── install-health-check-task.ps1  # NEW - Task installer
│   ├── install-startup-task.ps1       # NEW - Task installer
│   └── install-backup-tasks.ps1       # NEW - Task installer
├── config/
│   ├── monitoring.env.example    # NEW - Email config template
│   └── rclone.conf.example       # NEW - rclone config template
├── logs/                         # NEW directory (gitignored)
│   ├── health-check.log
│   ├── startup.log
│   └── backup.log
└── docs/
    └── prds/
        └── PRD-005-SPRINT-BACKLOG.md  # This file
```

---

## Definition of Done

Each task is complete when:
- [ ] Code is written and tested manually
- [ ] Script runs without errors
- [ ] Logging works correctly
- [ ] Error handling covers edge cases
- [ ] Documentation updated if needed

---

## Prerequisites Before Starting

1. **SMTP Credentials**: Gmail app password for sending alerts
2. **rclone Installation**: `winget install rclone`
3. **rclone Configuration**: Run `rclone config` to set up Google Drive
4. **Local Backup Directory**: Create `D:\Backups\ra-infrastructure\`

---

## Testing Checklist

### Sprint 1 Testing
- [ ] Health check detects Docker not running
- [ ] Health check detects container stopped
- [ ] Health check detects unhealthy database
- [ ] Email sent on failure
- [ ] Email rate limiting works (max 1 per 15 min)
- [ ] Startup verification works after reboot
- [ ] Logs written correctly

### Sprint 2 Testing
- [ ] Daily backup creates valid dump file
- [ ] Backup file is compressed
- [ ] Old backups cleaned up (7+ days)
- [ ] Weekly backup uploads to Google Drive
- [ ] Remote old backups cleaned up (4+ weeks)
- [ ] Restore script recovers database
- [ ] Email sent on backup failure

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Gmail blocks SMTP | No alerts | Use app password, not regular password |
| rclone OAuth expires | Weekly backup fails | Document re-auth procedure |
| Backup directory full | Backup fails | Monitor disk space in health check |
| Task Scheduler disabled | No monitoring | Document manual verification steps |
