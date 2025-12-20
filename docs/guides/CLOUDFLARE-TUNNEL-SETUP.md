# Cloudflare Tunnel Setup Guide

Set up Cloudflare DNS for selfwize.com with subdomain routing to dev PC via Cloudflare Tunnel.

## Overview

**Domain:** `selfwize.com` (registered on Namecheap)
**DNS Provider:** Cloudflare
**Purpose:** POC for personal information portal with subdomain-based routing

```
Internet → stuff.selfwize.com    → Cloudflare → Tunnel → localhost:3001
         → wellness.selfwize.com →                     → localhost:3002
         → app.selfwize.com      →                     → localhost:3000
         → api.selfwize.com      →                     → localhost:8080
```

**Subdomain Structure:**
| Subdomain | Purpose | Local Target |
|-----------|---------|--------------|
| `stuff.selfwize.com` | IT/Asset Inventory | `localhost:3001` |
| `wellness.selfwize.com` | Medical/Health Records | `localhost:3002` |
| `app.selfwize.com` | Main Dashboard (future) | `localhost:3000` |
| `api.selfwize.com` | API endpoint (future) | `localhost:8080` |

---

## Phase 1: Add Domain to Cloudflare

### Step 1.1: Add Site in Cloudflare Dashboard

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click **"Add a site"** (or **"Add site"** button)
3. Enter: `selfwize.com`
4. Click **Continue**
5. Select **Free** plan → Click **Continue**
6. Cloudflare will scan for existing DNS records → Click **Continue**

### Step 1.2: Note Your Cloudflare Nameservers

Cloudflare will display two nameservers. For selfwize.com:
```
arushi.ns.cloudflare.com
thomas.ns.cloudflare.com
```

**Copy these down** - needed for Namecheap.

---

## Phase 2: Update Nameservers at Namecheap

### Step 2.1: Log into Namecheap

