# ra-infrastructure Sprint Backlog

> **Status**: Active
> **Updated**: 2025-11-26
> **Current Phase**: Phase 1 - Foundation Completion

---

## Phase 1: Foundation Completion

**Goal**: Complete core CLI commands and prepare for integrations

### P0 - Critical Path

| Task | Status | Notes |
|------|--------|-------|
| Complete site commands (list, create, show, delete) | Pending | Partial exists |
| Complete zone commands (list, create, show, delete) | Pending | New file needed |
| Complete device commands (create, show, update, delete) | Pending | list exists |
| Complete network commands (list, show, create) | Pending | Partial exists |

### P1 - Important

| Task | Status | Notes |
|------|--------|-------|
| Add repository pattern to db layer | Pending | Refactor for reuse |
| Add Pydantic models for validation | Pending | Type safety |
| Achieve 80% test coverage | Pending | pytest --cov |

### Acceptance Criteria

- [ ] All CRUD operations work for: org, site, zone, device, network
- [ ] `inv <entity> list/show/create/delete` pattern consistent
- [ ] Tests pass with 80% coverage
- [ ] Code passes ruff, black, mypy checks

---

## Phase 2: HomeSeer Integration

**Goal**: Sync HomeSeer devices to inventory database

### P0 - Critical Path

| Task | Status | Notes |
|------|--------|-------|
| Create HomeSeer API client | Pending | `integrations/homeseer.py` |
| Implement `inv sync homeseer --full` | Pending | Initial import |
| Implement `inv sync homeseer` | Pending | Incremental sync |
| Test with real HomeSeer instance | Pending | Requires HS4 access |

### P1 - Important

| Task | Status | Notes |
|------|--------|-------|
| Map HomeSeer locations to zones | Pending | Auto-create zones |
| Map HomeSeer device types to categories | Pending | Lookup table |

### P2 - Nice to Have

| Task | Status | Notes |
|------|--------|-------|
| Create Windows scheduled task for sync | Pending | 15-minute interval |

---

## Phase 3: Network Discovery

**Goal**: Discover network devices automatically

### P0 - Critical Path

| Task | Status | Notes |
|------|--------|-------|
| Create PowerShell scanner script | Pending | `scripts/Scan-Network.ps1` |
| Implement `inv network scan` | Pending | Trigger scan |
| Implement `inv network import` | Pending | Import JSON results |

### P1 - Important

| Task | Status | Notes |
|------|--------|-------|
| MAC vendor lookup (OUI database) | Pending | Auto-populate manufacturer |
| Implement `inv network diff` | Pending | Show untracked devices |

### P2 - Nice to Have

| Task | Status | Notes |
|------|--------|-------|
| Create Windows scheduled task for scans | Pending | Daily scan |

---

## Phase 4: Web Dashboard

**Goal**: Visual interface for inventory management

### P0 - Critical Path

| Task | Status | Notes |
|------|--------|-------|
| Set up FastAPI app structure | Pending | `web/app.py` |
| Create base template with Tailwind | Pending | CDN, no build |
| Implement dashboard page | Pending | Stats, recent activity |
| Implement device list/detail/form | Pending | CRUD UI |
| Implement site/zone views | Pending | Hierarchy navigation |

### P1 - Important

| Task | Status | Notes |
|------|--------|-------|
| Implement network topology view | Pending | D3.js or Cytoscape |
| Implement HTMX interactions | Pending | No page reloads |
| Add site selector/filter | Pending | Multi-site support |

### P2 - Nice to Have

| Task | Status | Notes |
|------|--------|-------|
| Implement sync status page | Pending | Manual triggers |
| Implement reports/export | Pending | CSV, JSON |

---

## Phase 5: Polish & Multi-Site

**Goal**: Production-ready for multiple sites

### P0 - Critical Path

| Task | Status | Notes |
|------|--------|-------|
| Add second site configuration | Pending | Test multi-site |
| Test multi-site workflows | Pending | End-to-end |

### P1 - Important

| Task | Status | Notes |
|------|--------|-------|
| Add audit log viewing | Pending | UI for audit_log table |
| Documentation | Pending | User guide |

### P2 - Nice to Have

| Task | Status | Notes |
|------|--------|-------|
| Performance optimization | Pending | Query tuning |

---

## Completed

| Task | Phase | Completed |
|------|-------|-----------|
| Database schema (4 migrations) | Foundation | 2025-11-26 |
| Docker infrastructure | Foundation | 2025-11-26 |
| CLI skeleton with Typer | Foundation | 2025-11-26 |
| Organization commands (list, show, create, delete) | Foundation | 2025-11-26 |
| Database utility commands (migrate, seed, reset, stats) | Foundation | 2025-11-26 |
| Device list command (partial) | Foundation | 2025-11-26 |
| Seed data for Anand Family | Foundation | 2025-11-26 |
| Architecture plan document | Planning | 2025-11-26 |
