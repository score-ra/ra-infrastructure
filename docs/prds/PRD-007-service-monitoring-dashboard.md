# PRD-007: Service Monitoring Dashboard (Gatus)

## Overview

| Field | Value |
|-------|-------|
| **PRD Number** | PRD-007 |
| **Title** | Service Monitoring Dashboard with Gatus |
| **Status** | Implemented |
| **Created** | 2025-12-21 |
| **Implemented** | 2025-12-21 |
| **Author** | Infrastructure Team |

## Problem Statement

The existing health monitoring (PRD-005/PRD-006) provides CLI-based checks and PowerShell automation but lacks:
- Visual status dashboard for quick health overview
- Persistent status history for trend analysis
- Standardized uptime tracking
- Real-time web-accessible monitoring
- SSL certificate expiration monitoring for external endpoints

Users must run CLI commands or check logs to understand service status. There is no at-a-glance view of infrastructure health.

## Goals

1. **Visibility**: Provide web-based status dashboard accessible at `localhost:8083`
2. **Monitoring**: Check 5 core services every 30-60 seconds
3. **Alerting**: Send email notifications on failures and recoveries (using existing SMTP config)
4. **Persistence**: Store status history in SQLite for trend analysis
5. **SSL Monitoring**: Track certificate expiration for Cloudflare Tunnel endpoints

## Non-Goals

- External/public status page (internal use only)
- Slack integration (email only per requirements)
- Monitoring of third-party APIs beyond Cloudflare tunnel endpoints
- Custom webhook integrations
- Real-time metrics/Prometheus integration

---

## Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| MON-01 | PostgreSQL TCP connectivity check (port 5432) | P0 |
| MON-02 | MySQL TCP connectivity check (port 3306) | P0 |
| MON-03 | pgAdmin HTTP health check (port 80) | P1 |
| MON-04 | Snipe-IT external endpoint (stuff.selfwize.com) | P1 |
| MON-05 | Fasten Health external endpoint (wellness.selfwize.com) | P1 |
| MON-06 | Email alerting on service failures | P0 |
| MON-07 | Email notification on service recovery | P0 |
| MON-08 | Web dashboard on port 8081 | P0 |
| MON-09 | SSL certificate expiration warnings (7+ days) | P1 |
| MON-10 | Status history persistence across restarts | P1 |

---

## Implementation Details

### Technology Selection: Gatus

**Why Gatus:**
- Lightweight (~50MB memory footprint)
- Single container, no dependencies
- YAML-based configuration
- Built-in status dashboard
- SQLite for history persistence
- Native email alerting support
- SSL certificate monitoring
- Active open-source project

**Reference Implementation:** sc-infrastructure uses Gatus for internal monitoring

### Architecture

```
┌─────────────────────────────────────────────┐
│          ra-infrastructure Host             │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  Gatus Container (ra-status:8083)    │  │
│  │  - Runs health checks every 30-60s   │  │
│  │  - Displays status dashboard         │  │
│  │  - Manages email alerts              │  │
│  │  - Stores history in SQLite          │  │
│  └──────────────────────────────────────┘  │
│         ↓ monitors                         │
│  ┌──────────────────────────────────────┐  │
│  │  Database Services (inventory_network)│  │
│  │  - inventory-db (PostgreSQL:5432)    │  │
│  │  - homeautomation-db (MySQL:3306)    │  │
│  │  - inventory-pgadmin (HTTP:80)       │  │
│  └──────────────────────────────────────┘  │
│         ↓ monitors                         │
│  ┌──────────────────────────────────────┐  │
│  │  External Endpoints (Cloudflare)     │  │
│  │  - stuff.selfwize.com (Snipe-IT)     │  │
│  │  - wellness.selfwize.com (Fasten)    │  │
│  └──────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
         ↓ sends alerts to
┌──────────────────────────────────────────┐
│   Email (via existing SMTP config)       │
└──────────────────────────────────────────┘
```

### Monitored Endpoints

| Group | Service | URL/Target | Check Type | Interval | Alert Threshold |
|-------|---------|------------|------------|----------|-----------------|
| Databases | PostgreSQL | `tcp://inventory-db:5432` | TCP | 30s | 2 failures |
| Databases | MySQL | `tcp://homeautomation-db:3306` | TCP | 30s | 2 failures |
| Management | pgAdmin | `http://inventory-pgadmin:80` | HTTP 200 | 60s | 2 failures |
| External | Snipe-IT | `https://stuff.selfwize.com` | HTTPS + SSL | 60s | 2 failures |
| External | Fasten Health | `https://wellness.selfwize.com` | HTTPS + SSL | 60s | 2 failures |

### Health Check Conditions

**TCP Checks (Databases):**
```yaml
conditions:
  - "[CONNECTED] == true"
```

**HTTP Checks (pgAdmin):**
```yaml
conditions:
  - "[STATUS] == 200"
  - "[RESPONSE_TIME] < 5000"
```

**HTTPS Checks (External):**
```yaml
conditions:
  - "[STATUS] == any(200, 302)"          # 302 = Cloudflare Access redirect
  - "[RESPONSE_TIME] < 10000"
  - "[CERTIFICATE_EXPIRATION] > 168h"    # 7 days warning
```

