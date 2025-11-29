---
title: "PRD-004: Network Intelligence and Automated Discovery"
status: "approved"
priority: "high"
created: "2025-11-22"
updated: "2025-11-25"
author: "Rohit Anand"
depends_on: []
target_completion: "2025-12-20"
migrated_from: "ra-home-automation"
---

# PRD-004: Network Intelligence and Automated Discovery

> **Note**: This PRD was migrated from `ra-home-automation` to `ra-infrastructure` as network discovery is a core infrastructure capability that feeds the device inventory database.

## Executive Summary

Implement automated network discovery and intelligence gathering to identify, inventory, and monitor all devices on the network. This capability provides real-time visibility into network topology, device health, and changes.

**Goal**: Automated network scanning that discovers devices and populates the central PostgreSQL inventory database.

## Integration with ra-infrastructure

This PRD now integrates with the infrastructure layer:
- **Device Database**: Discovered devices populate `ra-infrastructure` PostgreSQL database
- **CLI Integration**: `inv network scan` command triggers discovery
- **API Integration**: REST endpoints for scan results and device data

### Updated Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Network Discovery System                   │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼─────┐      ┌──────▼──────┐    ┌──────▼──────┐
   │ PowerShell│      │    Nmap     │    │ MAC Vendor  │
   │  Scanner  │      │   Scanner   │    │   Lookup    │
   └────┬─────┘      └──────┬──────┘    └──────┬──────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                    ┌───────▼────────┐
                    │  PostgreSQL    │  ◄── ra-infrastructure
                    │  Device DB     │
                    └───────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼─────┐      ┌──────▼──────┐    ┌──────▼──────┐
   │   CLI    │      │   Reports   │    │ Integration │
   │ inv cmd  │      │ JSON/CSV/MD │    │  Home Asst  │
   └──────────┘      └─────────────┘    └─────────────┘
```

## Implementation Changes

### Database Integration (NEW)

Discovered devices are stored in PostgreSQL `devices` table:

```sql
-- Network discovery populates:
INSERT INTO devices (
    site_id, network_id, name, slug, device_type,
    mac_address, ip_address, hostname, manufacturer,
    status, last_seen, metadata
) VALUES (...);
```

### CLI Commands (NEW)

```bash
# Scan network and update database
inv network scan --site primary-residence

# Quick ARP scan
inv network scan --quick

# Show discovered devices not in inventory
inv network diff

# Import scan results
inv network import scan-results.json
```

### Original Requirements

See original PRD sections below for:
- PowerShell scanning implementation
- Nmap integration
- MAC vendor lookup
- Change detection
- Reporting

---

## Original PRD Content

[Remaining sections from original PRD preserved for reference]

### Primary Goals
1. **Automated Discovery**: Scan network and identify all connected devices
2. **Device Identification**: Extract MAC addresses, IP addresses, hostnames, manufacturer info
3. **Continuous Monitoring**: Scheduled scans to detect network changes
4. **Database Integration**: Populate central device inventory (PostgreSQL)
5. **Alerting**: Notify administrators of new, missing, or problematic devices

### Success Metrics
- 100% discovery of active network devices
- MAC address vendor identification for >90% of devices
- Scan completion in <5 minutes for typical home network (50-100 devices)
- Automated daily scans with change detection
- Direct integration with PostgreSQL device database

---

**Document Status**: Approved - Migrated to ra-infrastructure
**Original Location**: ra-home-automation/docs/prds/PRD-004-network-intelligence-discovery.md
**Migration Date**: 2025-11-25
