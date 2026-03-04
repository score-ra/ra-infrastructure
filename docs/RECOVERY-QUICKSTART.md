# Recovery Quick Reference

**One-page guide for common recovery scenarios on Raptor**

---

## Quick Health Check (Start Here!)

```powershell
cd C:\Users\symph\workspace\personal\software\ra-infrastructure
inv system selfcheck
```

This checks **everything**: Docker, databases, external endpoints, and more.

---

## What's Wrong? → What To Do

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| `inv system selfcheck` fails | Multiple issues | Check specific failures in output |
| `inv db health` shows error | Container stopped | `docker compose restart ra_postgres` |
| Docker whale icon missing | Docker not running | Start Docker Desktop from Start Menu |
| External sites down (*.selfwize.com) | Cloudflare tunnel issue | `Get-Service cloudflared` then restart |
| Snipe-IT restart loop | Missing APP_KEY | Check `../snipeit-asset-management/.env` |
| Docker pull fails | Credential helper issue | See QUICKSTART.md troubleshooting |
| Computer is new/rebuilt | Starting fresh | Follow QUICKSTART.md |

---

## Most Common Commands

### Check Status
```powershell
cd C:\Users\symph\workspace\personal\software\ra-infrastructure

# Comprehensive check
inv system selfcheck

# Docker containers
docker compose ps

# Database
inv db health
inv db stats

# Cloudflare tunnel
Get-Service cloudflared

# Scheduled tasks
Get-ScheduledTask -TaskName 'ra-infrastructure-*'
```

### Restart Services
```powershell
# Single container
docker compose restart ra_postgres

# All containers
docker compose restart

# Cloudflare tunnel
Stop-Process -Name "cloudflared" -Force; Start-Sleep 5; Start-Service cloudflared
```

### Restore from Backup
```powershell
.\scripts\restore.ps1 -BackupFile "C:\ra-infrastructure-local-backup\inventory\inventory_YYYY-MM-DD.dump.gz"
```

### Create Manual Backup
```powershell
.\scripts\backup.ps1 -Type daily -Verify
```

---

## Backup Locations

### PostgreSQL (Inventory)
| Location | What's There |
|----------|--------------|
| `C:\ra-infrastructure-local-backup\inventory\` | Daily backups |

### MySQL (Snipe-IT)
| Location | What's There |
|----------|--------------|
| `C:\ra-infrastructure-local-backup\mysql\` | Daily backups |

### Fasten Health
| Location | What's There |
|----------|--------------|
| `C:\ra-infrastructure-local-backup\fasten\` | Daily backups |

---

## Full Documentation

| Document | Purpose |
|----------|---------|
| [QUICKSTART.md](QUICKSTART.md) | Full setup guide for Raptor |
| [SELF-CHECK.md](SELF-CHECK.md) | Comprehensive health check guide |
| [DR-RUNBOOK.md](DR-RUNBOOK.md) | Detailed disaster recovery procedures |
| [ports-in-use.md](ports-in-use.md) | Port assignments |
| [guides/database-monitoring.md](guides/database-monitoring.md) | Database-specific monitoring |
