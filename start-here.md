# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Foundation |
| **Last Updated** | 2025-11-26 |
| **Last Session** | Initial repository setup |

## What's Done

- [x] Database schema designed (4 migrations)
- [x] Docker infrastructure (PostgreSQL + pgAdmin)
- [x] CLI skeleton with Typer framework
- [x] Organization commands (list, show, create, delete)
- [x] Database utility commands (migrate, seed, reset, stats)
- [x] Device list command (partial)
- [x] Seed data for Anand Family organization

## What's Next

- [ ] Complete site commands (create, show, delete)
- [ ] Complete device commands (create, show, import)
- [ ] Complete network commands (list, show, create)
- [ ] Add test suite (target: 80% coverage)
- [ ] Network discovery feature (PRD-004)

## Active Blockers

None

## Files Modified Recently

```
cli/src/inventory/commands/org.py
cli/src/inventory/commands/db.py
cli/src/inventory/commands/device.py
database/migrations/*.sql
database/seeds/001_initial_data.sql
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
pytest

# Check code quality
ruff check cli/ && black --check cli/
```

## Notes

- Database runs on localhost:5432
- pgAdmin available at localhost:5050
- See docs/QUICKSTART.md for detailed setup
