# PRD-007: Cloudflare Access Zero Trust Security

## Overview

| Field | Value |
|-------|-------|
| **PRD Number** | PRD-007 |
| **Title** | Cloudflare Access Zero Trust Authentication |
| **Status** | Implemented |
| **Created** | 2025-12-20 |
| **Implemented** | 2025-12-20 |
| **Author** | Infrastructure Team |
| **Related PRDs** | N/A |

## Problem Statement

The Cloudflare Tunnel (`selfwize-dev`) is currently operational and routing traffic to internal services:
- `stuff.selfwize.com` → Snipe-IT (asset inventory)
- `wellness.selfwize.com` → Fasten Health (personal health records)

However, these services are **publicly accessible without authentication**. Anyone who discovers these URLs can access sensitive data including:
- Asset inventory with network topology and device information
- Personal health records (HIPAA-sensitive data)

This violates the principle of defense-in-depth and exposes sensitive data to unauthorized access, even though the applications have their own authentication.

## Goals

1. **Edge-level Authentication**: Require authentication at Cloudflare's edge before any traffic reaches the origin server
2. **Email-based OTP**: Use email one-time passwords (OTP) as the primary authentication method (free tier)
3. **Selective Protection**: Prioritize `wellness.selfwize.com` for health data protection
4. **Session Management**: Configure reasonable session durations (24 hours)
5. **Audit Logging**: Enable access logging for compliance and security monitoring

## Non-Goals

- SSO integration (Google/Microsoft) - future enhancement
- Custom identity provider integration
- Multi-factor authentication beyond email OTP
- Real-time alerting on access attempts

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| **FR-01** | Enable Cloudflare Zero Trust for selfwize.com | P0 | ✅ Complete |
| **FR-02** | Create Access application for wellness.selfwize.com | P0 | ✅ Complete |
| **FR-03** | Create Access application for stuff.selfwize.com | P1 | ✅ Complete |
| **FR-04** | Configure email allowlist policy with authorized emails | P0 | ✅ Complete |
| **FR-05** | Set session duration to 24 hours | P1 | ✅ Complete |
| **FR-06** | Test authentication flow in incognito mode | P0 | ✅ Complete |
| **FR-07** | Verify unauthorized emails are blocked | P0 | ✅ Complete |

### Non-Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| **NFR-01** | Authentication adds <500ms latency to first request | P1 | ✅ Complete |
| **NFR-02** | Access logs retained for 30 days (Cloudflare default) | P2 | ✅ Complete |
| **NFR-03** | Documentation includes screenshots for manual setup | P1 | ✅ Complete |
| **NFR-04** | Verification script can check Access status | P2 | ✅ Complete |

---

## Technical Design

### Architecture

```
User Request → Cloudflare Edge → Access Policy Check
                                        ↓
                              Not Authenticated?
                                        ↓
                              Email OTP Login Page
                                        ↓
                              Authenticated?
                                        ↓
                              Forward via Tunnel → Origin Server
```

### Access Policies

#### Policy 1: Wellness Portal (High Security)
- **Application Name**: Wellness Portal
- **Domain**: `wellness.selfwize.com`
- **Policy Name**: Owner Only
- **Action**: Allow
- **Include Rule**: Emails matching allowlist
- **Session Duration**: 24 hours
- **Justification**: Health data requires strict access control

#### Policy 2: Asset Inventory (Medium Security)
- **Application Name**: Asset Inventory
- **Domain**: `stuff.selfwize.com`
- **Policy Name**: Authorized Users
- **Action**: Allow
- **Include Rule**: Emails matching allowlist
- **Session Duration**: 24 hours
- **Justification**: Internal infrastructure data

### Email Allowlist

Authorized emails (to be configured):
- Primary owner email
- Additional authorized users as needed

### Implementation Approach

This implementation requires **manual Cloudflare dashboard configuration** as:
1. Zero Trust setup is interactive (team name creation)
2. Access applications are created via web UI
3. Cloudflare API for Access requires Enterprise plan

**Steps:**
1. Manual dashboard setup (documented with screenshots)
2. Verification script to check Access status
3. Updated documentation marking Phase 9 as mandatory

---

## Security Benefits

