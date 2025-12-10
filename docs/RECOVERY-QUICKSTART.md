# Recovery Quick Reference

**One-page guide for common recovery scenarios**

---

## What's Wrong? → What To Do

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| `inv db stats` shows error | Container stopped | `docker-compose restart postgres` |
| Docker whale icon missing | Docker not running | Start Docker Desktop from Start Menu |
| Data is corrupted/deleted | Database issue | Use restore.ps1 (see below) |
| Computer is new/rebuilt | Starting fresh | Follow Tier 4 in DR-RUNBOOK.md |

---

## Most Common Commands

### Check Status
```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
docker-compose ps
inv db stats
```

### Restart Container
```powershell
docker-compose restart postgres
```

### Restore from Backup
```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure
.\scripts\restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\daily\inventory_YYYY-MM-DD.dump.gz"
```

### Create Manual Backup
```powershell
.\scripts\backup.ps1 -Type daily -Verify
```

---

## Backup Locations

| Location | What's There |
|----------|--------------|
| `D:\Backups\ra-infrastructure\daily\` | Last 30 days of backups |
| Google Drive: `ra-infrastructure-backup` | Last 6 months of backups |

**List local backups:**
```powershell
dir D:\Backups\ra-infrastructure\daily\ | Sort-Object LastWriteTime -Descending
```

---

## Emergency Contacts

| Role | Contact |
|------|---------|
| Primary Admin | TBD |
| Backup Admin | TBD |

---

## Full Documentation

For detailed step-by-step instructions, see: [DR-RUNBOOK.md](DR-RUNBOOK.md)
