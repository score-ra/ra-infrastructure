# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Operations Ready |
| **Last Updated** | 2025-12-10 |
| **Purpose** | Central infrastructure database for other repositories |

## What This Repository Is

**ra-infrastructure** is a standalone PostgreSQL database and CLI for managing:
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
| pgAdmin | `localhost:5050` |
| Database | `inventory` |
| User | `inventory` |
| Backups | `D:\Backups\ra-infrastructure\daily\` |
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
```

## Key Documents

| Document | Purpose |
|----------|---------|
| [docs/DATABASE.md](docs/DATABASE.md) | **External repository integration guide** |
| [docs/DR-RUNBOOK.md](docs/DR-RUNBOOK.md) | **Disaster recovery procedures** |
| [docs/RECOVERY-QUICKSTART.md](docs/RECOVERY-QUICKSTART.md) | One-page recovery reference |
| [docs/prds/PRD-005-infrastructure-operations.md](docs/prds/PRD-005-infrastructure-operations.md) | Backup/DR requirements |
| [CLAUDE.md](CLAUDE.md) | Development instructions |

## Notes

- Database runs on localhost:5432
- pgAdmin available at localhost:5050
- GitHub repo: https://github.com/score-ra/ra-infrastructure
