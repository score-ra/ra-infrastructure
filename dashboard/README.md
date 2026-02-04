# Selfwize Dashboard

A lightweight, config-driven service launcher for the ra-infrastructure stack. Mobile-first design with dark theme.

## Quick Start

```powershell
cd dashboard
docker-compose -f docker-compose.dashboard.yml up -d
```

**Access:**
- Local: http://localhost:8088
- External: https://dash.selfwize.com (via Cloudflare Tunnel)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Browser                                                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  index.html + styles.css + app.js                       ││
│  │         │                                                ││
│  │         ▼                                                ││
│  │  fetch('services.json')                                  ││
│  │         │                                                ││
│  │         ▼                                                ││
│  │  Render service cards grouped by category                ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  nginx:alpine container (selfwize-dashboard)                │
│  - Serves static files                                       │
│  - Gzip compression                                          │
│  - Cache headers (1h for assets, no-cache for config)       │
│  - Port 8088                                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Traefik Reverse Proxy                                       │
│  - Routes dash.selfwize.com → localhost:8088                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Cloudflare Tunnel + Access                                  │
│  - External access with authentication                       │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Adding a New Service

Edit `services.json` to add services. No code changes required.

```json
{
    "name": "My Service",
    "description": "Optional description shown on hover",
    "url": "https://service.selfwize.com",
    "icon": "server",
    "color": "blue",
    "status": "dev"
}
```

### Service Status

The `status` field tracks service lifecycle and controls alerting behavior in Gatus:

| Status | Alerts | Description |
|--------|--------|-------------|
| `production` | Enabled | Live service, failures trigger email alerts |
| `dev` | Disabled | Development service, monitored but no alerts |
| `deprecated` | Disabled | Scheduled for removal |

**Important:** When promoting a service to production, update both:
1. `services.json` - set `"status": "production"`
2. `gatus/config/gatus.yaml` - set `enabled: true` on the alert

Current production services:
- PostgreSQL Database
- MySQL Database
- Snipe-IT (stuff.selfwize.com)
- Fasten Health (wellness.selfwize.com)

### Available Icons

| Icon Key | Emoji | Use Case |
|----------|-------|----------|
| `home` | 🏠 | Home automation |
| `camera` | 📹 | Security/cameras |
| `security` | 🔒 | Security services |
| `health` | ❤️ | Health/medical |
| `inventory` | 📦 | Asset management |
| `family` | 👨‍👩‍👧‍👦 | Family/contacts |
| `calendar` | 📅 | Events/scheduling |
| `database` | 🗄️ | Database admin |
| `server` | 🖥️ | Servers |
| `network` | 🌐 | Network services |
| `monitor` | 📈 | Monitoring |
| `proxy` | 🔀 | Proxy/routing |
| `status` | ✅ | Status pages |
| `admin` | ⚙️ | Admin tools |
| `default` | 🔗 | Fallback |

### Available Colors

| Color | CSS Variable | Hex |
|-------|--------------|-----|
| `blue` | `--color-accent-blue` | #3b82f6 |
| `green` | `--color-accent-green` | #22c55e |
| `amber` | `--color-accent-amber` | #f59e0b |
| `red` | `--color-accent-red` | #ef4444 |
| `purple` | `--color-accent-purple` | #a855f7 |
| `cyan` | `--color-accent-cyan` | #06b6d4 |
| `pink` | `--color-accent-pink` | #ec4899 |
| `orange` | `--color-accent-orange` | #f97316 |

### Service Groups

Services are organized into collapsible groups:

```json
{
    "groups": [
        {
            "id": "home",
            "name": "Home",
            "icon": "home",
            "services": [...]
        }
    ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier (used for localStorage) |
| `name` | Yes | Display name in header |
| `icon` | No | Icon key for group header |
| `services` | Yes | Array of service objects |

## File Structure

```
dashboard/
├── index.html              # Main HTML (minimal, semantic)
├── styles.css              # Dark theme styles (CSS variables)
├── app.js                  # Config loading & rendering
├── services.json           # Service definitions (edit this!)
├── nginx.conf              # Server config
├── docker-compose.dashboard.yml
└── README.md               # This file
```

## Customization

### Theming

All colors are defined as CSS custom properties in `styles.css`:

```css
:root {
    --color-bg-primary: #0f0f14;
    --color-bg-secondary: #16161d;
    --color-accent-blue: #3b82f6;
    /* ... */
}
```

### Adding Custom Icons

Edit the `ICONS` object in `app.js`:

```javascript
const ICONS = {
    'my-icon': '🎯',
    // ...
};
```

### Mobile Responsiveness

The dashboard uses CSS Grid with `auto-fill` for responsive layouts:
- **Mobile** (<640px): ~90px cards
- **Tablet** (640-1024px): ~100px cards
- **Desktop** (>1024px): ~110px cards

Touch targets are minimum 48px for accessibility.

## Operations

### Restart Dashboard

```powershell
docker restart selfwize-dashboard
```

### View Logs

```powershell
docker logs selfwize-dashboard
```

### Update Config (Live)

Edit `services.json` - changes are picked up on page refresh (no restart needed).

### Health Check

```powershell
curl http://localhost:8088/health
# Returns: OK
```

## Comparison with Homarr

| Aspect | Selfwize Dashboard | Homarr |
|--------|-------------------|--------|
| Memory | ~32MB | ~1GB |
| Config | JSON file | Web UI |
| Add service | Edit JSON | Click through UI |
| Customization | Edit CSS/JS | Limited |
| Dependencies | nginx only | Node.js runtime |
| Startup time | <1 second | ~30 seconds |

## Troubleshooting

### Dashboard not loading

1. Check container is running: `docker ps | findstr selfwize`
2. Check logs: `docker logs selfwize-dashboard`
3. Test locally: `curl http://localhost:8088`

### Services.json changes not appearing

The config has `Cache-Control: no-cache`. Hard refresh the browser (Ctrl+Shift+R) or clear cache.

### External access not working

1. Verify Traefik route: `curl -H "Host: dash.selfwize.com" http://localhost/`
2. Check Cloudflare Tunnel status
3. Verify DNS: `nslookup dash.selfwize.com`
