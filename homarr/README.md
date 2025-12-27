# Homarr Dashboard

Landing page dashboard for all selfwize.com services. Provides a unified view with service tiles, status indicators, and quick access links.

## Quick Start

```powershell
# Start Homarr
cd homarr
docker-compose -f docker-compose.homarr.yml up -d

# Access locally (for initial setup)
Start-Process "http://localhost:7575"

# Access via Cloudflare (after tunnel setup)
Start-Process "https://dash.selfwize.com"
```

## Configuring Services

After Homarr starts, configure services via the web UI:

1. Click the **+** button or enter edit mode
2. Add new service tiles with:

| Service | URL | Suggested Icon |
|---------|-----|----------------|
| Asset Inventory | `https://stuff.selfwize.com` | `snipe-it` or `inventory` |
| Health Records | `https://wellness.selfwize.com` | `health` or `medical` |
| Status Dashboard | `https://status.selfwize.com` | `gatus` or `monitoring` |
| Database Admin | `http://localhost:5050` | `postgresql` |
| Traefik | `http://localhost:8080` | `traefik` |

## Features

- **Service Tiles**: Quick access to all apps
- **Docker Integration**: Shows container status (green/red indicators)
- **Customizable Layout**: Drag and drop tile arrangement
- **Categories**: Group services by type (Infrastructure, Personal, etc.)
- **Search**: Quick search across all services

## Docker Integration

Homarr can show real-time container status. The docker socket is mounted read-only:

```yaml
volumes:
  - //./pipe/docker_engine://var/run/docker.sock:ro
```

This allows Homarr to display which services are running/stopped.

## Backup

Homarr stores configuration in Docker volumes:

- `homarr_config`: Dashboard configuration and layout
- `homarr_icons`: Custom uploaded icons
- `homarr_data`: Application data

To backup:
```powershell
docker run --rm -v homarr_config:/data -v ${PWD}:/backup alpine tar czf /backup/homarr-backup.tar.gz /data
```

## Troubleshooting

### Dashboard Not Loading via Tunnel

1. Verify Traefik is running: `docker ps --filter name=traefik`
2. Check Traefik dashboard for homarr route: http://localhost:8080
3. Verify DNS: `nslookup dash.selfwize.com`

### Docker Status Not Showing

1. Verify socket mount is correct (Windows named pipe)
2. Check Homarr logs: `docker logs homarr`
