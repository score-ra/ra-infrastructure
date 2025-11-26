# Open Issues - Cross-Repository

> **Purpose**: Issues that need resolution in other repositories or require business decisions.
> **Owner**: Move these to appropriate repos when ready.
> **Updated**: 2025-11-26

---

## HomeSeer Integration (ra-home-automation)

### ISSUE-001: HomeSeer JSON API Access
**Priority**: P0 - Blocker for Phase 2

**Question**: Is the HomeSeer JSON API enabled?

**Action Required**:
- Verify at: `http://192.168.68.56/JSON?request=getstatus`
- If not enabled: Settings > Setup > Web Server > Enable JSON

**Repo**: `ra-home-automation`

---

### ISSUE-002: Multiple HomeSeer Instances
**Priority**: P1 - Affects multi-site architecture

**Question**: Will remote sites have their own HomeSeer instance, or is there a single centralized HomeSeer?

**Options**:
- A) Single HomeSeer at primary residence only
- B) Each site has independent HomeSeer
- C) Centralized HomeSeer with remote Z-Wave/Zigbee bridges

**Impact**: Determines how `inv sync homeseer` handles multiple sites.

**Repo**: `ra-home-automation`

---

### ISSUE-003: Device Naming Conflict Resolution
**Priority**: P2 - UX decision

**Question**: When network discovery and HomeSeer both find the same device (matched by MAC or IP), which name should be authoritative?

**Options**:
- A) HomeSeer name wins (user-configured)
- B) Network discovery name wins (hostname)
- C) First one wins, never overwrite
- D) Store both, display HomeSeer name

**Suggested Default**: Option A - HomeSeer name wins (user intent)

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