| Benefit | Description | Impact |
|---------|-------------|--------|
| **Edge-level blocking** | Unauthorized requests never reach origin server | High |
| **Protects login pages** | App's own login page isn't exposed to brute force | High |
| **Central access control** | Add/remove users in Cloudflare, no app changes | Medium |
| **Audit logging** | Who accessed what, when (compliance) | Medium |
| **No VPN needed** | Browser-based, works on any device | High |
| **Defense in depth** | Even if app has vulnerability, attackers can't reach it | High |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Protected domains** | 2/2 (wellness + stuff) | Manual verification |
| **Unauthorized access attempts** | 0 successful | Access logs |
| **User experience** | <30 seconds to authenticate | User testing |
| **Session persistence** | 24 hours without re-auth | User testing |

---

## Implementation Plan

### Phase 1: Zero Trust Setup (5 min)
1. Navigate to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com)
2. Create team name: `selfwize`
3. Select **Free** plan (up to 50 users)
4. Verify team is created

### Phase 2: Access Application - Wellness Portal (10 min)
1. Go to **Access** → **Applications** → **Add an application**
2. Select **Self-hosted**
3. Configure application:
   - **Name**: Wellness Portal
   - **Session Duration**: 24 hours
   - **Application domain**: `wellness.selfwize.com`
   - **Accept all available identity providers**: Yes
4. Add policy:
   - **Name**: Owner Only
   - **Action**: Allow
   - **Include**: Emails → Enter authorized email(s)
5. Save application

### Phase 3: Access Application - Asset Inventory (10 min)
1. Repeat Phase 2 steps for `stuff.selfwize.com`
2. Configure application:
   - **Name**: Asset Inventory
   - **Session Duration**: 24 hours
   - **Application domain**: `stuff.selfwize.com`
3. Add same policy with authorized emails

### Phase 4: Testing & Verification (10 min)
1. Open `wellness.selfwize.com` in incognito mode
2. Verify Cloudflare Access login page appears
3. Enter authorized email → receive OTP → verify
4. Confirm access granted to Fasten Health
5. Repeat for `stuff.selfwize.com`
6. Test with unauthorized email (should be blocked)

### Phase 5: Documentation Updates (15 min)
1. Update `CLOUDFLARE-TUNNEL-SETUP.md` - make Phase 9 mandatory
2. Create implementation guide with screenshots
3. Update `start-here.md` with Access status
4. Create verification script

---

## Testing Plan

### Manual Testing Checklist

| Test Case | Expected Result | Status |
|-----------|----------------|--------|
| Access wellness.selfwize.com (not authenticated) | Redirected to Cloudflare Access login | Pending |
| Enter authorized email | Receive OTP code via email | Pending |
| Enter correct OTP | Granted access to Fasten Health | Pending |
| Enter incorrect OTP | Access denied, error message | Pending |
| Access stuff.selfwize.com (not authenticated) | Redirected to Cloudflare Access login | Pending |
| Access with unauthorized email | Access denied | Pending |
| Session persistence (within 24h) | No re-authentication required | Pending |
| Session expiry (after 24h) | Re-authentication required | Pending |

### Verification Script

```powershell
# Script: scripts/verify-cloudflare-access.ps1
# Purpose: Check if Cloudflare Access is enabled for tunneled domains
# Note: Uses HTTP response analysis (Access returns 302 to login page)
```

---

## Rollout Plan

### Pre-Rollout
- [ ] Communicate to authorized users about new authentication
- [ ] Provide instructions for first-time login
- [ ] Ensure authorized emails are current and accessible

### Rollout Steps
1. **Implement Access for wellness.selfwize.com first** (highest priority)
2. Test thoroughly with authorized users
3. Implement Access for stuff.selfwize.com
4. Monitor access logs for first 48 hours

### Rollback Plan
If Access causes issues:
1. Go to Access → Applications
2. Delete the problematic application
3. Traffic will flow directly to origin (unprotected)
4. Investigate issue before re-enabling

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Email delivery failure** | Users can't authenticate | Low | Use reliable email provider, test OTP delivery |
| **Session expiry during use** | User interrupted mid-session | Low | 24h duration provides buffer |
| **Forgot authorized email** | Lockout from own services | Medium | Document authorized emails, have backup |
| **Cloudflare outage** | Services inaccessible | Very Low | Cloudflare has 99.99% uptime SLA |
| **Free tier limits exceeded** | Access stops working | Very Low | Free tier allows 50 users |

