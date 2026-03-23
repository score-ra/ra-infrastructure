- Use plan mode before making multi-file or architectural changes.
- Keep changes minimal. Avoid refactoring beyond what's requested.

# Development
- Test: `cd cli && pytest`
- Lint: `ruff check cli/`
- Format: `black cli/`
- Type check: `mypy cli/src/`
- Health check: `inv system selfcheck`

# Session Management

# Database Conventions
- UUID primary keys, snake_case names
- Include `created_at` and `updated_at` timestamps
- JSONB for flexible metadata
- Prefix migrations: `001_`, `002_`, etc.

# Architecture
- Root `docker-compose.yml` is the active compose file
- CLI uses Typer, installed via `cd cli && pip install -e ".[dev]"`
- Config in `config/infrastructure.env`, secrets in `.env` (git-ignored)
- Docker Desktop settings: `%APPDATA%/Docker/settings-store.json` (AutoStart, etc.)
- `ghcr.io/fastenhealth/fasten-onprem:main` is a distroless image — no shell, curl, wget, or standard Unix utilities. Healthchecks must be disabled or use the app binary.