1. Go to [Namecheap Dashboard](https://ap.www.namecheap.com)
2. Click **Domain List** in the left sidebar
3. Find `selfwize.com` → Click **Manage**

### Step 2.2: Change Nameservers

1. Scroll to **NAMESERVERS** section
2. Change dropdown from **"Namecheap BasicDNS"** to **"Custom DNS"**
3. Enter the Cloudflare nameservers:
   ```
   Nameserver 1: arushi.ns.cloudflare.com
   Nameserver 2: thomas.ns.cloudflare.com
   ```
4. Click the **green checkmark** to save

### Step 2.3: Wait for Propagation

- Usually takes 10 minutes to a few hours
- Can take up to 24-48 hours in rare cases

### Step 2.4: Verify Domain is Active

1. Go back to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click on `selfwize.com`
3. Check the **Overview** page
4. Status should change from **"Pending"** to **"Active"**

Verification command:
```powershell
nslookup -type=NS selfwize.com
# Should return Cloudflare nameservers when complete
```

---

## Phase 3: Install Cloudflared

Run in PowerShell as Administrator:

```powershell
winget install Cloudflare.cloudflared
```

Verify installation:
```powershell
cloudflared --version
```

---

## Phase 4: Authenticate with Cloudflare

```powershell
cloudflared tunnel login
```

This opens a browser to authorize. Select `selfwize.com` when prompted.

**Result:** Creates credentials at `~/.cloudflared/cert.pem`

**Secure Storage Note:** The `cert.pem` file is your account credential. Keep it secure and never commit to version control.

---

## Phase 5: Create the Tunnel

```powershell
# Create tunnel named "selfwize-dev"
cloudflared tunnel create selfwize-dev
```

**Result:**
- Creates tunnel with a UUID (e.g., `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
- Creates credentials file: `~/.cloudflared/<TUNNEL-UUID>.json`

**Important:** Note the tunnel UUID - you'll need it for configuration.

**Secure Storage Note:** The `<TUNNEL-UUID>.json` file contains tunnel credentials. Store securely.

---

## Phase 6: Configure the Tunnel

### 6.1 Create Configuration File

Create/edit `C:\Users\ranand\.cloudflared\config.yml`:

```yaml
# Cloudflare Tunnel Configuration for selfwize-dev
# Personal Information Portal POC
#
# Replace <TUNNEL-UUID> with your actual tunnel ID from Phase 5

tunnel: <TUNNEL-UUID>
credentials-file: C:\Users\ranand\.cloudflared\<TUNNEL-UUID>.json

ingress:
  # IT/Asset Inventory (Snipe-IT, etc.)
  - hostname: stuff.selfwize.com
    service: http://localhost:3001
    originRequest:
      noTLSVerify: true

  # Medical/Health Records (Fasten Health, etc.)
  - hostname: wellness.selfwize.com
    service: http://localhost:3002
    originRequest:
      noTLSVerify: true

  # Main Dashboard (future)
  - hostname: app.selfwize.com
    service: http://localhost:3000
    originRequest:
      noTLSVerify: true

  # API Endpoint (future)
  - hostname: api.selfwize.com
    service: http://localhost:8080
    originRequest:
      noTLSVerify: true

  # Catch-all rule (required - must be last)
  - service: http_status:404
```

### 6.2 Create DNS Records

Create CNAME records pointing to the tunnel for each subdomain:

```powershell
cloudflared tunnel route dns selfwize-dev stuff.selfwize.com
cloudflared tunnel route dns selfwize-dev wellness.selfwize.com
cloudflared tunnel route dns selfwize-dev app.selfwize.com
cloudflared tunnel route dns selfwize-dev api.selfwize.com
```

This creates CNAME records in Cloudflare DNS pointing to your tunnel.

---

## Phase 7: Test the Tunnel

### 7.1 Validate Configuration

```powershell
cloudflared tunnel ingress validate
```

### 7.2 Run Tunnel Manually

```powershell
# Start tunnel (Ctrl+C to stop)
cloudflared tunnel run selfwize-dev
```

### 7.3 Verify Access

Open each URL in a browser to verify they route correctly:
- https://stuff.selfwize.com
- https://wellness.selfwize.com
- https://app.selfwize.com
- https://api.selfwize.com

**Note:** The local services must be running on their respective ports for this to work.

---

## Phase 8: Install as Windows Service (Optional)

For automatic startup on boot. **Note:** The default service install has a bug where it doesn't use your config file. Use the setup script or manual steps below.

### Option A: Use Setup Script (Recommended)

Run as Administrator:
```powershell
& "C:\Users\ranand\workspace\personal\software\ra-infrastructure\scripts\setup-cloudflared-service.ps1"
```

### Option B: Manual Installation

Run as Administrator:

```powershell
# 1. Copy config to Program Files
Copy-Item "$env:USERPROFILE\.cloudflared\config.yml" "C:\Program Files (x86)\cloudflared\" -Force
Copy-Item "$env:USERPROFILE\.cloudflared\<TUNNEL-UUID>.json" "C:\Program Files (x86)\cloudflared\" -Force

# 2. Update config to use new credentials path
# Edit C:\Program Files (x86)\cloudflared\config.yml
# Change: credentials-file: C:\Program Files (x86)\cloudflared\<TUNNEL-UUID>.json

# 3. Install service
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" service install

# 4. Fix registry to use config file (IMPORTANT!)
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared"
Set-ItemProperty $regPath -Name ImagePath -Value '"C:\Program Files (x86)\cloudflared\cloudflared.exe" --config "C:\Program Files (x86)\cloudflared\config.yml" tunnel run'

# 5. Start service
Start-Service cloudflared
Get-Service cloudflared
```

### Why the Registry Fix?

The `cloudflared service install` command ignores the `--config` flag. The service runs as SYSTEM and can't access user directories. The registry fix ensures the service uses the correct config file.

---

## Start/Stop Instructions

### Manual Operation (No Service)

```powershell
# Start tunnel
cloudflared tunnel run selfwize-dev

# Stop tunnel
# Press Ctrl+C in the terminal running the tunnel
```

### Service Operation (After Phase 8)

```powershell
# Start tunnel
Start-Service cloudflared

# Stop tunnel
Stop-Service cloudflared

# Restart tunnel
Restart-Service cloudflared

# Check status
Get-Service cloudflared
```

### View Logs

```powershell
# If running as service
Get-WinEvent -LogName Application -FilterXPath "*[System[Provider[@Name='cloudflared']]]" -MaxEvents 50

# If running manually, logs appear in the terminal
```

---

## Phase 9: Set Up Cloudflare Access (Authentication)

Protect your services with Zero Trust authentication.

### 9.1 Enable Zero Trust

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. Create a team name (e.g., `selfwize`)
3. Select **Free** plan (up to 50 users)

### 9.2 Create Access Application

For each subdomain that needs protection:

1. Go to **Access** → **Applications** → **Add an application**
2. Select **Self-hosted**
3. Configure:
   - **Name:** (e.g., "Wellness Portal")
   - **Session Duration:** 24 hours
   - **Application domain:** (e.g., `wellness.selfwize.com`)
4. Add Policy:
   - **Name:** Allow Owner
   - **Action:** Allow
   - **Include:** Specific email addresses
5. Save

**Recommendation:** Use stricter policies (specific email allowlist) for sensitive services like `wellness.selfwize.com`.

### 9.3 Test Authentication

1. Open the protected URL in incognito mode
2. You should see Cloudflare Access login page
3. Enter your email → receive code → verify
4. Access granted!

---

## Troubleshooting

### Windows Service Won't Start

The most common issue. The service runs as SYSTEM and can't find the config.

```powershell
# Check if tunnel has active connections
cloudflared tunnel info selfwize-dev

# If "does not have any active connection", fix the registry:
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared"
$current = (Get-ItemProperty $regPath).ImagePath
Write-Host "Current ImagePath: $current"

# Should include --config flag. If not, fix it:
Set-ItemProperty $regPath -Name ImagePath -Value '"C:\Program Files (x86)\cloudflared\cloudflared.exe" --config "C:\Program Files (x86)\cloudflared\config.yml" tunnel run'

Restart-Service cloudflared
```

### Tunnel Not Connecting

```powershell
# Check tunnel status
cloudflared tunnel info selfwize-dev

# View service status (if installed as service)
Get-Service cloudflared

# Run with debug logging
cloudflared tunnel run selfwize-dev --loglevel debug
```

### DNS Not Resolving

```powershell
# Verify CNAME records exist
nslookup stuff.selfwize.com

# Should return something like:
# stuff.selfwize.com -> <tunnel-id>.cfargotunnel.com
```

### Service Unreachable (502 Error)

```powershell
# Verify local service is running on expected port
curl http://localhost:3001

# Check if port is listening
netstat -an | findstr "3001"
```

### Reset and Start Over

```powershell
# Remove service (if installed)
cloudflared service uninstall

# Delete tunnel
cloudflared tunnel delete selfwize-dev

# Remove config
Remove-Item ~/.cloudflared/config.yml

# Start fresh from Phase 4
```

---

## Quick Reference

### Files and Credentials

| File | Purpose | Security |
|------|---------|----------|
| `~/.cloudflared/cert.pem` | Account credentials (from `tunnel login`) | Keep secure, never commit |
| `~/.cloudflared/<UUID>.json` | Tunnel credentials | Keep secure, never commit |
| `~/.cloudflared/config.yml` | Tunnel routing configuration | Can commit (no secrets) |

### Commands

```powershell
# List tunnels
cloudflared tunnel list

# Tunnel info
cloudflared tunnel info selfwize-dev

# Run manually
cloudflared tunnel run selfwize-dev

# Validate config
cloudflared tunnel ingress validate

# Add DNS route
cloudflared tunnel route dns selfwize-dev <subdomain>.selfwize.com
```

### Service Commands

```powershell
Start-Service cloudflared
Stop-Service cloudflared
Restart-Service cloudflared
Get-Service cloudflared
```

---

## Security Notes

1. **Never commit credentials** - `.cloudflared/cert.pem` and `*.json` contain secrets
2. **Use Cloudflare Access** - Don't rely solely on application authentication
3. **Protect health data** - Use strict email allowlist for `wellness.selfwize.com`
4. **Review access logs** - Zero Trust dashboard shows all access attempts
5. **Keep cloudflared updated** - `winget upgrade Cloudflare.cloudflared`
6. **SSL is automatic** - Cloudflare provides free SSL certificates for all subdomains
