# Cloudflare Tunnel Setup Checklist

**Purpose:** Step-by-step checklist for setting up Cloudflare Tunnel for a new organization.
**Audience:** AI agents or developers setting up tunnels.
**Time:** ~30 minutes if everything goes smoothly.

---

## Pre-Flight Checklist

Before starting, gather this information:

| Item | Example | Your Value |
|------|---------|------------|
| Domain name | `example.com` | |
| Domain registrar | Namecheap, GoDaddy, etc. | |
| Subdomains needed | stuff, api, app | |
| Target PC OS | Windows 11 | |

**For each service you want to expose:**

| Service | Container Name | Host Port | Protocol | Needs noTLSVerify? |
|---------|---------------|-----------|----------|-------------------|
| Snipe-IT | snipeit-app | 8082 | HTTP | No |
| Fasten Health | fasten-prod | 9090 | HTTPS | Yes (self-signed) |

### How to Find Your Service Ports

```powershell
# List all running Docker containers with their port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Example output:
# NAMES          PORTS
# snipeit-app    0.0.0.0:8082->80/tcp    <- Use port 8082
# fasten-prod    0.0.0.0:9090->8080/tcp  <- Use port 9090
```

### How to Determine HTTP vs HTTPS

```powershell
# Test with HTTP first
curl.exe -v --max-time 5 http://localhost:8082

# If you see "Client sent an HTTP request to an HTTPS server", use HTTPS:
curl.exe -vk --max-time 5 https://localhost:9090
```

---

## Phase 1: Cloudflare Setup (5 min)

### 1.1 Add Domain to Cloudflare

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **Add a site**
3. Enter your domain → Select **Free** plan → Continue
4. **Copy the two nameservers** (e.g., `arushi.ns.cloudflare.com`, `thomas.ns.cloudflare.com`)

### 1.2 Update Nameservers at Registrar

At your domain registrar (Namecheap, GoDaddy, etc.):
1. Find DNS/Nameserver settings
2. Change to **Custom DNS**
3. Enter the two Cloudflare nameservers
4. Save

### 1.3 Wait for Activation

- Usually 10-30 minutes
- Check Cloudflare dashboard - status changes from "Pending" to "Active"
- Verify: `nslookup -type=NS yourdomain.com`

### 1.4 Enable "Always Use HTTPS"

1. In Cloudflare → SSL/TLS → Edge Certificates
2. Enable **Always Use HTTPS**
3. Enable **Automatic HTTPS Rewrites**

---

## Phase 2: Install Cloudflared (5 min)

Run as Administrator:

```powershell
# Install
winget install Cloudflare.cloudflared

# Verify
cloudflared --version
```

---

## Phase 3: Create Tunnel (5 min)

```powershell
# Login (opens browser)
cloudflared tunnel login
# Select your domain when prompted

# Create tunnel
cloudflared tunnel create <tunnel-name>
# Example: cloudflared tunnel create myorg-dev

# Note the UUID from output - you'll need it!
# Example: Created tunnel myorg-dev with id a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

---

## Phase 4: Configure Tunnel (10 min)

### 4.1 Create DNS Routes

```powershell
cloudflared tunnel route dns <tunnel-name> subdomain1.yourdomain.com
cloudflared tunnel route dns <tunnel-name> subdomain2.yourdomain.com
# Repeat for each subdomain
```

### 4.2 Create Config File

Create `C:\Users\<username>\.cloudflared\config.yml`:

```yaml
tunnel: <TUNNEL-UUID>
credentials-file: C:\Users\<username>\.cloudflared\<TUNNEL-UUID>.json

ingress:
  # HTTP service (most common)
  - hostname: stuff.yourdomain.com
    service: http://localhost:8082

  # HTTPS service with self-signed cert
  - hostname: wellness.yourdomain.com
    service: https://localhost:9090
    originRequest:
      noTLSVerify: true

  # Catch-all (required, must be last)
  - service: http_status:404
```

### 4.3 Validate Config

```powershell
cloudflared tunnel ingress validate
```

---

## Phase 5: Test Manually First (5 min)

**IMPORTANT:** Always test manually before installing as a service!

```powershell
# Start tunnel manually
cloudflared tunnel run <tunnel-name>

# In another terminal, test each service:
curl.exe -sI https://stuff.yourdomain.com
curl.exe -sI https://wellness.yourdomain.com
```

**Expected responses:**
- `HTTP/1.1 200 OK` or `HTTP/1.1 302 Found` = Working
- `HTTP/1.1 502 Bad Gateway` = Service not running locally
- `HTTP/1.1 524` = Wrong port or service not responding (see troubleshooting)

---

## Phase 6: Install as Windows Service (5 min)

Run as Administrator:

```powershell
# 1. Copy files to Program Files
$tunnelId = "<TUNNEL-UUID>"
Copy-Item "$env:USERPROFILE\.cloudflared\config.yml" "C:\Program Files (x86)\cloudflared\" -Force
Copy-Item "$env:USERPROFILE\.cloudflared\$tunnelId.json" "C:\Program Files (x86)\cloudflared\" -Force

