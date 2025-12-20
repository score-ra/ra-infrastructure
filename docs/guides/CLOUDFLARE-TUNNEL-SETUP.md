# Cloudflare Tunnel Setup Guide

Expose local services to the internet securely using Cloudflare Tunnel.

## Overview

**Domain:** `selfwize.com`

```
Internet → snipe.ra.selfwize.com → Cloudflare → Tunnel → 192.168.68.56:8082
         → fasten.ra.selfwize.com →                    → 192.168.68.56:9090
```

**Multi-tenant subdomain structure:**
```
                    selfwize.com
                         │
        ┌────────────────┼────────────────┐
        │                │                │
      ra.            smith.           acme.
        │                │                │
   ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
   │         │      │         │      │         │
snipe.   fasten.  snipe.   fasten.  snipe.   fasten.
```

**Services to expose:**
| Service | Local URL | Public URL |
|---------|-----------|------------|
| Snipe-IT | http://192.168.68.56:8082 | snipe.ra.selfwize.com |
| Fasten Health | http://192.168.68.56:9090 | fasten.ra.selfwize.com |

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

Cloudflare will display two nameservers like:
```
ada.ns.cloudflare.com
bob.ns.cloudflare.com
```
(Your actual names will differ)

**Copy these down** - needed for Namecheap.

---

## Phase 1B: Update Nameservers at Namecheap

### Step 1.3: Log into Namecheap

