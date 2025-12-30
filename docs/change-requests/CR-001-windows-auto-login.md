# Change Request: CR-001

## Windows Auto-Login Configuration for Docker Service Recovery

| Field | Value |
|-------|-------|
| **CR Number** | CR-001 |
| **Date Submitted** | 2025-12-30 |
| **Requested By** | ranand |
| **Status** | Implemented |
| **Implementation Date** | 2025-12-30 |

---

## Summary

Enable Windows auto-login on the infrastructure server to ensure Docker Desktop and all containerized services automatically start after system reboots or power outages.

---

## Business Justification

### Problem Statement

After system reboots, Docker Desktop and all 11 containerized services remained stopped, causing complete infrastructure unavailability for 4+ hours until manual intervention.

### Impact of Not Implementing

- All self-hosted services unavailable after every reboot
- No remote access to health records (Fasten Health)
- No access to asset inventory (Snipe-IT)
- Monitoring dashboard offline (Gatus)
- Manual intervention required for every power outage or Windows update

### Benefits

- Automatic service recovery after power outages
- Zero manual intervention required for reboots
- Services available even when away from home (vacation, travel)
- Improved infrastructure reliability

---

## Technical Details

### Root Cause Analysis

Docker Desktop with WSL2 backend has specific startup requirements:

1. `com.docker.service` is set to Manual startup by Docker Desktop (intentionally)
2. Docker Desktop auto-start is registered in **HKCU** (user registry), not HKLM
3. Docker Desktop **only starts when a user logs in**
4. `Set-Service -StartupType Automatic` does NOT work - Docker resets it to Manual

### Solution

Configure Windows auto-login so the user session starts automatically at boot, triggering Docker Desktop's auto-start.

### Implementation

```powershell
# Registry path
HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon

# Values set
AutoAdminLogon  = "1"
DefaultUsername = "ranand"
DefaultPassword = <configured by user>
```

### Boot Sequence After Change

```
Power On
    │
    └─► Windows Boot
            │
            └─► Auto-login as 'ranand'
                    │
                    └─► HKCU\Run triggers Docker Desktop.exe
                            │
                            └─► Docker Desktop starts com.docker.service
                                    │
                                    └─► WSL2 backend initializes
                                            │
                                            └─► All 11 containers auto-start
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Password stored in registry | Low | Medium | Server in secured location; family-only physical access |
| Unauthorized local access | Low | High | Server in locked room/closet |
| Remote access via auto-login | N/A | N/A | Auto-login is local only; RDP still requires authentication |

### Security Considerations

- **Physical security:** Server is in a secured location with family-only access
- **Password storage:** Windows stores the password in the registry (readable by local admins)
- **Network security:** Auto-login does not affect remote access security
- **Recommendation:** Acceptable for dedicated home server in secured location

---

## Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Set-Service Automatic | Simple, standard Windows approach | Docker Desktop resets to Manual; doesn't work with WSL2 | Rejected |
| Scheduled Task at startup | Runs as SYSTEM before login | Permission issues with Docker Desktop; WSL2 requires user session | Rejected |
| Windows Containers mode | Service can be truly Automatic | Requires switching from WSL2; compatibility issues | Rejected |
| Auto-login | Works with existing Docker Desktop + WSL2 setup | Password in registry | **Selected** |

---

## Testing & Verification

### Pre-Implementation Verification

```powershell
# Confirm current state
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' |
    Select-Object AutoAdminLogon, DefaultUsername
```

### Post-Implementation Verification

1. Reboot the server
2. Verify Windows auto-logs in without manual intervention
3. Verify Docker Desktop starts automatically
4. Verify all 11 containers are running: `docker ps`
5. Verify external endpoints accessible:
   - https://stuff.selfwize.com
   - https://wellness.selfwize.com
   - https://status.selfwize.com

### Rollback Procedure

```powershell
# Run as Administrator to disable auto-login
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $RegPath -Name "AutoAdminLogon" -Value "0"
Remove-ItemProperty -Path $RegPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
```

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| [Post-Mortem: 2025-12-30](../post-mortems/2025-12-30-docker-service-outage.md) | Incident that prompted this change |
| [start-here.md](../../start-here.md) | Updated with auto-recovery configuration |
| [GitHub Issue #2](https://github.com/score-ra/ra-infrastructure/issues/2) | Original issue tracking |

---

## Approvals

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Requestor | ranand | 2025-12-30 | |
| Implementor | Claude Code | 2025-12-30 | Implemented |
| Owner Approval | ranand | 2025-12-30 | |

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2025-12-30 | Claude Code | Initial CR created |
| 2025-12-30 | Claude Code | Implementation completed |
