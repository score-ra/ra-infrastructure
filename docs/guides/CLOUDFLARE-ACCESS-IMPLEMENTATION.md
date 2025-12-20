# Cloudflare Access Implementation Guide

**Domain:** `selfwize.com`
**Tunnel:** `selfwize-dev`
**Purpose:** Protect publicly exposed services with Zero Trust authentication
**Time Required:** ~30 minutes
**Related:** [PRD-007](../prds/PRD-007-cloudflare-access-security.md)

---

## Overview

This guide implements email-based authentication for:
- **wellness.selfwize.com** → Fasten Health (personal health records) - **PRIORITY**
- **stuff.selfwize.com** → Snipe-IT (asset inventory)

After implementation, users must authenticate with an email OTP code before accessing these services.

---

## Prerequisites

- [ ] Cloudflare Tunnel is operational (`selfwize-dev`)
- [ ] Services are accessible at their public URLs
- [ ] You have admin access to Cloudflare account
- [ ] List of authorized email addresses prepared

---

## Phase 1: Enable Cloudflare Zero Trust (5 min)

### Step 1.1: Navigate to Zero Trust Dashboard

1. Open browser and go to: **https://one.dash.cloudflare.com**
2. Log in with your Cloudflare account credentials
3. You should see the Zero Trust dashboard

**Expected:** If this is your first time, you'll be prompted to create a team.

### Step 1.2: Create Team Name

1. Enter team name: **`selfwize`** (or your preferred name)
2. Click **Continue**
3. Select plan: **Free** (supports up to 50 users)
4. Click **Continue** to activate

**Verification:** You should see the Zero Trust dashboard with your team name in the top-left corner.

---

## Phase 2: Create Access Application - Wellness Portal (10 min)

### Step 2.1: Start Application Creation

1. In the left sidebar, click **Access** → **Applications**
2. Click **Add an application** button
3. Select **Self-hosted** (for applications behind Cloudflare Tunnel)
4. Click **Continue** or **Next**

### Step 2.2: Configure Application Details

Fill in the following fields:

| Field | Value | Notes |
|-------|-------|-------|
| **Application name** | `Wellness Portal` | Friendly name |
| **Session Duration** | `24 hours` | How long before re-authentication |
| **Application domain** | Click **Add domain** | |
| **Subdomain** | `wellness` | Enter subdomain only |
| **Domain** | `selfwize.com` | Select from dropdown |

**Result:** Full domain will be `wellness.selfwize.com`

### Step 2.3: Configure Application Settings (Optional)

These settings can typically be left as defaults:

- **Accept all available identity providers**: ✓ Checked (enables email OTP)
- **Enable automatic cloudflared authentication**: Leave unchecked
- **Enable App Launcher**: Optional (shows app in Zero Trust portal)
- **App Launcher visibility**: Optional

Click **Next** to proceed to policies.

### Step 2.4: Create Access Policy

1. **Policy name**: `Owner Only`
2. **Action**: Select **Allow**
3. **Session duration**: `24 hours` (matches application setting)

### Step 2.5: Configure Include Rules

This defines who can access the application:

1. Under **Configure rules**, click **Add include**
2. Select **Emails** from the dropdown
3. Enter authorized email addresses, one per line:
   ```
   your-email@example.com
   authorized-user-2@example.com
   ```
4. Click **Save**

**IMPORTANT:** Only these email addresses will be able to authenticate.

### Step 2.6: Review and Create

1. Review all settings:
   - Application domain: `wellness.selfwize.com`
   - Policy action: Allow
   - Authorized emails: Correct list
2. Click **Add application** (or **Create**)

**Verification:** You should see "Wellness Portal" in your Applications list.

---

## Phase 3: Create Access Application - Asset Inventory (10 min)

Repeat Phase 2 steps with these values:

| Field | Value |
|-------|-------|
| **Application name** | `Asset Inventory` |
| **Session Duration** | `24 hours` |
| **Subdomain** | `stuff` |
| **Domain** | `selfwize.com` |
| **Policy name** | `Authorized Users` |
| **Action** | `Allow` |
| **Include** | Same email list as Wellness Portal |

