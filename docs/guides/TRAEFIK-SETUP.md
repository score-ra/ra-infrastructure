# Traefik Reverse Proxy Setup Guide

This guide covers the complete setup of Traefik reverse proxy with Cloudflare wildcard tunnel for the ra-infrastructure project.

## Prerequisites

- Docker Desktop running on Windows
- Cloudflare account with selfwize.com domain
- Existing tunnel: `selfwize-dev` (ID: 1f014ff9-68ae-4033-bacf-e058b91d2df4)
- `inventory_network` Docker network exists

## Architecture Overview

```
Internet → Cloudflare (*.selfwize.com) → Tunnel → Traefik:80 → Services
```

All traffic to any `*.selfwize.com` subdomain flows through:
1. **Cloudflare**: SSL termination, DDoS protection, Access authentication
2. **Tunnel**: Secure connection to local network
3. **Traefik**: Routes to correct service based on hostname

## Step 1: Deploy Traefik

```powershell
# Ensure inventory_network exists
cd C:\Users\ranand\workspace\personal\software\ra-infrastructure\docker
docker-compose up -d

# Start Traefik
cd ..\traefik
docker-compose -f docker-compose.traefik.yml up -d

# Verify
docker ps --filter name=traefik
```

**Expected output:**
```
CONTAINER ID   IMAGE          STATUS         PORTS
abc123         traefik:v3.2   Up 10 seconds  0.0.0.0:80->80/tcp, 0.0.0.0:8080->8080/tcp
```

**Test Traefik Dashboard:**
```powershell
Start-Process "http://localhost:8080"
```

## Step 2: Deploy Homarr Dashboard

```powershell
cd C:\Users\ranand\workspace\personal\software\ra-infrastructure\homarr
docker-compose -f docker-compose.homarr.yml up -d

# Test via Traefik (locally)
curl.exe -H "Host: dash.selfwize.com" http://localhost:80
```

## Step 3: Update Gatus

```powershell
cd C:\Users\ranand\workspace\personal\software\ra-infrastructure\gatus
docker-compose -f docker-compose.gatus.yml up -d --force-recreate

# Test via Traefik (locally)
curl.exe -H "Host: status.selfwize.com" http://localhost:80
```

## Step 4: Test External Services via Traefik

```powershell
# Test Snipe-IT routing
curl.exe -H "Host: stuff.selfwize.com" http://localhost:80

# Test Fasten Health routing
curl.exe -H "Host: wellness.selfwize.com" http://localhost:80
```

## Step 5: Configure Wildcard DNS

1. Log into Cloudflare Dashboard
2. Go to **DNS** settings for selfwize.com
3. Add new record:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| CNAME | `*` | `1f014ff9-68ae-4033-bacf-e058b91d2df4.cfargotunnel.com` | Proxied |

4. Save and wait for propagation (usually instant)

## Step 6: Update Cloudflare Tunnel

```powershell
# Backup current config
Copy-Item "C:\Program Files (x86)\cloudflared\config.yml" `
          "C:\Program Files (x86)\cloudflared\config.yml.backup"

# Edit config (as Administrator)
notepad "C:\Program Files (x86)\cloudflared\config.yml"
```

**Replace ingress section with:**
```yaml
ingress:
  - hostname: "*.selfwize.com"
    service: http://localhost:80
  - service: http_status:404
```

**Restart tunnel:**
```powershell
Restart-Service cloudflared
```

## Step 7: Verify Public Access

```powershell
# Test all services via public URLs
Start-Process "https://dash.selfwize.com"      # Homarr
Start-Process "https://status.selfwize.com"    # Gatus
Start-Process "https://stuff.selfwize.com"     # Snipe-IT
Start-Process "https://wellness.selfwize.com"  # Fasten Health
```

## Step 8: Configure Cloudflare Access (Optional)

For new subdomains that need protection:

1. Go to Cloudflare Zero Trust Dashboard
2. Access → Applications → Add Application
3. Configure:
   - Application domain: `status.selfwize.com`
   - Session duration: 24 hours
   - Policy: Email allowlist

## Adding New Services

### Docker Service

Add to your docker-compose.yml:
```yaml
services:
  my-app:
    image: my-app:latest
    networks:
      - inventory_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.selfwize.com`)"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"

networks:
  inventory_network:
    external: true
```

Then start it:
```powershell
docker-compose up -d
```

**Done!** The service is immediately available at `https://myapp.selfwize.com`

### Non-Docker Service

Edit `traefik/dynamic/external-services.yml`:
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

Traefik auto-reloads within seconds.

## Troubleshooting

### 502 Bad Gateway

1. Check if Traefik is running: `docker ps --filter name=traefik`
2. Check Traefik dashboard for the route: http://localhost:8080
3. Verify the backend service is running

### 404 Not Found

1. Route not found in Traefik
2. Check container has correct labels
3. Verify container is on `inventory_network`

### Service Not Appearing in Traefik Dashboard

1. Verify `traefik.enable=true` label
2. Check container is on correct network
3. Check Traefik logs: `docker logs traefik`

### External Service Connection Refused

1. Verify service is running on host
2. Check port is correct
3. For Docker Desktop, use `host.docker.internal` not `localhost`

## Rollback

If something goes wrong:

```powershell
# Restore original tunnel config
Copy-Item "C:\Program Files (x86)\cloudflared\config.yml.backup" `
          "C:\Program Files (x86)\cloudflared\config.yml" -Force
Restart-Service cloudflared

# Stop Traefik
docker stop traefik

# Services go back to direct tunnel routing
```

## Useful Commands

```powershell
# Check Traefik status
docker ps --filter name=traefik

# View Traefik logs
docker logs traefik -f

# Restart Traefik
docker restart traefik

# Check tunnel status
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info selfwize-dev

# List all Traefik routes
curl http://localhost:8080/api/http/routers | ConvertFrom-Json | Format-Table
```
