# Quick Start Guide

## Prerequisites

- Docker Desktop installed and running
- Python 3.12+ installed (`C:\Program Files\Python312\`)
- GitHub CLI (`gh`) authenticated
- Sibling repos cloned: `snipeit-asset-management`, `ra-life-tracker`

## Host: Raptor (Windows 11)

- User: `ra-local` (`C:\Users\symph\`)
- Workspace: `C:\Users\symph\workspace\personal\software\ra-infrastructure`
- Connected via Tailscale (IP: `100.91.54.92`)
- SMB share to BEAST: `Z:` → `\\100.103.212.60\netshare`

## Setup

### 1. Docker PATH

Docker Desktop must be running. Add to PATH if not already:

```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Docker\Docker\resources\bin", "Machine")
```

**Note:** Remote sessions (Tailscale SSH) cannot use the Docker credential store.
Ensure `~\.docker\config.json` has `"credsStore": ""` and rename
`docker-credential-desktop.exe` / `docker-credential-wincred.exe` in
`C:\Program Files\Docker\Docker\resources\bin\` if pulls fail with
"A specified logon session does not exist".

### 2. Build Local Images

The `ra_eventlog` service uses a locally-built image:

```powershell
cd C:\Users\symph\workspace\personal\software\ra-life-tracker
docker build -t daily-event-log:latest .
```

### 3. Sibling Repo .env Files

Both sibling repos need `.env` files (not committed to git):

- `../snipeit-asset-management/.env` — APP_KEY, MySQL creds, Snipe-IT API key
- `../ra-life-tracker/.env` — PostgreSQL creds, Fasten/Gramps credentials

### 4. Start Docker Stack

```powershell
cd C:\Users\symph\workspace\personal\software\ra-infrastructure
docker compose up -d
docker compose ps
```

### 5. Install CLI

```powershell
cd cli
pip install -e ".[dev]"
```

If `pip` is not in PATH:
```powershell
& "C:\Program Files\Python312\python.exe" -m pip install -e ".[dev]"
```

### 6. Initialize Database

```powershell
inv db migrate
inv db seed
inv db health
```

### 7. Verify Services

```powershell
inv system selfcheck
```

| Service | Local URL | Expected |
|---------|-----------|----------|
| Dashboard | http://localhost:8088 | 200 |
| Snipe-IT | http://localhost:8083 | 200/302 |
| Fasten | http://localhost:9091 | 200/302 |
| Event Log | http://localhost:8089 | 200 |
| Gatus | http://localhost:8085 | 200 |
| Labels | http://localhost:8100/health | 200 |
| Traefik | http://localhost:8070 | 404 (expected) |
| PostgreSQL | `inv db health` | Healthy |

## Cloudflare Tunnel

The tunnel runs as a Windows service, routing `*.selfwize.com` → `localhost:8070` (Traefik).

- Tunnel ID: `1f014ff9-68ae-4033-bacf-e058b91d2df4`
- Config: `C:\Program Files (x86)\cloudflared\config.yml`
- Credentials: `C:\Windows\System32\config\systemprofile\.cloudflared\`

```powershell
# Check service
Get-Service cloudflared

# Restart
Stop-Process -Name "cloudflared" -Force; Start-Sleep 5; Start-Service cloudflared

# Manual test
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --config "C:\Program Files (x86)\cloudflared\config.yml" run
```

## Scheduled Tasks

Three tasks are registered:

| Task | Purpose |
|------|---------|
| `ra-infrastructure-startup` | Start Docker stack on login |
| `ra-infrastructure-backup-daily` | Daily database backups |
| `ra-infrastructure-backup-weekly` | Weekly full backups |

```powershell
Get-ScheduledTask -TaskName 'ra-infrastructure-*'
```

## CLI Commands

```powershell
inv --help                    # Show all commands
inv system selfcheck          # Comprehensive health check
inv db health                 # Database connectivity
inv db stats                  # Record counts
inv db migrate                # Run migrations
inv db seed                   # Seed data
inv device list               # List devices
inv org list                  # List organizations
```

## Troubleshooting

### Docker credential errors on remote sessions
Rename credential helpers in `C:\Program Files\Docker\Docker\resources\bin\`:
- `docker-credential-desktop.exe` → `.bak`
- `docker-credential-wincred.exe` → `.bak`

Set `"credsStore": ""` in `~\.docker\config.json`.

### Cloudflared service won't start
Check the service binary path includes tunnel arguments:
```powershell
sc.exe qc cloudflared
```
If `BINARY_PATH_NAME` is just `cloudflared.exe` without `tunnel run`, recreate the service with proper arguments.

### Snipe-IT restart loop
Check `../snipeit-asset-management/.env` has `APP_KEY=base64:...`. Recreate container after fixing:
```powershell
docker compose up -d ra_snipeit --force-recreate
```