**Result:** Both applications are now protected.

---

## Phase 4: Testing & Verification (10 min)

### Test 1: Verify Access Login Page Appears

1. Open **incognito/private browsing** window
2. Navigate to: **https://wellness.selfwize.com**
3. **Expected:** You are redirected to Cloudflare Access login page
4. **Expected:** Page says "Wellness Portal" and shows email input field

**If you see Fasten Health directly:** Access is not working. Check:
- Application domain is exactly `wellness.selfwize.com`
- Policy is set to "Allow" (not "Block")
- Application is active/enabled

### Test 2: Authenticate with Authorized Email

1. Enter your authorized email address
2. Click **Send code** or **Continue**
3. **Expected:** Email sent confirmation message
4. Check your email inbox for Cloudflare Access code (6-digit code)
5. Enter the code on the verification page
6. Click **Verify** or **Continue**

**Expected:** You are redirected to Fasten Health application. ✓

### Test 3: Verify Session Persistence

1. After successful login, navigate to another page in Fasten Health
2. Close the browser window
3. Re-open browser and go to **https://wellness.selfwize.com**

**Expected:** You are NOT asked to re-authenticate (within 24 hours).

### Test 4: Test Unauthorized Email (CRITICAL)

1. Open new incognito window
2. Navigate to: **https://wellness.selfwize.com**
3. Enter an email address NOT in your allowlist
4. Request OTP code

**Expected:** Either:
- Email receives code, but after verification shows "Access Denied"
- OR: No code sent, immediate "Access Denied" message

**If unauthorized email gets access:** Your policy is misconfigured!

### Test 5: Test Asset Inventory

Repeat Tests 1-3 for **https://stuff.selfwize.com**

**Expected:** Same authentication flow, access to Snipe-IT after verification.

---

## Phase 5: Verify Access Logs (Optional)

1. In Zero Trust dashboard, go to **Logs** → **Access**
2. You should see authentication events:
   - User email
   - Application (Wellness Portal / Asset Inventory)
   - Action (Allow / Deny)
   - Timestamp

**Purpose:** Audit trail for compliance and security monitoring.

---

## Troubleshooting

### Issue 1: "Application not found" when accessing URL

**Cause:** Domain might not be exactly correct.

**Fix:**
1. Go to **Access** → **Applications**
2. Click on the application
3. Verify domain is exactly `wellness.selfwize.com` (no extra characters, no typos)
4. Save and try again

### Issue 2: Email OTP code not arriving

**Cause:** Email delivery issues or spam filtering.

**Fix:**
1. Check spam/junk folder
2. Wait 2-3 minutes (email can be delayed)
3. Request a new code
4. Try with a different email address (Gmail, Outlook)
5. Check Cloudflare status page for email delivery issues

### Issue 3: "Access Denied" even with authorized email

**Cause:** Email might not be in the Include list, or policy is set to Block.

**Fix:**
1. Go to **Access** → **Applications** → Click on application
2. Click on the policy
3. Verify **Action** is set to **Allow** (not Block)
4. Check **Include** rules - ensure email is listed exactly as entered
5. Save and try again

### Issue 4: Still seeing application directly without login page

**Possible causes:**
1. **Browser cache:** Clear cookies for the domain
2. **Existing session:** You're already authenticated (check in incognito)
3. **DNS cache:** Flush DNS cache (`ipconfig /flushdns` on Windows)
4. **Application not active:** Check application is enabled in dashboard

**Fix:**
1. Open incognito window
2. Clear all cookies for `selfwize.com`
3. Try accessing the URL again
4. If still not working, verify application status in dashboard

### Issue 5: Access works but breaks application functionality

**Cause:** Application might be making cross-origin requests or has strict referrer policies.

**Fix:**
1. Go to application settings
2. Under **CORS settings**, add application's own domain to allowed origins
3. Check application's built-in authentication settings

---

## Verification Checklist

After implementation, verify all these checkboxes:

