# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Operations Ready |
| **Last Updated** | 2025-12-20 |
| **Purpose** | Central infrastructure database for other repositories |

## Session Context (2025-12-20)

### Cloudflare Tunnel Setup - COMPLETED (pending reboot verification)

**What was done:**
1. Registered selfwize.com with Cloudflare (nameservers: arushi/thomas)
2. Installed cloudflared via winget
3. Created tunnel `selfwize-dev` (ID: `1f014ff9-68ae-4033-bacf-e058b91d2df4`)
4. Created DNS routes for 4 subdomains
5. Installed Windows service with registry fix
6. Enabled "Always Use HTTPS" in Cloudflare

**Issue encountered:** 524 timeout errors - tunnel shows connected but requests timeout. Reboot recommended.

### After Reboot - Verify These Steps:

```powershell
# 1. Check service is running
Get-Service cloudflared

# 2. Check tunnel has active connections
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info selfwize-dev

# 3. Test site access (should return 502 since no service on port)
curl.exe https://stuff.selfwize.com

# If 502 = SUCCESS (tunnel working, just no backend service)
# If 524 = FAIL (tunnel not connecting)
```

**If still failing after reboot:**
- Check Windows Event Viewer for cloudflared errors
- Try manual run: `& "C:\Program Files (x86)\cloudflared\cloudflared.exe" --config "C:\Program Files (x86)\cloudflared\config.yml" tunnel run`

### Files Modified This Session:
- `docs/guides/CLOUDFLARE-TUNNEL-SETUP.md` - Complete rewrite with new subdomain structure + registry fix
- `config/cloudflare.env` - API credentials and tunnel ID
- `config/cloudflared-config.template.yml` - Updated template
- `scripts/install-cloudflared.ps1` - Full rewrite with service registry fix
- `scripts/setup-cloudflared-service.ps1` - New script for service-only setup

## What This Repository Is

**ra-infrastructure** is a standalone database infrastructure and CLI for managing:
- **Organizations** - Multi-tenant support
- **Sites** - Physical locations
- **Zones** - Logical areas within sites
- **Devices** - All infrastructure devices
- **Networks** - Network configurations and IP allocations

This database is designed to be consumed by **other repositories** for their device/network data needs.

## What's Done

- [x] Database schema (4 migrations)
- [x] Docker infrastructure (PostgreSQL 16 + pgAdmin)
- [x] CLI with Typer (`inv` command)
- [x] Full CRUD for all entities (org, site, zone, device, network)
- [x] Repository pattern for db layer
- [x] Pydantic models for validation
- [x] 79 tests passing
- [x] **Backup & DR infrastructure** (PRD-005)
  - Daily local backups (2:00 AM) with 30-day retention
  - Weekly remote backups (Sunday 3:00 AM) to Google Drive with 6-month retention
  - Health monitoring every 5 minutes with email alerts
  - Disaster recovery runbook with 4-tier procedures
  - Restore script with safety backups
  - Backup verification fixed (2025-12-10) - backups now create valid, restorable dumps
  - **Fasten Health integration** (2025-12-10) - consolidated backup supports `-IncludeFasten` flag
  - **MySQL (home automation)** (2025-12-14) - consolidated backup supports `-IncludeMySQL` flag
  - **Pending**: End-to-end DR test on separate device

## For External Repositories

See **[docs/DATABASE.md](docs/DATABASE.md)** for:
- Connection details
- Schema documentation
- Example queries
- Python connection examples

## Infrastructure Status

| Component | Status |
|-----------|--------|
| PostgreSQL | `localhost:5432` |
| MySQL | `localhost:3306` |
| pgAdmin | `localhost:5050` |
| Database (PostgreSQL) | `inventory` |
| Database (MySQL) | `homeautomation` |
| User (PostgreSQL) | `inventory` |
| User (MySQL) | `homeautomation` |
| Backups | `D:\Backups\ra-infrastructure\daily\` |
| MySQL Backups | `D:\Backups\homeautomation-mysql\daily\` |
| Fasten Backups | `D:\Backups\fasten-health\` |
| Remote Backups | Google Drive: `ra-infrastructure-backup` |

## Quick Commands

```powershell
# Start database
cd docker && docker-compose up -d

