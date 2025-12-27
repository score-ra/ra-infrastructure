# Traefik Reverse Proxy

Central reverse proxy for all `*.selfwize.com` services. Routes traffic based on hostname using Docker labels or file configuration.

## Quick Start

```powershell
# Ensure inventory_network exists
cd ..\docker
docker-compose up -d

# Start Traefik
cd ..\traefik
docker-compose -f docker-compose.traefik.yml up -d

# Verify
docker ps --filter name=traefik
Start-Process "http://localhost:8080"  # Dashboard
```

## Architecture

```
Internet -> Cloudflare (*.selfwize.com) -> Tunnel -> Traefik:80 -> Services
```

- **Port 80**: Receives HTTP traffic from Cloudflare tunnel
- **Port 8080**: Dashboard (internal only, not exposed via tunnel)

## Adding New Services

### Docker-Based Apps (Recommended)

Add these labels to your docker-compose service:

```yaml
services:
  my-app:
    image: my-app:latest
    networks:
      - inventory_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.selfwize.com`)"
      - "traefik.http.routers.myapp.entrypoints=web"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"

networks:
  inventory_network:
    external: true
```

Then start the container - Traefik auto-discovers it. No DNS or tunnel changes needed!

### Non-Docker Apps

Add to `dynamic/external-services.yml`:

```yaml
http:
  routers:
    myapp-router:
      rule: "Host(`myapp.selfwize.com`)"
      entryPoints:
        - web
      service: myapp-service

  services:
    myapp-service:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:3456"
```

Traefik auto-reloads when the file changes.

### Apps with Self-Signed Certificates

```yaml
http:
  services:
    myapp-service:
      loadBalancer:
        servers:
          - url: "https://host.docker.internal:9443"
        serversTransport: insecure-transport

  serversTransports:
    insecure-transport:
      insecureSkipVerify: true
```

## Current Routes

| Hostname | Service | Type |
|----------|---------|------|
| `dash.selfwize.com` | Homarr Dashboard | Docker |
| `status.selfwize.com` | Gatus Monitoring | Docker |
| `stuff.selfwize.com` | Snipe-IT | External |
| `wellness.selfwize.com` | Fasten Health | External |

## Troubleshooting

### Service Not Found (404)

1. Check Traefik dashboard: http://localhost:8080
2. Verify container has `traefik.enable=true` label
3. Verify container is on `inventory_network`

### Connection Refused

1. Verify service is running: `docker ps`
2. Check service port matches label configuration

### External Service Not Reachable

1. Verify service is running on host
2. Check `host.docker.internal` resolves (Docker Desktop only)
3. For HTTPS services, ensure `serversTransport` is configured

## Files

| File | Purpose |
|------|---------|
| `docker-compose.traefik.yml` | Container definition |
| `traefik.yml` | Static configuration |
| `dynamic/external-services.yml` | External service routes |
