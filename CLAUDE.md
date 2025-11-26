# Claude Code Instructions - Infrastructure Repository

## Project Overview
Central infrastructure repository for device inventory, network management, and multi-organization support.

## Repository Structure

```
ra-infrastructure/
├── docker/              # Docker Compose for PostgreSQL + pgAdmin
├── database/
│   ├── migrations/      # SQL migration files (numbered)
│   └── seeds/           # Initial/sample data
├── cli/                 # Python CLI (inv command)
├── api/                 # Node.js REST API (future)
└── docs/                # Documentation
```

## Tech Stack
- **Database**: PostgreSQL 16 (Docker)
- **CLI**: Python 3.11+ with Typer/Click
- **API**: Node.js with Express/Fastify (future)

## Database Schema Conventions
- Use UUID for primary keys
- Use snake_case for table/column names
- Include `created_at` and `updated_at` timestamps
- Use JSONB for flexible metadata fields
- Prefix migrations with numbers: `001_`, `002_`, etc.

## CLI Commands Pattern
```bash
inv <entity> <action> [options]
inv device list --site primary-residence
inv device create "Living Room Switch" --type switch
```

## Development Setup
```bash
# Start database
cd docker && docker-compose up -d

# Install CLI
cd cli && pip install -e .

# Run migrations
inv db migrate

# Seed data
inv db seed
```

## Testing
- Run `pytest` for Python tests
- Database tests use test schema/transactions

## Git Conventions
- Branch: `feature/description` or `fix/description`
- Commits: Clear, atomic, focused
- PRs: Required for main branch
