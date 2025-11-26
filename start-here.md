# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Phase 1 - Foundation Completion |
| **Last Updated** | 2025-11-26 |
| **Last Session** | Architecture planning, published to GitHub |

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

## What's Next (Phase 1)

- [ ] Complete site commands (list, create, show, delete)
- [ ] Create zone commands (list, create, show, delete)
- [ ] Complete device commands (create, show, update, delete)
- [ ] Complete network commands (list, show, create)
- [ ] Add repository pattern to db layer
- [ ] Add Pydantic models for validation
- [ ] Achieve 80% test coverage

## Active Blockers

None for Phase 1. See [docs/OPEN-ISSUES.md](docs/OPEN-ISSUES.md) for cross-repo issues.

## Key Documents

| Document | Purpose |
|----------|---------|
| [docs/architecture/PLAN.md](docs/architecture/PLAN.md) | Architecture decisions and design |
| [docs/architecture/SPRINT-BACKLOG.md](docs/architecture/SPRINT-BACKLOG.md) | Task tracking by phase |
| [docs/OPEN-ISSUES.md](docs/OPEN-ISSUES.md) | Cross-repo issues to resolve |
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Setup instructions |

## Files Modified This Session

```
docs/architecture/PLAN.md (new)
docs/architecture/SPRINT-BACKLOG.md (new)
docs/OPEN-ISSUES.md (new)
start-here.md (updated)
```

## Quick Commands

```bash
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
