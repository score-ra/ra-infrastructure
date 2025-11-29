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

### 4. Watch Command (Continuous Monitoring)

```bash
inv db watch [OPTIONS]
```

**Options:**
- `--interval, -i` - Check interval in seconds (default: 30)
- `--email, -e` - Email address for notifications
- `--smtp-host` - SMTP server host (default: localhost)
- `--smtp-port` - SMTP server port (default: 25)
- `--smtp-user` - SMTP username for authentication
- `--smtp-password` - SMTP password for authentication
- `--smtp-tls` - Use TLS for SMTP connection
- `--webhook, -w` - Webhook URL for notifications (sends JSON POST)

**Behavior:**
- Monitors database health continuously
- Sends notifications only on state changes (DOWN or RECOVERED)
- Logs each check to console with timestamp
- Press Ctrl+C to stop

**Examples:**
```bash
# Console output only
inv db watch

# Email notifications via local SMTP
inv db watch --email admin@example.com

# Gmail SMTP (requires app password)
inv db watch -e you@gmail.com --smtp-host smtp.gmail.com --smtp-port 587 --smtp-tls --smtp-user you@gmail.com --smtp-password "app-password"

# Webhook notifications (Slack, Teams, custom)
inv db watch --webhook https://hooks.slack.com/services/xxx/yyy/zzz
```

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

### `inv db watch` - Continuous Monitoring
```
Database Health Monitor
------------------------------
Interval:     30s
Email:        admin@example.com
------------------------------
Press Ctrl+C to stop

[2024-11-28 14:30:00] OK - Healthy (latency: 12ms)
[2024-11-28 14:30:30] OK - Healthy (latency: 15ms)
[2024-11-28 14:31:00] DOWN - Container inventory-db is exited
  State changed: DOWN
  Sending email to admin@example.com... sent
[2024-11-28 14:31:30] DOWN - Container inventory-db is exited
[2024-11-28 14:32:00] OK - Healthy (latency: 18ms)
  State changed: UP
  Sending email to admin@example.com... sent
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
- Automatic recovery

---

**Created**: 2024-11-28
**Updated**: 2024-11-28 - Added watch command with email/webhook notifications
**Status**: Implemented
