# Dependent Repositories

This file tracks repositories that depend on the ra-infrastructure database (ra_inventory).

When making schema changes, check this list to identify affected consumers and notify them via GitHub issues.

## Active Dependents

| Repository | Access Level | Tables Used | Primary Use Case |
|------------|--------------|-------------|------------------|
| [network-tools](https://github.com/score-ra/network-tools) | READ/WRITE | devices, networks, sites, device_categories | Network device discovery and inventory updates |
| [ra-home-automation](https://github.com/score-ra/ra-home-automation) | READ | devices | HomeSeer/BlueIris device reference |

## Integration Details

### network-tools

- **Connection**: Direct PostgreSQL via psycopg3
- **Operations**:
  - READ: Query existing devices for comparison during discovery
  - WRITE: Insert/update confirmed discovered devices
- **Key columns used**:
  - `devices.mac_address` (primary matching key)
  - `devices.ip_address`, `devices.hostname`, `devices.manufacturer`
  - `devices.site_id`, `devices.status`, `devices.last_seen`
- **PRD Reference**: [device-discovery-prd.md](../network-tools/docs/device-discovery-prd.md)

### ra-home-automation

- **Connection**: Read-only queries (future)
- **Operations**: READ only
- **Key columns used**:
  - `devices.homeseer_ref`
  - `devices.blueiris_short_name`
- **Status**: Not yet integrated (planned)

## How to Add a Dependent

1. Add an entry to the table above
2. Document the integration details
3. Reference any PRD or design documents
4. Ensure the consuming repo has the schema contract: [SCHEMA-CONTRACT.md](docs/SCHEMA-CONTRACT.md)

## Notification Process

When making **breaking schema changes**:

1. Check this file for affected repositories
2. Create GitHub issues in each affected repo
3. Include:
   - What changed
   - Migration path
   - Timeline for deprecation (if applicable)
4. Update CHANGELOG.md with breaking change details

See [SCHEMA-CONTRACT.md](docs/SCHEMA-CONTRACT.md) for stability guarantees.