# 2. Update config to use new path
# Edit C:\Program Files (x86)\cloudflared\config.yml
# Change credentials-file to: C:\Program Files (x86)\cloudflared\<TUNNEL-UUID>.json

# 3. Install service
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" service install

# 4. CRITICAL: Fix registry (service ignores --config flag by default)
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared"
Set-ItemProperty $regPath -Name ImagePath -Value '"C:\Program Files (x86)\cloudflared\cloudflared.exe" --config "C:\Program Files (x86)\cloudflared\config.yml" tunnel run'

# 5. Start service
Start-Service cloudflared
Get-Service cloudflared
```

---

## Phase 7: Configure Backend Apps

**CRITICAL:** Backend apps must be configured with the public URL, not internal IP!

### Snipe-IT

Edit the docker-compose `.env` file:
```
APP_URL=https://stuff.yourdomain.com
```

Then recreate container:
```powershell
docker-compose up -d --force-recreate snipeit
docker exec snipeit-app php artisan config:clear
docker exec snipeit-app php artisan cache:clear
```

### Fasten Health

Fasten typically doesn't need URL configuration, but uses HTTPS with self-signed cert - hence `noTLSVerify: true` in tunnel config.

### Other Laravel Apps

Same pattern as Snipe-IT - update `APP_URL` in `.env` and recreate container.

---

## Verification Checklist

Run these checks after setup:

```powershell
# 1. Service running?
Get-Service cloudflared

# 2. Tunnel connected?
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info <tunnel-name>
# Should show active connections

# 3. Sites accessible?
curl.exe -sI https://stuff.yourdomain.com
# Should return 200 or 302

# 4. Redirects correct? (not internal IP)
curl.exe -sI https://stuff.yourdomain.com 2>&1 | Select-String "location"
# Should show https://stuff.yourdomain.com/... NOT https://192.168.x.x/...
```

---

## Troubleshooting Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| 524 Timeout | Wrong port or non-HTTP service on port | Check `docker ps`, find correct port |
| 502 Bad Gateway | Nothing listening on port | Start the backend service |
| Redirect to internal IP | App configured with internal URL | Update APP_URL, recreate container |
| "HTTP to HTTPS server" | Backend needs HTTPS | Use `https://` + `noTLSVerify: true` |
| Service won't start | Registry missing config path | Run registry fix command |

### Diagnostic Commands

```powershell
# What's on a port?
Get-NetTCPConnection -LocalPort 8082 | Select-Object OwningProcess
Get-Process -Id <PID> | Select-Object ProcessName

# Test local service
curl.exe -v --max-time 5 http://localhost:8082

# Tunnel logs (manual run)
cloudflared tunnel run <tunnel-name> --loglevel debug
```

---

## Files Reference

| File | Location | Purpose |
|------|----------|---------|
| Account cert | `~/.cloudflared/cert.pem` | Cloudflare account auth |
| Tunnel creds | `~/.cloudflared/<UUID>.json` | Tunnel authentication |
| User config | `~/.cloudflared/config.yml` | Tunnel routing (user) |
| Service config | `C:\Program Files (x86)\cloudflared\config.yml` | Tunnel routing (service) |
| Service creds | `C:\Program Files (x86)\cloudflared\<UUID>.json` | Service tunnel auth |

---

## Service Management

```powershell
Start-Service cloudflared
Stop-Service cloudflared
Restart-Service cloudflared
Get-Service cloudflared
```

---

## Key Lessons Learned

1. **Always check actual ports** - Don't assume. Run `docker ps` to see real port mappings.

2. **Test locally first** - Before blaming the tunnel, verify `curl.exe http://localhost:PORT` works.

3. **HTTP vs HTTPS matters** - Some apps (Fasten) require HTTPS. You'll get "HTTP request to HTTPS server" error if wrong.

4. **noTLSVerify only for HTTPS** - Only needed when backend uses HTTPS with self-signed certs.

5. **APP_URL must match public domain** - Apps like Snipe-IT redirect based on their configured URL. Update it to match the public domain.

6. **Recreate, don't restart** - When changing Docker env vars, use `docker-compose up -d --force-recreate`, not `docker restart`.

7. **Registry fix is mandatory** - Windows cloudflared service ignores the `--config` flag. Always apply the registry fix.

8. **524 ≠ 502** - 524 means something accepts connection but doesn't respond. 502 means connection refused. Different fixes.
