---
title: "PRD-008: Reverse Proxy Infrastructure with Traefik + Homarr"
status: "approved"
priority: "high"
created: "2025-12-27"
updated: "2025-12-27"
author: "Rohit Anand"
depends_on: ["PRD-007"]
---

# PRD-008: Reverse Proxy Infrastructure with Traefik + Homarr

## Overview

| Field | Value |
|-------|-------|
| Status | Approved |
| Priority | High |
| Created | 2025-12-27 |
| Author | Rohit Anand |

## Problem Statement

The current Cloudflare tunnel configuration requires manual changes for each new service:
1. Add DNS CNAME record in Cloudflare dashboard
2. Add ingress rule in cloudflared config
3. Restart cloudflared service
4. Configure Cloudflare Access policy (if protected)

As the number of applications grows (home automation, monitoring tools, personal apps), this manual process becomes:
- Time-consuming
- Error-prone
- Difficult to maintain

## Goals

- **Scalability**: Add new services with only Docker labels - no Cloudflare changes
- **Centralized Routing**: Single point of entry for all `*.selfwize.com` traffic
- **Service Discovery**: Dashboard showing all available services
- **Per-App Auth**: Maintain ability to protect some apps while leaving others public

## Non-Goals

- High availability / load balancing across multiple hosts
- Automatic SSL certificate management (Cloudflare handles this)
- Complex traffic policies (rate limiting, circuit breakers)

## Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| RP-01 | Wildcard DNS `*.selfwize.com` routes to tunnel | P0 | Pending |
| RP-02 | Traefik receives all tunnel traffic on port 80 | P0 | Pending |
| RP-03 | Traefik auto-discovers Docker containers with labels | P0 | Pending |
| RP-04 | External services (Snipe-IT, Fasten) routed via file config | P0 | Pending |
| RP-05 | Homarr dashboard at dash.selfwize.com | P1 | Pending |
| RP-06 | Gatus monitoring at status.selfwize.com | P1 | Pending |
| RP-07 | Cloudflare Access protection preserved | P0 | Pending |
| RP-08 | Traefik dashboard accessible locally at :8080 | P2 | Pending |

## Architecture

### Before (Per-Service Routing)

```
Internet → Cloudflare → Tunnel → cloudflared config routes to:
                                  ├── stuff.selfwize.com → localhost:8082
                                  ├── wellness.selfwize.com → localhost:9090
                                  └── dash.selfwize.com → localhost:8083
```

### After (Centralized Routing)

```
Internet → Cloudflare (*.selfwize.com) → Tunnel → Traefik:80 → Services
                                                      │
                    ┌─────────────┬─────────────┬─────┴─────┬─────────────┐
                    ▼             ▼             ▼           ▼             ▼
                 Homarr        Gatus       Snipe-IT     Fasten      Future Apps
              dash.selfwize  status.selfwize  stuff.*   wellness.*    (via labels)
```

## Implementation

### Phase 1: Traefik Infrastructure

**Files Created:**
- `traefik/docker-compose.traefik.yml` - Container definition
- `traefik/traefik.yml` - Static configuration
- `traefik/dynamic/external-services.yml` - External service routes
- `traefik/README.md` - Documentation

**Key Configuration:**
- Entry point on port 80 (receives HTTP from tunnel, SSL terminated at Cloudflare)
- Docker provider with Windows named pipe
- File provider for external services
- Cloudflare IP trust for X-Forwarded headers

### Phase 2: Homarr Dashboard

**Files Created:**
- `homarr/docker-compose.homarr.yml` - Container with Traefik labels
- `homarr/README.md` - Configuration guide

**Traefik Labels:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.homarr.rule=Host(`dash.selfwize.com`)"
  - "traefik.http.services.homarr.loadbalancer.server.port=7575"
```

### Phase 3: Gatus Migration

**Files Modified:**
- `gatus/docker-compose.gatus.yml` - Added Traefik labels

**Changes:**
- New hostname: `status.selfwize.com` (was `dash.selfwize.com`)
- Added Traefik routing labels
- Kept port 8083 for direct local access

### Phase 4: Cloudflare Configuration

**DNS (Cloudflare Dashboard):**
```
Type: CNAME
Name: *
Content: 1f014ff9-68ae-4033-bacf-e058b91d2df4.cfargotunnel.com
Proxy: Enabled (orange cloud)
```

**Tunnel Config:**
```yaml
ingress:
  - hostname: "*.selfwize.com"
    service: http://localhost:80
  - service: http_status:404
```

## Adding New Services

### Docker-Based Service

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
```

**That's it!** No DNS changes, no tunnel config changes, no service restart.

### Non-Docker Service

Add to `traefik/dynamic/external-services.yml`:
```yaml
http:
  routers:
    myapp-router:
      rule: "Host(`myapp.selfwize.com`)"
      service: myapp-service
  services:
    myapp-service:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:3456"
```

## Service Mapping

| Hostname | Service | Type | Protected |
|----------|---------|------|-----------|
| dash.selfwize.com | Homarr Dashboard | Docker | Optional |
| status.selfwize.com | Gatus Monitoring | Docker | Optional |
| stuff.selfwize.com | Snipe-IT | External | Yes |
| wellness.selfwize.com | Fasten Health | External | Yes |

## Migration Plan

1. **Deploy Traefik** (parallel) - No disruption
2. **Deploy Homarr** - No disruption
3. **Update Gatus** - Brief container restart
4. **Add wildcard DNS** - Instant propagation
5. **Update tunnel config** - Brief reconnection
6. **Verify all services** - Test public URLs
7. **Create Cloudflare Access apps** - For new subdomains

## Rollback Plan

```powershell
# Restore original tunnel config
Copy-Item "C:\Program Files (x86)\cloudflared\config.yml.backup" `
          "C:\Program Files (x86)\cloudflared\config.yml" -Force
Restart-Service cloudflared

# Stop Traefik and Homarr
docker stop traefik homarr
```

## Success Criteria

| Criteria | Target | Status |
|----------|--------|--------|
| Existing services accessible | All 3 (Snipe-IT, Fasten, Gatus) | Pending |
| Homarr loads at dash.selfwize.com | Yes | Pending |
| Traefik dashboard at localhost:8080 | Yes | Pending |
| New app requires only Docker labels | Yes | Pending |
| No Cloudflare changes for new apps | Yes | Pending |
| Resource usage | <512MB total | Pending |

## Dependencies

- Docker Desktop (Windows)
- Cloudflare Tunnel (cloudflared service)
- Cloudflare Access (Zero Trust)
- inventory_network Docker network

## Files Structure

```
ra-infrastructure/
├── traefik/
│   ├── docker-compose.traefik.yml
│   ├── traefik.yml
│   ├── dynamic/
│   │   └── external-services.yml
│   └── README.md
├── homarr/
│   ├── docker-compose.homarr.yml
│   └── README.md
├── gatus/
│   └── docker-compose.gatus.yml  (modified)
├── config/
│   └── cloudflared-config.template.yml  (modified)
└── docs/
    ├── prds/
    │   └── PRD-008-reverse-proxy-infrastructure.md
    └── guides/
        └── TRAEFIK-SETUP.md
```

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-27 | 1.0 | Initial PRD creation |
