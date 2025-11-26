# Claude Code Instructions - ra-infrastructure

## Project Overview

Central infrastructure repository for device inventory, network management, and multi-organization support. This is a personal project for home automation infrastructure management.

## Quick Start

```bash
# Start database
cd docker && docker-compose up -d

# Install CLI (editable)
cd cli && pip install -e ".[dev]"

# Run migrations and seed
inv db migrate && inv db seed

# Run tests
cd cli && pytest
```

## Session Management

### Always Start Here
1. **Read** [start-here.md](start-here.md) for current context
2. **Verify** your environment: `inv db stats`

### Always End Here
1. **Update** [start-here.md](start-here.md) with:
   - Completed tasks
   - Files modified
   - Next steps
   - Any blockers

## Repository Structure

```
ra-infrastructure/
├── cli/                 # Python CLI (inv command)
│   ├── src/inventory/   # Main package
│   │   ├── commands/    # CLI command modules
│   │   └── db/          # Database utilities
│   └── tests/           # Test suite
├── database/
│   ├── migrations/      # SQL migrations (numbered)
│   └── seeds/           # Initial/sample data
├── docker/              # Docker Compose (PostgreSQL + pgAdmin)
├── docs/                # Documentation
├── config/              # Configuration files
├── scripts/             # Utility scripts
└── templates/           # Document templates
```

## Tech Stack

- **Database**: PostgreSQL 16 (Docker)
- **CLI**: Python 3.11+ with Typer
- **Testing**: pytest with 80% coverage target
- **Linting**: ruff, black, mypy

## Development Standards

### Code Quality
- Run `ruff check cli/` before committing (0 errors)
- Run `black cli/` for formatting
- Run `mypy cli/src/` for type checking
- Maintain 80% test coverage: `pytest --cov --cov-fail-under=80`

### Database Conventions
- UUID for primary keys
- snake_case for table/column names
- Include `created_at` and `updated_at` timestamps
- Use JSONB for flexible metadata fields
- Prefix migrations: `001_`, `002_`, etc.

### CLI Pattern
```bash
inv <entity> <action> [options]
inv device list --site primary-residence
inv org show anand-family
```

### Git Conventions
- Branch: `feature/description` or `fix/description`
- Commits: Clear, atomic, focused
- Always run tests before pushing

## Pre-Commit Checklist

Before committing changes:

```bash
# 1. Run tests
cd cli && pytest

# 2. Check linting
ruff check cli/
black --check cli/

# 3. Type check
mypy cli/src/

# 4. Update start-here.md
```

## Key Files

| File | Purpose |
|------|---------|
| `start-here.md` | Session context - READ FIRST |
| `docs/QUICKSTART.md` | Detailed setup guide |
| `docker/docker-compose.yml` | Database infrastructure |
| `cli/pyproject.toml` | Python dependencies |

## Testing

```bash
# Run all tests
cd cli && pytest

# Run with coverage
pytest --cov=inventory --cov-report=term-missing

# Run specific test file
pytest tests/test_commands/test_org.py
```

## Troubleshooting

**Database connection failed:**
```bash
cd docker && docker-compose ps  # Check if running
docker-compose up -d            # Start if needed
```

**CLI not found after install:**
```bash
cd cli && pip install -e .      # Reinstall in editable mode
```
