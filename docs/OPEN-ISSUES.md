# Open Issues - Cross-Repository

> **Purpose**: Issues that need resolution in other repositories or require business decisions.
> **Owner**: Move these to appropriate repos when ready.
> **Updated**: 2025-11-26

---

## Home Assistant Integration (ra-home-automation)

### ISSUE-001: Home Assistant REST API Access
**Priority**: P0 - Blocker for Phase 2

**Question**: Is a Home Assistant long-lived access token configured?

**Action Required**:
- Verify API at: `http://192.168.68.68:8123/api/`
- If no token: Profile → Long-Lived Access Tokens → Create Token

**Repo**: `ra-home-automation`

---

### ISSUE-002: Multiple Home Assistant Instances
**Priority**: P1 - Affects multi-site architecture

**Question**: Will remote sites have their own Home Assistant instance, or is there a single centralized instance?

**Options**:
- A) Single Home Assistant at primary residence only
- B) Each site has independent Home Assistant
- C) Centralized Home Assistant with remote integrations

**Impact**: Determines how `inv sync homeassistant` handles multiple sites.

**Repo**: `ra-home-automation`

---

### ISSUE-003: Device Naming Conflict Resolution
**Priority**: P2 - UX decision

**Question**: When network discovery and Home Assistant both find the same device (matched by MAC or IP), which name should be authoritative?

**Options**:
- A) Home Assistant entity name wins (user-configured)
- B) Network discovery name wins (hostname)
- C) First one wins, never overwrite
- D) Store both, display Home Assistant name

**Suggested Default**: Option A - Home Assistant entity name wins (user intent)

**Repo**: `ra-home-automation` or product decision

---

## Web Dashboard (ra-infrastructure)

### ISSUE-004: Dashboard Authentication
**Priority**: P2 - Security decision

**Question**: Even on VPN, should the web dashboard require authentication?

**Options**:
- A) No auth - trust VPN
- B) Basic auth (username/password)
- C) API key in header
- D) OAuth/SSO integration

**Suggested Default**: Option A for MVP, add Option B later if needed.

**Repo**: `ra-infrastructure` (self-contained, but noting for visibility)

---

## Resolution Log

| Issue | Resolution | Date | Resolved By |
|-------|------------|------|-------------|
| - | - | - | - |
