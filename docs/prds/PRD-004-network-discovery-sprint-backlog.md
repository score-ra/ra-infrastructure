---
title: "PRD-004 Sprint Backlog: Network Intelligence and Discovery Implementation"
status: "ready-for-sprint"
priority: "high"
created: "2025-11-22"
updated: "2025-11-26"
author: "Rohit Anand"
depends_on: ["PRD-004"]
sprint_type: "sequential-development"
estimated_duration: "10-12 days"
migrated_from: "ra-home-automation"
---

# PRD-004 Sprint Backlog: Network Intelligence and Discovery Implementation

> **Note**: This sprint backlog was migrated from `ra-home-automation` to `ra-infrastructure` as network discovery is a core infrastructure capability.

## Integration with ra-infrastructure

This sprint now integrates with the infrastructure layer:
- **Database**: Discovered devices populate PostgreSQL `devices` table
- **CLI**: Use `inv network scan` command for discovery
- **Reports**: Generate from database, not flat files

### Updated Dependencies
- PostgreSQL database (Docker)
- `inv` CLI installed and configured
- Database migrations applied (`inv db migrate`)

---

## Sprint Overview

### Sprint Goal
Implement automated network discovery that populates the central device inventory database with minimal manual intervention.

### Updated Scope
- PowerShell-based network scanning
- Direct PostgreSQL database integration
- MAC address vendor lookup
- Change detection via database queries
- CLI commands for scan operations

### Sprint Duration
**Estimated**: 10-12 days (2 weeks)

---

## Sprint Backlog

### Epic 1: Core Network Discovery Engine
**Priority**: P0 (Critical Path)
**Estimated Effort**: 3 days

#### Story 1.1: PowerShell Network Scanner
**Points**: 5

**Updated Acceptance Criteria**:
- [ ] Script uses `Get-NetNeighbor` to enumerate ARP cache
- [ ] Script uses `Test-Connection` for ping sweep
- [ ] Script uses `Resolve-DnsName` for hostname resolution
- [ ] **NEW**: Outputs JSON compatible with `inv network import`
- [ ] **NEW**: Can directly insert to PostgreSQL database
- [ ] Error handling for unreachable devices
- [ ] Progress indicators for long scans

**Deliverables**:
- `scripts/network-discovery/Scan-Network.ps1` - Core PowerShell scanner
- JSON output format matching database schema

---

#### Story 1.2: Database Integration
**Points**: 5
**Dependencies**: Story 1.1

**Acceptance Criteria**:
- [ ] Scanner outputs JSON matching `devices` table schema
- [ ] `inv network import` command processes scan results
- [ ] Upsert logic: update existing, insert new devices
- [ ] Track `last_seen` timestamp
- [ ] Track `discovery_source` metadata

**Deliverables**:
- `inv network import` CLI command
- Database upsert logic

---

### Epic 2: MAC Vendor Lookup
**Priority**: P1 (High)
**Estimated Effort**: 1 day

#### Story 2.1: OUI Database Integration
**Points**: 3

**Acceptance Criteria**:
- [ ] Download IEEE OUI database
- [ ] Parse and store in PostgreSQL
- [ ] Lookup vendor during scan
- [ ] Populate `manufacturer` field in devices table

**Deliverables**:
- OUI lookup function
- Manufacturer auto-population

---

### Epic 3: CLI Integration
**Priority**: P0 (Critical)
**Estimated Effort**: 2 days

#### Story 3.1: Network Scan Commands
**Points**: 5

**Acceptance Criteria**:
- [ ] `inv network scan` - Run discovery and import
- [ ] `inv network scan --quick` - ARP-only fast scan
- [ ] `inv network diff` - Show devices not in inventory
- [ ] `inv network import <file>` - Import scan results

**Deliverables**:
- CLI commands in `cli/src/inventory/commands/network.py`

---

### Epic 4: Change Detection
**Priority**: P1 (High)
**Estimated Effort**: 1 day

#### Story 4.1: Database-Based Change Detection
**Points**: 3

**Acceptance Criteria**:
- [ ] Query for new devices (first_seen = last_seen)
- [ ] Query for missing devices (last_seen > 24 hours)
- [ ] Query for IP changes (same MAC, different IP)
- [ ] `inv network changes` CLI command

**Deliverables**:
- Change detection queries
- CLI command for changes report

---

## Success Metrics

- **Device Discovery**: >95% of active devices discovered
- **Scan Speed**: Full scan <5 minutes for 100 devices
- **Database Integration**: All discovered devices in PostgreSQL
- **CLI Usability**: Single command to scan and import

---

## Original Sprint Backlog Reference

The original sprint backlog contained additional stories for:
- Nmap integration (deferred - PowerShell sufficient for MVP)
- HTML report generation (replaced by CLI queries)
- Home Assistant integration (separate PRD)
- HomeSeer integration (separate concern)

These may be implemented in future sprints as needed.

---

**Document Status**: Ready for Sprint (Updated for ra-infrastructure)
**Original Location**: ra-home-automation/docs/prds/PRD-004-network-discovery-sprint-backlog.md
**Migration Date**: 2025-11-26
