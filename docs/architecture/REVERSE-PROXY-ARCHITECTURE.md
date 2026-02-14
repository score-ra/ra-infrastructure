# Reverse Proxy Architecture

Developer reference for understanding the traffic flow, component interactions, and configuration of the ra-infrastructure reverse proxy system.

## Traffic Flow Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    INTERNET                                          │
└─────────────────────────────────────────┬───────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              CLOUDFLARE EDGE                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  DNS: *.selfwize.com → CNAME → cfargotunnel.com                             │    │
│  │  SSL: Termination (Full mode) - presents valid certificate to browser       │    │
│  │  Protection: DDoS, WAF, Bot management                                      │    │
│  │  Auth: Cloudflare Access (Zero Trust) - per-application policies            │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────┬───────────────────────────────────────────┘
                                          │ Encrypted tunnel (QUIC/HTTP2)
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARED SERVICE (Windows)                                │
│  Location: C:\Program Files (x86)\cloudflared\                                       │
│  Config: config.yml                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  ingress:                                                                   │    │
│  │    - hostname: "*.selfwize.com"                                             │    │
│  │      service: http://localhost:80  ─────────────────────┐                   │    │
│  │    - service: http_status:404                           │                   │    │
│  └─────────────────────────────────────────────────────────│───────────────────┘    │
└────────────────────────────────────────────────────────────│────────────────────────┘
                                                             │ HTTP (plain)
                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           TRAEFIK REVERSE PROXY                                      │
