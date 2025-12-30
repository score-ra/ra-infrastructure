# Fasten Health: Disabling Database Encryption

**Date:** December 29, 2025
**Fasten Version:** 1.1.3
**Status:** Completed

---

## Summary

Disabled Fasten Health database encryption to eliminate the encryption key prompt on every container restart. This document records the configuration changes and decryption process for future reference.

## Problem

Fasten Health v1.1.3 enforces database encryption by default (PR #603). Users must enter their encryption key:
- On every container restart
- When the browser session is cleared
- When accessing from a new device

For self-hosted deployments with automated container restarts, this creates availability issues.

## Solution Applied

### 1. Disable Encryption via Config

Created `config.yaml` to disable encryption:

```yaml
version: 1

web:
  listen:
    port: 8080
    host: 0.0.0.0

database:
  location: '/opt/fasten/db/fasten.db'
  type: 'sqlite'
  encryption:
    enabled: false
```

### 2. Mount Config in Docker

Updated `docker-compose.yml`:

```yaml
volumes:
  - ./db:/opt/fasten/db
  - ./cache:/opt/fasten/cache
  - ./certs:/opt/fasten/certs/shared
  - ./config.yaml:/opt/fasten/config/config.yaml:ro
```

### 3. Restart Container

```powershell
docker-compose -f docker-compose.yml down
docker-compose -f docker-compose.yml up -d
```

## Decrypting an Encrypted Database (Reference)

If you have the encryption key, you can decrypt an existing Fasten database:

```python
# Requires: pip install sqlcipher3-binary
import sqlcipher3

# Open encrypted database
conn = sqlcipher3.connect('fasten.db.encrypted')
conn.execute("PRAGMA key = 'YOUR_ENCRYPTION_KEY'")
conn.execute('PRAGMA cipher_compatibility = 3')
conn.execute('PRAGMA cipher_use_hmac = OFF')
conn.execute('PRAGMA kdf_iter = 4000')
conn.execute('PRAGMA cipher_page_size = 1024')

# Export to plaintext
conn.execute("ATTACH DATABASE 'fasten.db.decrypted' AS plaintext KEY ''")
conn.execute("SELECT sqlcipher_export('plaintext')")
conn.execute('DETACH DATABASE plaintext')
conn.close()
```

**SQLCipher Settings (Fasten v1.1.3):**
- `cipher_compatibility = 3` (legacy mode)
- `cipher_use_hmac = OFF`
- `kdf_iter = 4000`
- `cipher_page_size = 1024`

## Files Changed

| File | Change |
|------|--------|
| `fasten-deploy/config.yaml` | Created - disables encryption |
| `fasten-deploy/docker-compose.yml` | Added config volume mount |

## Current State

- Encryption: **Disabled**
- Database: Fresh (previous data was lost during migration)
- Access: https://wellness.selfwize.com (no key prompt)

## Backup Recommendation

Now that encryption is disabled, ensure regular backups:

```powershell
# Add to scheduled backup
.\scripts\backup.ps1 -Type daily -IncludeFasten
```
