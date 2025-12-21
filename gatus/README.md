# ra-infrastructure Status Dashboard

Gatus-based service monitoring for home infrastructure.

**PRD:** [docs/prds/PRD-007-service-monitoring-dashboard.md](../docs/prds/PRD-007-service-monitoring-dashboard.md)

## Quick Start

```powershell
# 1. Ensure main infrastructure is running
cd docker && docker-compose up -d
cd ..

# 2. Copy environment template and configure SMTP
Copy-Item gatus\.env.template gatus\.env
notepad gatus\.env
# Fill in SMTP credentials (copy from config/monitoring.env if available)

# 3. Start Gatus
cd gatus && docker-compose -f docker-compose.gatus.yml up -d

# 4. Access dashboard
Start-Process "http://localhost:8083"
```

## Monitored Services

| Group | Service | Check Type | Interval | Alerts |
|-------|---------|------------|----------|--------|
| Databases | PostgreSQL | TCP 5432 | 30s | Email |
| Databases | MySQL | TCP 3306 | 30s | Email |
| Management | pgAdmin | HTTP 80 | 60s | Email |
| External Access | Snipe-IT | HTTPS + SSL | 60s | Email |
| External Access | Fasten Health | HTTPS + SSL | 60s | Email |

## Commands

```powershell
# Start Gatus
docker-compose -f gatus/docker-compose.gatus.yml up -d

# Stop Gatus
docker-compose -f gatus/docker-compose.gatus.yml down

# View logs
docker-compose -f gatus/docker-compose.gatus.yml logs -f

# Restart Gatus
docker-compose -f gatus/docker-compose.gatus.yml restart

# Check container status
docker ps --filter name=ra-status
```

## Dashboard Access

- **Local URL:** http://localhost:8083
- **External URL:** https://dash.selfwize.com (via Cloudflare Tunnel)
- **Features:**
  - Real-time service status (green/red indicators)
  - Response time graphs
  - Uptime percentage
  - Status history

## Alert Behavior

- **Failure threshold:** 2 consecutive failures before alerting
- **Recovery notification:** Sent when service returns to healthy
- **Email delivery:** Using SMTP configured in `.env`

## Files

| File | Purpose |
|------|---------|
| `docker-compose.gatus.yml` | Container definition |
| `config/gatus.yaml` | Endpoint configuration |
| `.env` | SMTP credentials (gitignored) |
| `.env.template` | Template for new setups |

## Troubleshooting

### Container fails to start

```powershell
# Check if inventory_network exists
docker network ls | findstr inventory

# If not, start main infrastructure first
cd docker && docker-compose up -d
```

### External endpoints show as down

This is expected if Cloudflare Tunnel is not running:

```powershell
# Check tunnel status
Get-Service cloudflared
```

### No email alerts received

1. Verify `.env` exists and has correct SMTP credentials
2. Check Gatus logs: `docker logs ra-status`
3. Test SMTP connectivity independently

### Dashboard not accessible

```powershell
# Check container is running
docker ps --filter name=ra-status

# Check port availability
netstat -an | findstr 8081
```
