# PRD-005 Implementation Reference

This document contains implementation details for PRD-005 Infrastructure Operations.

---

## Quick Reference: Key Values

| Setting | Value |
|---------|-------|
| Database container | `inventory-db` |
| Database name | `inventory` |
| Database user | `inventory` |
| Database password | `inventory_dev_password` |
| Local backup path | `D:\Backups\ra-infrastructure\` |
| Google Drive remote | `gdrive:ra-infrastructure-backup/` |
| Health check interval | 5 minutes |
| Daily backup time | 2:00 AM |
| Weekly backup time | 3:00 AM (Sundays) |
| Local retention | 7 days |
| Remote retention | 4 weeks |
| Alert rate limit | 15 minutes |
