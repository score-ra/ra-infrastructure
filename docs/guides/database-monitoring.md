# Database Monitoring Guide

This guide explains how to monitor the ra-infrastructure database for availability and receive notifications when it goes down or recovers.

## Quick Start

```bash
# Check health once
inv db health

# Watch continuously (uses .env settings)
inv db watch

# Watch with custom interval
inv db watch -i 10
```

## Commands Overview

| Command | Description |
|---------|-------------|
| `inv db health` | One-time health check (exit 0=healthy, 1=unhealthy) |
| `inv db status` | Detailed status with uptime and ports |
| `inv db watch` | Continuous monitoring with notifications |
| `inv db stop` | Stop the database container |
| `inv db start` | Start the database container |
| `inv db restart` | Restart the database container |

## Configuration

### Environment Variables (.env)

Create a `.env` file in the project root with your SMTP settings:

```env
# SMTP Configuration
INV_SMTP_HOST=smtp.gmail.com
INV_SMTP_PORT=587
INV_SMTP_USER=your-email@gmail.com
INV_SMTP_PASSWORD=your-app-password
INV_SMTP_TLS=true

# Alert Recipients
INV_ALERT_EMAIL=admin@example.com

# Optional: Webhook (Slack, Teams, custom)
# INV_ALERT_WEBHOOK=https://hooks.slack.com/services/xxx/yyy/zzz
```

### Gmail Setup

To use Gmail for notifications:

1. Enable 2-Factor Authentication on your Google account
2. Generate an App Password:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and your device
   - Copy the 16-character password
3. Use the app password in `INV_SMTP_PASSWORD`

### Command Line Options

All settings can be overridden via command line:

```bash
# Override email only
inv db watch --email different@example.com

# Full command line configuration
inv db watch \
  --email admin@example.com \
  --smtp-host smtp.gmail.com \
  --smtp-port 587 \
  --smtp-tls \
  --smtp-user sender@gmail.com \
  --smtp-password "app-password"

# Use webhook instead of email
inv db watch --webhook https://hooks.slack.com/services/xxx
```

## Watch Command Behavior

The `inv db watch` command:

1. **Checks health** every N seconds (default: 30)
2. **Logs status** to console with timestamp
3. **Detects state changes** (healthy → unhealthy or vice versa)
4. **Sends notifications** only when state changes (not on every check)

### Example Output

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

### Email Notifications

**Subject lines:**
- `[ALERT] Database inventory-db is DOWN`
- `[RECOVERED] Database inventory-db is UP`

**Body includes:**
- Container name
- Timestamp
- Reason/status details

### Webhook Notifications

Sends JSON POST to the configured URL:

```json
{
  "status": "down",
  "container": "inventory-db",
  "reason": "Container inventory-db is exited",
  "timestamp": "2024-11-28 14:31:00"
}
```

Works with:
- Slack Incoming Webhooks
- Microsoft Teams Webhooks
- Custom endpoints

## Testing Notifications

To verify your notification setup:

1. **Start the watcher** in one terminal:
   ```bash
   inv db watch -i 10
   ```

2. **Stop the database** in another terminal:
   ```bash
   inv db stop -y
   ```

3. **Check for DOWN notification** (email or console)

4. **Start the database**:
   ```bash
   inv db start
   ```

5. **Check for RECOVERED notification**

## Running as a Background Service

### Windows (Task Scheduler)

1. Create a batch file `watch-db.bat`:
   ```batch
   @echo off
   cd /d C:\Users\ranand\workspace\personal\software\ra-infrastructure
   C:\Users\ranand\AppData\Local\Python\pythoncore-3.14-64\Scripts\inv.exe db watch
   ```

2. Create a scheduled task to run at startup

### Linux/macOS (systemd)

Create `/etc/systemd/system/db-monitor.service`:

```ini
[Unit]
Description=Database Health Monitor
After=network.target docker.service

[Service]
Type=simple
WorkingDirectory=/path/to/ra-infrastructure
ExecStart=/path/to/inv db watch
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable db-monitor
sudo systemctl start db-monitor
```

## Troubleshooting

### Email Not Sending

1. **Check SMTP settings**: Verify host, port, and TLS setting
2. **App password**: Gmail requires app passwords, not regular passwords
3. **Firewall**: Ensure port 587 (or your SMTP port) is not blocked
4. **Test manually**: Try sending a test email with the same credentials

### Container Not Found

```
Container inventory-db is not found
```

The container doesn't exist. Start it with:
```bash
cd docker && docker-compose up -d
```

### Connection Refused

```
Database connection failed: connection refused
```

Container is running but PostgreSQL isn't ready. Wait a few seconds or check container logs:
```bash
docker logs inventory-db
```

## Integration with External Monitoring

For production environments, consider integrating with:

- **Prometheus + Alertmanager**: Scrape the health endpoint
- **Uptime Kuma**: Self-hosted monitoring
- **Grafana + Loki**: Visualization and log aggregation

The `inv db health` command returns proper exit codes for scripting:
- Exit 0 = healthy
- Exit 1 = unhealthy

---

**See also:**
- [PRD-006: Database Availability Testing](../prds/PRD-006-database-availability-testing.md)
- [DATABASE.md](../DATABASE.md) - Schema and connection details
