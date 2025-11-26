# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Phase 1 - Foundation Completion |
| **Last Updated** | 2025-11-26 |
| **Last Session** | Infrastructure verification, Python installation |

## What's Done

- [x] Database schema designed (4 migrations)
- [x] Docker infrastructure (PostgreSQL + pgAdmin)
- [x] CLI skeleton with Typer framework
- [x] Organization commands (list, show, create, delete)
- [x] Database utility commands (migrate, seed, reset, stats)
- [x] Device list command (partial)
- [x] Seed data for Anand Family organization
- [x] Published to GitHub: https://github.com/score-ra/ra-infrastructure
- [x] Architecture plan documented
- [x] Sprint backlog created
- [x] Startup verification script (`scripts/startup.ps1`)
- [x] Docker resource limits configured

## What's Next (Phase 1)

**IMMEDIATE (after reboot):**
1. Verify Python 3.13 installation: `python --version`
2. Install CLI: `cd cli && pip install -e ".[dev]"`
3. Run startup script: `.\scripts\startup.ps1`
4. Verify database: `inv db stats`

**THEN continue with:**
- [ ] Complete site commands (list, create, show, delete)
- [ ] Create zone commands (list, create, show, delete)
- [ ] Complete device commands (create, show, update, delete)
- [ ] Complete network commands (list, show, create)
- [ ] Add repository pattern to db layer
- [ ] Add Pydantic models for validation
- [ ] Achieve 80% test coverage

## Active Blockers

- **Python 3.13 just installed** - Reboot required for long path support
- After reboot, run `.\scripts\startup.ps1` to verify environment

## Infrastructure Status (verified 2025-11-26)

| Component | Status |
|-----------|--------|
| Docker Desktop | Running |
| PostgreSQL container | Running (healthy) on localhost:5432 |
| pgAdmin container | Running on localhost:5050 |
| Python 3.13 | Installed (reboot pending) |
| CLI (inv) | Not yet installed (needs pip install) |

## Key Documents

| Document | Purpose |
|----------|---------|
| [docs/architecture/PLAN.md](docs/architecture/PLAN.md) | Architecture decisions and design |
| [docs/architecture/SPRINT-BACKLOG.md](docs/architecture/SPRINT-BACKLOG.md) | Task tracking by phase |
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Setup instructions |
| [scripts/startup.ps1](scripts/startup.ps1) | Environment verification script |

## Files Modified This Session

```
scripts/startup.ps1 (new) - Environment verification script
docker/docker-compose.yml (updated) - Added resource limits
start-here.md (updated)
```

## Quick Commands

```powershell
# Verify environment (run this first after reboot!)
.\scripts\startup.ps1

# Or manually:
# Start database
cd docker && docker-compose up -d

# Install CLI (editable)
cd cli && pip install -e ".[dev]"

# Run migrations and seed
inv db migrate && inv db seed

# Run tests
cd cli && pytest

# Check code quality
ruff check cli/ && black --check cli/
```

## Architecture Decisions

| Decision | Choice |
|----------|--------|
| API Layer | CLI only (no REST API) |
| Web UI | FastAPI + HTMX + Tailwind (embedded) |
| Integration Priority | HomeSeer first |
| Multi-Site | 4+ sites supported |
| Deployment | Single Windows machine |
| Security | VPN access only |

## Notes

- Database runs on localhost:5432
- pgAdmin available at localhost:5050
- GitHub repo: https://github.com/score-ra/ra-infrastructure
- Docker containers have resource limits (512MB postgres, 256MB pgadmin)