### Alert Configuration

**Email Alerting:**
- Uses existing SMTP configuration from `config/monitoring.env`
- Failure threshold: 2 consecutive failures (avoids false positives)
- Success threshold: 2 consecutive successes (confirms recovery)
- Send-on-resolved: Yes (recovery notifications enabled)

**Alert Email Format:**
- Subject: `[Gatus] Service Down: <service-name>`
- Body: Service details, check conditions, timestamp

---

## File Structure

After implementation:

```
ra-infrastructure/
├── gatus/
│   ├── config/
│   │   └── gatus.yaml              # Endpoint configuration
│   ├── docker-compose.gatus.yml    # Container definition
│   ├── .env                        # SMTP credentials (gitignored)
│   ├── .env.template               # Template for setup
│   └── README.md                   # Quick start guide
├── docs/
│   └── prds/
│       └── PRD-007-service-monitoring-dashboard.md
└── .gitignore                      # Updated with gatus/.env
```

---

## CLI Commands

### Start Gatus
```powershell
cd gatus && docker-compose -f docker-compose.gatus.yml up -d
```

### Stop Gatus
```powershell
docker-compose -f gatus/docker-compose.gatus.yml down
```

### View Logs
```powershell
docker-compose -f gatus/docker-compose.gatus.yml logs -f
```

### Restart Gatus
```powershell
docker-compose -f gatus/docker-compose.gatus.yml restart
```

### Check Container Status
```powershell
docker ps --filter name=ra-status
```

---

## Success Criteria

| Criteria | Target |
|----------|--------|
| Dashboard loads at localhost:8083 | Yes |
| All 5 endpoints monitored | Yes |
| Green status for healthy services | Yes |
| Email sent within 2 minutes of failure | Yes |
| Recovery email sent on service restoration | Yes |
| Status history persists across container restarts | Yes |
| Resource usage | < 128MB RAM |

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| Docker Desktop running | Required | Main infrastructure must be up first |
| `inventory_network` exists | Required | Created by main docker-compose |
| SMTP credentials configured | Required | Copy from existing `config/monitoring.env` |
| Cloudflare Tunnel running | Optional | External endpoint checks will fail if tunnel is down |

---

## Relationship to Existing Monitoring

This PRD complements existing monitoring (PRD-005/PRD-006):

| Feature | health-check.ps1 (PRD-005) | Gatus (PRD-007) |
|---------|----------------------------|-----------------|
| **Type** | PowerShell script | Docker container |
| **Execution** | Scheduled Task (5 min) | Continuous (30-60s) |
| **UI** | Console output / logs | Web dashboard |
| **History** | Log files | SQLite database |
| **Docker Desktop check** | Yes | No |
| **MySQL check** | No | Yes |
| **External URLs** | No | Yes |
| **SSL monitoring** | No | Yes |

**Recommendation:** Keep both systems running. They are complementary:
- `health-check.ps1`: Deep Docker integration, checks Docker Desktop process
- `Gatus`: Visual dashboard, external URL validation, SSL monitoring

---

## Future Enhancements (Out of Scope)

- PRD-008: Expose Gatus via Cloudflare Tunnel for remote access
- Prometheus/Grafana integration for metrics
- Custom webhook for home automation triggers
- Mobile push notifications via Pushover
- Slack integration

---

## Appendix A: Configuration Reference

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_HOST` | SMTP server hostname | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `SMTP_FROM` | Sender email address | `alerts@example.com` |
| `SMTP_USERNAME` | SMTP authentication username | `alerts@example.com` |
| `SMTP_PASSWORD` | SMTP authentication password | `app-password` |
| `ALERT_EMAIL` | Recipient email address | `admin@example.com` |

### Docker Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '0.25'
      memory: 128M
    reservations:
      cpus: '0.1'
      memory: 64M
```

---

## Appendix B: Troubleshooting

### Gatus container fails to start

**Symptom:** Container exits immediately

**Check:**
1. Verify `inventory_network` exists: `docker network ls | findstr inventory`
2. If not, start main infrastructure first: `cd docker && docker-compose up -d`
3. Check config syntax: `docker-compose -f gatus/docker-compose.gatus.yml config`

### External endpoints show as down

**Symptom:** Snipe-IT and Fasten Health show red

**Check:**
1. Verify Cloudflare Tunnel is running: `Get-Service cloudflared`
2. Test endpoint manually: `curl https://stuff.selfwize.com`
3. This is expected behavior if tunnel is stopped

### No email alerts received

**Symptom:** Service goes down but no email

**Check:**
1. Verify `.env` file exists in `gatus/` directory
2. Check SMTP credentials match `config/monitoring.env`
3. View Gatus logs: `docker logs ra-status`
4. Test SMTP connectivity from host

### Dashboard not accessible

**Symptom:** Cannot reach `localhost:8081`

**Check:**
1. Container running: `docker ps --filter name=ra-status`
2. Port not in use: `netstat -an | findstr 8081`
3. Firewall allowing local connections