│  Container: traefik (port 80, dashboard 8080)                                        │
│  Config: traefik/traefik.yml + traefik/dynamic/*.yml                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  Routing Decision (based on Host header):                                   │    │
│  │                                                                             │    │
│  │    Host: dash.selfwize.com     → homarr-service                             │    │
│  │    Host: status.selfwize.com   → gatus-service                              │    │
│  │    Host: stuff.selfwize.com    → snipeit-service                            │    │
│  │    Host: wellness.selfwize.com → fasten-service                             │    │
│  │    Host: home.selfwize.com     → home-selfwize-service                      │    │
│  │    Host: cameras.selfwize.com  → blueiris-service                           │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
└───────┬─────────────┬─────────────┬─────────────┬─────────────┬─────────────┬───────┘
        │             │             │             │             │             │
        ▼             ▼             ▼             ▼             ▼             ▼
┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│  Homarr   │ │   Gatus   │ │ Snipe-IT  │ │  Fasten   │ │ Home Asst │ │ Blue Iris │
│  :7575    │ │   :8083   │ │   :8082   │ │   :9090   │ │   :8123   │ │   :443    │
│  Docker   │ │  Docker   │ │  Docker   │ │  Docker   │ │  Native   │ │  Native   │
│ internal  │ │ internal  │ │ internal  │ │ internal  │ │192.168.68 │ │192.168.68 │
└───────────┘ └───────────┘ └───────────┘ └───────────┘ └───────────┘ └───────────┘
```

## Component Details

### 1. Cloudflare Edge

**Purpose**: SSL termination, security, and authentication

| Function | Description |
|----------|-------------|
| DNS | Wildcard CNAME `*.selfwize.com` points to tunnel |
| SSL | Terminates HTTPS, presents valid certificate |
| Access | Zero Trust authentication per application |
| Security | DDoS protection, WAF, bot management |

**Configuration Location**: Cloudflare Dashboard (no local files)

### 2. Cloudflared Tunnel

**Purpose**: Secure connection between Cloudflare edge and local network

| File | Location |
|------|----------|
| Binary | `C:\Program Files (x86)\cloudflared\cloudflared.exe` |
| Config | `C:\Program Files (x86)\cloudflared\config.yml` |
| Credentials | `C:\Program Files (x86)\cloudflared\<tunnel-id>.json` |
| Service | Windows Service: `cloudflared` |

**Current Configuration**:
```yaml
tunnel: 1f014ff9-68ae-4033-bacf-e058b91d2df4
credentials-file: C:\Program Files (x86)\cloudflared\1f014ff9-68ae-4033-bacf-e058b91d2df4.json

ingress:
  - hostname: "*.selfwize.com"
    service: http://localhost:80
  - service: http_status:404
```

**Key Points**:
- All `*.selfwize.com` traffic routes to `localhost:80` (Traefik)
- Tunnel receives encrypted traffic from Cloudflare
- Forwards plain HTTP to Traefik (SSL already terminated)

### 3. Traefik Reverse Proxy

**Purpose**: Route requests to correct backend service based on hostname

| File | Purpose |
|------|---------|
| `traefik/docker-compose.traefik.yml` | Container definition |
| `traefik/traefik.yml` | Static configuration |
| `traefik/dynamic/external-services.yml` | Service routes |

**Static Configuration** (`traefik.yml`):
```yaml
entryPoints:
  web:
    address: ":80"
    forwardedHeaders:
      trustedIPs: [Cloudflare IPs]  # Trust X-Forwarded-* headers

providers:
  file:
    directory: "/etc/traefik/dynamic"
    watch: true  # Auto-reload on changes
```

**Dynamic Configuration** (`external-services.yml`):
```yaml
http:
  routers:
    <service>-router:
      rule: "Host(`<subdomain>.selfwize.com`)"
      entryPoints: [web]
      service: <service>-service
      middlewares: [cloudflare-headers]

  services:
    <service>-service:
      loadBalancer:
        servers:
          - url: "http://<target>:<port>"
```

**Network Connectivity**:

| Service Type | URL Pattern | Example |
|--------------|-------------|---------|
| Docker container | `http://host.docker.internal:<port>` | `http://host.docker.internal:7575` |
| External host | `http://<ip>:<port>` | `http://192.168.68.68:8123` |
| HTTPS with self-signed | Add `serversTransport: selfsigned-transport` | Fasten, Blue Iris |

### 4. Backend Services

| Service | Container | Port | Network Access |
|---------|-----------|------|----------------|
| Homarr | `homarr` | 7575 | `host.docker.internal:7575` |
| Gatus | `ra-status` | 8083 | `host.docker.internal:8083` |
| Snipe-IT | `snipeit-app` | 8082 | `host.docker.internal:8082` |
| Fasten | `fasten-deploy-fasten-prod-1` | 9090 | `host.docker.internal:9090` (HTTPS) |
| Home Assistant | Home Assistant OS | 8123 | `192.168.68.68:8123` |
| Blue Iris | Native Windows | 443 | `192.168.68.56:443` (HTTPS) |

## Request Flow Example

**User requests**: `https://stuff.selfwize.com/hardware`

```
1. Browser → DNS lookup → *.selfwize.com → Cloudflare
2. Cloudflare → SSL termination → Cloudflare Access check
3. Cloudflare → Tunnel → cloudflared service (localhost)
4. cloudflared → HTTP request to localhost:80
5. Traefik receives: Host: stuff.selfwize.com, Path: /hardware
6. Traefik matches: snipeit-router (rule: Host(`stuff.selfwize.com`))
7. Traefik forwards to: http://host.docker.internal:8082/hardware
8. Snipe-IT processes request → Response
9. Response flows back through entire chain
```

## Configuration File Map

```
ra-infrastructure/
├── traefik/
│   ├── docker-compose.traefik.yml    # Traefik container
│   ├── traefik.yml                   # Static config (entry points, providers)
│   └── dynamic/
│       └── external-services.yml     # All service routes (auto-reloads)
├── homarr/
│   ├── docker-compose.homarr.yml     # Dashboard container
│   └── .env                          # SECRET_ENCRYPTION_KEY
├── gatus/
│   ├── docker-compose.gatus.yml      # Monitoring container
│   └── config/gatus.yaml             # Endpoint definitions
├── config/
│   └── cloudflared-config.template.yml  # Reference only (actual in Program Files)
└── docker/
    └── docker-compose.yml            # Core infrastructure (PostgreSQL, etc.)
```

## Adding New Services

### Option A: Docker Container (Recommended)

Add Traefik labels to your docker-compose.yml:

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

**Note**: Docker label-based routing requires Docker provider enabled in Traefik. Currently disabled on Windows due to named pipe limitation. Use Option B instead.

### Option B: File-Based Configuration

Edit `traefik/dynamic/external-services.yml`:

```yaml
http:
  routers:
    myapp-router:
      rule: "Host(`myapp.selfwize.com`)"
      entryPoints:
        - web
      service: myapp-service
      middlewares:
        - cloudflare-headers

  services:
    myapp-service:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:8080"
```

For HTTPS backends with self-signed certificates:
```yaml
    myapp-service:
      loadBalancer:
        servers:
          - url: "https://host.docker.internal:8443"
        serversTransport: selfsigned-transport
```

**No restart required** - Traefik watches the file and auto-reloads.

### Option C: External Non-Docker Service

Same as Option B, but use actual IP instead of `host.docker.internal`:

```yaml
    myapp-service:
      loadBalancer:
        servers:
          - url: "http://192.168.68.100:3000"
```

## Monitoring Integration

Gatus monitors all services at two levels:

| Level | URL Pattern | Purpose |
|-------|-------------|---------|
| External | `https://<subdomain>.selfwize.com` | End-to-end through Cloudflare |
| Internal | `http://<ip>:<port>` or `http://host.docker.internal:<port>` | Direct backend health |

Configuration: `gatus/config/gatus.yaml`

## Troubleshooting

### Debug Checklist

1. **Cloudflare**: Check tunnel status in Zero Trust dashboard
2. **Tunnel**: `Get-Service cloudflared` - ensure running
3. **Traefik**: `docker logs traefik` - check for routing errors
4. **Backend**: `curl http://localhost:<port>` - verify service responds

### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| 502 Bad Gateway | Traefik can't reach backend | Check backend is running, verify URL in external-services.yml |
| 404 Not Found | No matching route | Check Host header matches rule in Traefik |
| Connection refused | Service down or wrong port | Verify container is running, check port mapping |
| SSL error on backend | Self-signed cert not trusted | Add `serversTransport: selfsigned-transport` |

### Useful Commands

```powershell
# Check all running containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View Traefik routes
curl http://localhost:8080/api/http/routers | python -m json.tool

# Test routing locally
curl -H "Host: myapp.selfwize.com" http://localhost:80

# Check tunnel status
Get-Service cloudflared

# Restart Traefik (picks up config changes)
docker restart traefik

# View Traefik access logs
docker logs traefik -f
```

## Security Considerations

1. **SSL Termination**: Happens at Cloudflare edge. Traffic between Cloudflare and tunnel is encrypted. Traffic from tunnel to Traefik is plain HTTP on localhost.

2. **Authentication**: Handled by Cloudflare Access at the edge. Backend services may have their own auth (e.g., Snipe-IT login).

3. **Network Isolation**: Docker containers on `inventory_network`. External services on separate IP (192.168.68.56).

4. **Secrets**:
   - Tunnel credentials in `C:\Program Files (x86)\cloudflared\`
   - Service secrets in respective `.env` files (gitignored)

## Related Documentation

- [TRAEFIK-SETUP.md](../guides/TRAEFIK-SETUP.md) - Step-by-step setup guide
- [PRD-008-reverse-proxy-infrastructure.md](../prds/PRD-008-reverse-proxy-infrastructure.md) - Requirements and design
- [CLOUDFLARE-TUNNEL-SETUP.md](../guides/CLOUDFLARE-TUNNEL-SETUP.md) - Tunnel configuration
- [GATUS-E2E-TEST-PLAN.md](../guides/GATUS-E2E-TEST-PLAN.md) - Monitoring test plan