# Check status
inv db stats

# Install CLI
cd cli && pip install -e ".[dev]"

# Run tests
cd cli && pytest

# Backup ra-infrastructure only
.\scripts\backup.ps1 -Type daily

# Backup ra-infrastructure + MySQL (home automation)
.\scripts\backup.ps1 -Type daily -IncludeMySQL

# Backup ra-infrastructure + Fasten Health
.\scripts\backup.ps1 -Type daily -IncludeFasten

# Backup everything (ra-infrastructure + MySQL + Fasten)
.\scripts\backup.ps1 -Type daily -IncludeMySQL -IncludeFasten

# Weekly backup with Google Drive upload
.\scripts\backup.ps1 -Type weekly -IncludeMySQL -IncludeFasten
```

## Key Documents

| Document | Purpose |
|----------|---------|
| [docs/DATABASE.md](docs/DATABASE.md) | **External repository integration guide** |
| [docs/DR-RUNBOOK.md](docs/DR-RUNBOOK.md) | **Disaster recovery procedures** |
| [docs/RECOVERY-QUICKSTART.md](docs/RECOVERY-QUICKSTART.md) | One-page recovery reference |
| [docs/prds/PRD-005-infrastructure-operations.md](docs/prds/PRD-005-infrastructure-operations.md) | Backup/DR requirements |
| [CLAUDE.md](CLAUDE.md) | Development instructions |

## Cloudflare Tunnel (External Access)

Expose local services to the internet via custom domains.

**Domain:** `selfwize.com`
**Tunnel:** `selfwize-dev` (ID: `1f014ff9-68ae-4033-bacf-e058b91d2df4`)
**Status:** Installed, pending reboot verification

| Subdomain | Purpose | Local Target |
|-----------|---------|--------------|
| stuff.selfwize.com | IT/Asset Inventory | localhost:3001 |
| wellness.selfwize.com | Medical/Health Records | localhost:3002 |
| app.selfwize.com | Main Dashboard | localhost:3000 |
| api.selfwize.com | API Endpoint | localhost:8080 |

**Config locations:**
- Service config: `C:\Program Files (x86)\cloudflared\config.yml`
- Credentials: `C:\Program Files (x86)\cloudflared\1f014ff9-68ae-4033-bacf-e058b91d2df4.json`
- User config: `C:\Users\ranand\.cloudflared\config.yml`

**Setup guide:** [docs/guides/CLOUDFLARE-TUNNEL-SETUP.md](docs/guides/CLOUDFLARE-TUNNEL-SETUP.md)

```powershell
# Service management
Get-Service cloudflared
Start-Service cloudflared
Stop-Service cloudflared
Restart-Service cloudflared

# Check tunnel status
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info selfwize-dev

# Fresh install (run as Admin)
.\scripts\install-cloudflared.ps1

# Service-only setup (if tunnel already exists)
.\scripts\setup-cloudflared-service.ps1
```

## Notes

- PostgreSQL runs on localhost:5432 (inventory database)
- MySQL runs on localhost:5432 (homeautomation database for home automation systems)
- pgAdmin available at localhost:5050
- GitHub repo: https://github.com/score-ra/ra-infrastructure

## MySQL (Home Automation) Connection Details

| Setting | Value |
|---------|-------|
| Host | `localhost` |
| Port | `3306` |
| Database | `homeautomation` |
| Username | `homeautomation` |
| Password | `homeautomation_dev_password` |
| Root Password | `mysql_root_dev_password` |

Connection string: `mysql://homeautomation:homeautomation_dev_password@localhost:3306/homeautomation`