- [ ] Wellness Portal application created in Zero Trust dashboard
- [ ] Asset Inventory application created in Zero Trust dashboard
- [ ] Both applications have correct domains (wellness.selfwize.com, stuff.selfwize.com)
- [ ] Policies are set to "Allow" with email allowlist
- [ ] Incognito test shows Cloudflare Access login page for wellness.selfwize.com
- [ ] Incognito test shows Cloudflare Access login page for stuff.selfwize.com
- [ ] Authorized email receives OTP code
- [ ] OTP code grants access to Fasten Health
- [ ] OTP code grants access to Snipe-IT
- [ ] Unauthorized email is blocked
- [ ] Session persists after browser restart (within 24h)
- [ ] Access logs show authentication events

---

## Security Best Practices

### Authorized Email Management

1. **Use personal emails only** - Don't use shared email addresses
2. **Keep list minimal** - Only add users who truly need access
3. **Review quarterly** - Remove emails for users who no longer need access
4. **Document changes** - Keep a record of who was added/removed and when

### Session Management

1. **24-hour duration is recommended** for personal use
2. Consider shorter durations (8 hours) for highly sensitive data
3. Users can manually log out from any Cloudflare Access protected app

### Monitoring

1. **Review access logs weekly** - Check for unusual access patterns
2. **Set up email notifications** (if available in your plan) for failed authentication attempts
3. **Audit authorized emails monthly** - Ensure list is current

### Incident Response

If you suspect unauthorized access:
1. Go to **Access** → **Applications**
2. Edit the affected application
3. Edit the policy → Remove suspected compromised email
4. Save immediately (takes effect within seconds)
5. Add back with a different email if needed
6. Review access logs to understand scope of access

---

## Maintenance

### Adding New Users

1. Go to **Access** → **Applications**
2. Click on the application (e.g., "Wellness Portal")
3. Click on the policy (e.g., "Owner Only")
4. Under **Include** → **Emails**, add new email address
5. Click **Save**
6. Notify user they can now access the application

### Removing Users

1. Follow same steps as "Adding New Users"
2. Under **Include** → **Emails**, remove email address
3. Click **Save**
4. User will be immediately blocked on next access attempt

### Changing Session Duration

1. Go to **Access** → **Applications**
2. Click on application → **Edit**
3. Change **Session Duration** (e.g., from 24 hours to 12 hours)
4. Click **Save**
5. Affects new sessions only (existing sessions continue until expiry)

---

## Next Steps

After successful implementation:

1. **Update start-here.md** - Mark Access as implemented
2. **Document authorized emails** - Keep secure list of who has access
3. **Schedule quarterly review** - Review access logs and authorized users
4. **Consider additional protections**:
   - Enable Cloudflare WAF rules
   - Set up rate limiting
   - Configure additional policies (IP restrictions, time-based access)

---

## Related Documentation

- [PRD-007: Cloudflare Access Security](../prds/PRD-007-cloudflare-access-security.md) - Requirements and design
- [Cloudflare Tunnel Setup Guide](CLOUDFLARE-TUNNEL-SETUP.md) - Original tunnel setup
- [Cloudflare Access Official Docs](https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/self-hosted-apps/)

---

## Support

If you encounter issues not covered in this guide:

1. Check [Cloudflare Community Forums](https://community.cloudflare.com/)
2. Review [Cloudflare Access Documentation](https://developers.cloudflare.com/cloudflare-one/applications/)
3. Check Cloudflare status page for service disruptions
4. Contact Cloudflare support (response times vary by plan)

---

## Quick Reference

### URLs

| URL | Purpose |
|-----|---------|
| https://one.dash.cloudflare.com | Zero Trust Dashboard |
| https://dash.cloudflare.com | Main Cloudflare Dashboard |
| https://wellness.selfwize.com | Wellness Portal (Fasten Health) |
| https://stuff.selfwize.com | Asset Inventory (Snipe-IT) |

### Key Settings

| Setting | Value | Location |
|---------|-------|----------|
| Team Name | `selfwize` | Zero Trust → Settings |
| Session Duration | 24 hours | Application settings |
| Authentication Method | Email OTP | Default (free tier) |
| Access Logs Retention | 30 days | Cloudflare default |

---

**Last Updated:** 2025-12-20
**Status:** Ready for Implementation
**Estimated Time:** 30 minutes
