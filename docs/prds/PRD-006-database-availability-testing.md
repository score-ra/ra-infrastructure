# PRD-006: Database Availability Testing

## Overview

Provide CLI commands to test and verify database and Docker container availability. This enables infrastructure owners to validate notification and alerting systems by intentionally bringing down components.

## Problem Statement

As the infrastructure owner, I need to:
1. Verify the database container is running
2. Verify the database is accepting connections
3. Intentionally stop/start components to test monitoring and alerting
4. Get clear status feedback for automation and scripting

## MVP Requirements

### 1. Health Check Command

```bash
inv db health
```

**Output:**
- Docker container status (running/stopped)
- Database connection status (connected/failed)
- Connection latency
- Exit code: 0 = healthy, 1 = unhealthy

### 2. Container Control Commands

```bash
inv db stop       # Stop the database container
inv db start      # Start the database container
inv db restart    # Restart the database container
```

### 3. Status Command (Enhanced)

```bash
inv db status
```

**Output:**
- Container name and state
- Uptime
- Port mappings
- Database connection test result
- Last health check timestamp

## CLI Output Examples

### `inv db health` - All Healthy
```
Database Health Check
─────────────────────
Container:  inventory-db [running]
Database:   connected (latency: 12ms)
Status:     HEALTHY
```

### `inv db health` - Container Down
```
Database Health Check
─────────────────────
Container:  inventory-db [stopped]
Database:   N/A
Status:     UNHEALTHY - Container not running
```

### `inv db health` - Container Up, DB Not Responding
```
Database Health Check
─────────────────────
Container:  inventory-db [running]
Database:   connection refused
Status:     UNHEALTHY - Database not accepting connections
```

## Test Scenarios

| Scenario | Command | Expected Result |
|----------|---------|-----------------|
| Normal operation | `inv db health` | Exit 0, HEALTHY |
| Stop container | `inv db stop && inv db health` | Exit 1, UNHEALTHY |
| Restart container | `inv db restart && inv db health` | Exit 0, HEALTHY |

## Implementation

### Files to Create/Modify

| File | Change |
|------|--------|
| `cli/src/inventory/commands/db.py` | Add `health`, `stop`, `start`, `restart`, `status` commands |

### Dependencies

- Docker CLI available in PATH
- `docker-compose` or `docker compose` available
- psycopg3 for connection testing

## Success Criteria

1. `inv db health` returns correct exit code for healthy/unhealthy states
2. `inv db stop` successfully stops the container
3. `inv db start` successfully starts the container
4. Commands work on Windows (PowerShell)
5. Output is clear and scriptable (exit codes)

## Out of Scope

- External monitoring integration (Prometheus, etc.)
- Alerting/notification systems
- Automatic recovery

---

**Created**: 2024-11-28
**Status**: Ready for Implementation
