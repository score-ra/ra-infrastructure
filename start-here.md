# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Foundation Complete |
| **Last Updated** | 2025-11-27 |
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
| Database | `ra_inventory` |
| User | `inventory` |

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
| [docs/architecture/SPRINT-BACKLOG.md](docs/architecture/SPRINT-BACKLOG.md) | Completed task tracking |
| [CLAUDE.md](CLAUDE.md) | Development instructions |

## Notes

- Database runs on localhost:5432
- pgAdmin available at localhost:5050
- GitHub repo: https://github.com/score-ra/ra-infrastructure