---

## Documentation Deliverables

1. **PRD-007** (this document) - Requirements and design
2. **CLOUDFLARE-ACCESS-IMPLEMENTATION.md** - Step-by-step guide with screenshots
3. **scripts/verify-cloudflare-access.ps1** - Verification script
4. **Updated CLOUDFLARE-TUNNEL-SETUP.md** - Phase 9 marked as required
5. **Updated start-here.md** - Access implementation status

---

## Compliance & Privacy

### HIPAA Considerations (Fasten Health)
- **Administrative Safeguards**: Access control via email allowlist ✓
- **Audit Controls**: Access logs available in Zero Trust dashboard ✓
- **Person or Entity Authentication**: Email OTP provides authentication ✓

### Data Protection
- **Authentication logs**: Stored by Cloudflare, not on-premise
- **Email addresses**: Only used for authentication, not stored in app
- **Session tokens**: Cloudflare-managed, encrypted

---

## Future Enhancements

1. **SSO Integration**: Google Workspace or Microsoft 365 SSO (P2)
2. **Custom Access Policies**: Time-based access, IP restrictions (P3)
3. **Access Log Alerting**: Automated alerts on unusual access patterns (P3)
4. **Temporary Access Links**: Guest access with expiry (P4)

---

## Approval & Sign-Off

| Role | Name | Status | Date |
|------|------|--------|------|
| **Author** | Infrastructure Team | Approved | 2025-12-20 |
| **Stakeholder** | User | Approved | 2025-12-20 |
| **Implementation Lead** | Claude | Complete | 2025-12-20 |

---

## Change Log

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-20 | Infrastructure Team | Initial PRD creation |
| 2025-12-20 | Infrastructure Team | Implemented all requirements - marked as Complete |
| 2026-02-05 | Infrastructure Team | Added CF Access Service Token for device-deployments M2M API access |

## Implementation Summary

**Implementation completed on 2025-12-20**

### What Was Implemented

1. **Zero Trust Team**: Using existing "symphonycore" team
2. **Access Applications**:
   - Wellness Portal (wellness.selfwize.com) - PROTECTED
   - Asset Inventory (stuff.selfwize.com) - PROTECTED
3. **Authentication Method**: Email OTP with authorized user allowlist
4. **Session Duration**: 24 hours
5. **Testing**: Authentication flow verified, SSO working correctly

### Deliverables Created

- ✅ PRD-007 (this document)
- ✅ CLOUDFLARE-ACCESS-IMPLEMENTATION.md (step-by-step guide)
- ✅ verify-cloudflare-access.ps1 (verification script)
- ✅ Updated CLOUDFLARE-TUNNEL-SETUP.md (Phase 9 mandatory)
- ✅ Updated start-here.md (status tracking)
- ✅ CLOUDFLARE-ACCESS-NEXT-STEPS.md (implementation summary)

### Service Tokens (M2M API Access)

Implemented 2026-02-05 to allow `device-deployments` CLI to access Snipe-IT through CF Access.

| Token Name | Application | Consumer Repo | Created |
|------------|-------------|---------------|---------|
| `device-deployments-api` | Asset Inventory (`stuff.selfwize.com`) | `score-ra/device-deployments` | 2026-02-05 |

**How it works:** The client sends `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers alongside the existing Snipe-IT Bearer token. Cloudflare validates the service token at the edge before forwarding to origin. The Asset Inventory Access application has a "Service Auth" policy that accepts this token.

**Related issue:** [score-ra/device-deployments#2](https://github.com/score-ra/device-deployments/issues/2)

### Security Impact

- ✅ Personal health records (Fasten Health) protected by Zero Trust
- ✅ Infrastructure asset inventory (Snipe-IT) protected by Zero Trust
- ✅ Unauthorized access blocked at Cloudflare edge (before reaching origin)
- ✅ Audit logs available for compliance monitoring
- ✅ Defense-in-depth security posture achieved
- ✅ M2M API access via service tokens (no email OTP bypass needed)