1. Go to [Namecheap Dashboard](https://ap.www.namecheap.com)
2. Click **Domain List** in the left sidebar
3. Find `selfwize.com` → Click **Manage**

### Step 1.4: Change Nameservers

1. Scroll to **NAMESERVERS** section
2. Change dropdown from **"Namecheap BasicDNS"** to **"Custom DNS"**
3. Enter the Cloudflare nameservers:
   ```
   Nameserver 1: ada.ns.cloudflare.com
   Nameserver 2: bob.ns.cloudflare.com
   ```
   (Use YOUR actual nameservers from Cloudflare)
4. Click the **green checkmark** to save

### Step 1.5: Wait for Propagation

- Usually takes 10 minutes to a few hours
- Can take up to 24-48 hours in rare cases

### Step 1.6: Verify Domain is Active

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

## Phase 2: Install Cloudflared (Run Script)

Run this in PowerShell as Administrator:

```powershell
# Run the installation script
C:\Users\ranand\workspace\personal\software\ra-infrastructure\scripts\install-cloudflared.ps1
```

Or manually:
```powershell
winget install Cloudflare.cloudflared
```

Verify installation:
```powershell
cloudflared --version
```

---

## Phase 3: Authenticate with Cloudflare

```powershell
cloudflared tunnel login
```

This opens a browser to authorize. Select your domain when prompted.

**Result:** Creates credentials at `~/.cloudflared/cert.pem`

---

## Phase 4: Create the Tunnel

```powershell
# Create tunnel named "ra-services"
cloudflared tunnel create ra-services
```

**Result:**
- Creates tunnel with a UUID (e.g., `a1b2c3d4-...`)
- Creates credentials file: `~/.cloudflared/<TUNNEL-UUID>.json`

Note the tunnel UUID - you'll need it for configuration.

---

## Phase 5: Configure the Tunnel

### 5.1 Create Configuration File

Edit `C:\Users\ranand\.cloudflared\config.yml`:

```yaml
# Cloudflare Tunnel Configuration
# Replace <TUNNEL-UUID> with your actual tunnel ID

tunnel: <TUNNEL-UUID>
credentials-file: C:\Users\ranand\.cloudflared\<TUNNEL-UUID>.json

ingress:
  # Snipe-IT Asset Management
  - hostname: snipe.ra.selfwize.com
    service: http://192.168.68.56:8082
    originRequest:
      noTLSVerify: true

  # Fasten Health
  - hostname: fasten.ra.selfwize.com
    service: http://192.168.68.56:9090
    originRequest:
      noTLSVerify: true

  # Catch-all (required)
  - service: http_status:404
```

### 5.2 Create DNS Records

```powershell
cloudflared tunnel route dns ra-services snipe.ra.selfwize.com
cloudflared tunnel route dns ra-services fasten.ra.selfwize.com
```

This creates CNAME records pointing to your tunnel.

---

## Phase 6: Test the Tunnel

```powershell
# Validate configuration
cloudflared tunnel ingress validate

# Test run (Ctrl+C to stop)
cloudflared tunnel run ra-services
```

Visit your URLs in a browser to verify they work.

---

## Phase 7: Install as Windows Service

Run as Administrator:

```powershell
# Install the service
cloudflared service install

# Verify service is running
Get-Service cloudflared
```

The tunnel now starts automatically on boot.

### Service Management

```powershell
# Stop service
Stop-Service cloudflared

# Start service
Start-Service cloudflared

# Restart service
Restart-Service cloudflared

# View logs
Get-WinEvent -LogName Application -FilterXPath "*[System[Provider[@Name='cloudflared']]]" -MaxEvents 50
```

---

## Phase 8: Set Up Cloudflare Access (Authentication)

Protect your services with authentication.

### 8.1 Enable Zero Trust

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. Create a team name (e.g., `anand-home`)
3. Select **Free** plan (up to 50 users)

### 8.2 Create Access Application for Snipe-IT

1. Go to **Access** → **Applications** → **Add an application**
2. Select **Self-hosted**
3. Configure:
   - **Name:** Snipe-IT
   - **Session Duration:** 24 hours
   - **Application domain:** `snipe.ra.selfwize.com`
4. Add Policy:
   - **Name:** Allow Family
   - **Action:** Allow
   - **Include:** Emails ending in `@gmail.com` (or specific emails)
5. Save

### 8.3 Create Access Application for Fasten Health

Repeat for Fasten:
- **Name:** Fasten Health
- **Application domain:** `fasten.ra.selfwize.com`
- Use stricter policy (specific email addresses only recommended for health data)

### 8.4 Test Authentication

1. Open `snipe.ra.selfwize.com` in incognito
2. You should see Cloudflare Access login page
3. Enter your email → receive code → verify
4. Access granted!

---

## Troubleshooting

### Tunnel Not Connecting

```powershell
# Check tunnel status
cloudflared tunnel info ra-services

# View service status
Get-Service cloudflared

# Check logs
cloudflared tunnel run ra-services --loglevel debug
```

### DNS Not Resolving

```powershell
# Verify CNAME records exist
nslookup snipe.ra.selfwize.com

# Should return something like:
# snipe.ra.selfwize.com -> <tunnel-id>.cfargotunnel.com
```

### Service Unreachable

```powershell
# Verify local service is running
curl http://192.168.68.56:8082

# Check Docker containers
docker ps
```

### Reset and Start Over

```powershell
# Remove service
cloudflared service uninstall

# Delete tunnel
cloudflared tunnel delete ra-services

# Remove config
Remove-Item ~/.cloudflared/config.yml
```

---

## Quick Reference

### Files

| File | Purpose |
|------|---------|
| `~/.cloudflared/cert.pem` | Account credentials (from `tunnel login`) |
| `~/.cloudflared/<UUID>.json` | Tunnel credentials |
| `~/.cloudflared/config.yml` | Tunnel routing configuration |

### Commands

```powershell
# List tunnels
cloudflared tunnel list

# Tunnel info
cloudflared tunnel info ra-services

# Run manually
cloudflared tunnel run ra-services

# Service control
Start-Service cloudflared
Stop-Service cloudflared
Restart-Service cloudflared
```

---

## Security Notes

1. **Never commit credentials** - `.cloudflared/` contains secrets
2. **Use Cloudflare Access** - Don't rely solely on app authentication
3. **Review access logs** - Zero Trust dashboard shows all access attempts
4. **Restrict health data** - Use email allowlist for Fasten Health
5. **Keep cloudflared updated** - `winget upgrade Cloudflare.cloudflared`
