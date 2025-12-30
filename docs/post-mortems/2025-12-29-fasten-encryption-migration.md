# Post-Mortem: Fasten Health Encryption Migration

**Date:** December 29, 2025
**Duration:** ~2 hours
**Severity:** High (data loss)
**Author:** Claude Code Assistant

---

## Executive Summary

An attempt to disable Fasten Health's database encryption to eliminate recurring key prompts resulted in accidental deletion of both the encrypted database backup and the successfully decrypted database. The root cause was a PowerShell wildcard pattern (`fasten.db*`) that matched more files than intended. The medical records stored in Fasten were permanently lost.

---

## Timeline of Events

| Time | Event |
|------|-------|
| 09:00 | User reported frequent "Access Restricted" encryption key prompts in Fasten Health |
| 09:15 | Investigated Fasten Health encryption implementation via GitHub research |
| 09:20 | Identified solution: disable encryption via `config.yaml` |
| 09:24 | Created `config.yaml` with `encryption.enabled: false` |
| 09:24 | Updated `docker-compose.yml` to mount config file |
| 09:25 | Restarted Fasten - failed due to encrypted database incompatibility |
| 09:26 | Backed up encrypted database to `fasten.db.encrypted.bak` |
| 09:27 | Restarted Fasten - created fresh unencrypted database |
| 09:27 | Fasten operational but with empty database |
| 10:00 | User confirmed they have the encryption key |
| 10:05 | Researched SQLCipher decryption methods |
| 10:10 | Pulled `pallocchi/sqlcipher` Docker image |
| 10:11 | Initial decryption attempts failed (wrong cipher settings) |
| 10:12 | Found Fasten's exact SQLCipher settings in source code |
| 10:13 | **SUCCESS:** Decrypted database using Python sqlcipher3-binary |
| 10:13 | Exported 267 tables to `fasten.db.decrypted` (11.7 MB) |
| 10:14 | Stopped Fasten container to swap databases |
| 10:14 | **INCIDENT:** Ran `Remove-Item 'fasten.db*' -Force` |
| 10:14 | Wildcard deleted ALL files: `.db`, `.db-shm`, `.db-wal`, `.db.decrypted`, `.db.encrypted.bak` |
| 10:15 | Discovered data loss - no backups available |
| 10:21 | Restarted Fasten with fresh empty database |
| 10:25 | Updated documentation |

---

## Root Cause Analysis

### Primary Cause: Unsafe Wildcard Pattern

The command intended to delete only the active database files:
```powershell
Remove-Item 'C:\...\fasten.db*' -Force
```

**Expected matches:**
- `fasten.db` (active database)
- `fasten.db-shm` (shared memory file)
- `fasten.db-wal` (write-ahead log)

**Actual matches:**
- `fasten.db` ✓
- `fasten.db-shm` ✓
- `fasten.db-wal` ✓
- `fasten.db.decrypted` ✗ (the successfully decrypted export)
- `fasten.db.encrypted.bak` ✗ (the original backup)

### Contributing Factors

1. **Same directory for all files:** The backup, decrypted export, and active database were all in the same `db/` directory.

2. **Similar naming convention:** All files started with `fasten.db`, making them susceptible to wildcard matching.

3. **No verification before deletion:** The command was executed without first listing what would be deleted.

4. **PowerShell `-Force` flag:** Bypassed confirmation prompts and recycle bin.

5. **No intermediate backup:** The decrypted file was not copied to a safe location before file operations began.

6. **Sequential operations in single command:** The delete and move were chained, so when delete succeeded but move failed, there was no recovery path.

---

## Technical Details

### Fasten Health Encryption Implementation

Fasten Health v1.1.3 uses SQLCipher for database encryption with these settings:

```go
// From backend/pkg/database/sqlite_repository.go
pragmaOpts["_cipher"] = "sqlcipher"
pragmaOpts["_legacy"] = "3"
pragmaOpts["_hmac_use"] = "off"
pragmaOpts["_kdf_iter"] = "4000"
pragmaOpts["_legacy_page_size"] = "1024"
```

This translates to SQLCipher legacy mode 3, which differs from SQLCipher 4 defaults:
- HMAC disabled (vs enabled in v4)
- 4000 KDF iterations (vs 256000 in v4)
- 1024 byte page size (vs 4096 in v4)

### Successful Decryption Process

The decryption that worked (before the files were deleted):

```python
import sqlcipher3

conn = sqlcipher3.connect('fasten.db.encrypted.bak')
conn.execute("PRAGMA key = '<encryption_key>'")
conn.execute('PRAGMA cipher_compatibility = 3')
conn.execute('PRAGMA cipher_use_hmac = OFF')
conn.execute('PRAGMA kdf_iter = 4000')
conn.execute('PRAGMA cipher_page_size = 1024')

# Verify access
tables = conn.execute('SELECT count(*) FROM sqlite_master').fetchone()[0]
# Result: 267 tables

# Export to plaintext
conn.execute("ATTACH DATABASE 'fasten.db.decrypted' AS plaintext KEY ''")
conn.execute("SELECT sqlcipher_export('plaintext')")
conn.execute('DETACH DATABASE plaintext')
```

### The Destructive Command

```powershell
# DANGEROUS: This command deleted all fasten.db* files
Remove-Item 'C:\Users\ranand\workspace\personal\software\fasten-deploy\db\fasten.db*' -Force

# What should have been done:
Remove-Item 'C:\...\db\fasten.db' -Force
Remove-Item 'C:\...\db\fasten.db-shm' -Force
Remove-Item 'C:\...\db\fasten.db-wal' -Force
# Then move the decrypted file
Move-Item 'C:\...\db\fasten.db.decrypted' 'C:\...\db\fasten.db'
```

---

## Impact Assessment

### Data Lost

| Data Type | Impact |
|-----------|--------|
| Medical provider connections | Must re-authenticate with all healthcare providers |
| Synced medical records | All previously imported records lost |
| User account | Must create new account |
| Application settings | Reset to defaults |

### Systems Affected

- Fasten Health (wellness.selfwize.com)
- No other systems impacted

### Recovery Options Explored

| Option | Result |
|--------|--------|
| Windows Recycle Bin | Empty (`-Force` bypasses recycle bin) |
| Windows Shadow Copy | Not available/configured |
| Docker volumes | Not used (bind mounts only) |
| Google Drive backup | No Fasten backups existed |
| Local backup directory | No Fasten backups existed |

---

## Lessons Learned

### 1. Never Use Wildcards for Destructive Operations

**Wrong:**
```powershell
Remove-Item 'path\filename*' -Force
```

**Right:**
```powershell
# List first
Get-ChildItem 'path\filename*'
# Then delete specific files
Remove-Item 'path\filename.ext' -Force
```

### 2. Always Preview Before Deleting

```powershell
# Preview what will be deleted
Get-ChildItem 'C:\path\*.db*' | Format-Table Name, Length

# Only then delete with explicit paths
```

### 3. Move Backups to Separate Location Immediately

Before any file operations on the working directory:
```powershell
# Copy to safe location FIRST
Copy-Item 'source\backup.bak' 'D:\Backups\safe-location\' -Force

# THEN proceed with operations in source directory
```

### 4. Use Explicit File Names, Not Patterns

```powershell
# Bad - pattern matching
Remove-Item "$dir\fasten.db*"

# Good - explicit files
$filesToDelete = @(
    "$dir\fasten.db",
    "$dir\fasten.db-shm",
    "$dir\fasten.db-wal"
)
$filesToDelete | Remove-Item -Force
```

### 5. Avoid `-Force` When Possible

The `-Force` flag:
- Bypasses confirmation prompts
- Bypasses recycle bin
- Deletes read-only files
- Suppresses errors

Only use when absolutely necessary and after verification.

### 6. Implement Backup Before Migration

Before any database migration:
```powershell
# 1. Create timestamped backup in separate location
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item "$dbDir\fasten.db*" "D:\Backups\fasten-health\pre-migration-$timestamp\"

# 2. Verify backup
Test-Path "D:\Backups\fasten-health\pre-migration-$timestamp\fasten.db*"

# 3. THEN proceed with migration
```

### 7. Use Transactions/Atomic Operations

```powershell
# Create a rollback point
$backupDir = "D:\Backups\rollback-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $backupDir
Copy-Item "$sourceDir\*" $backupDir -Recurse

try {
    # Perform operations
    # ...

    # Success - clean up rollback point (optional)
    Remove-Item $backupDir -Recurse -Force
}
catch {
    # Failure - restore from rollback
    Remove-Item "$sourceDir\*" -Force
    Copy-Item "$backupDir\*" $sourceDir -Recurse
    throw
}
```

---

## Preventive Measures Implemented

### 1. Fasten Backup Added to Scheduled Backups

```powershell
# scripts/backup.ps1 now supports -IncludeFasten
.\scripts\backup.ps1 -Type daily -IncludeFasten
```

### 2. Documentation Created

- `docs/issues/FASTEN-ENCRYPTED-DB-MIGRATION.md` - Configuration reference
- `docs/post-mortems/2025-12-29-fasten-encryption-migration.md` - This document

### 3. Encryption Key Stored Securely

The encryption key should be stored in a password manager or secure location for future reference, even though encryption is now disabled.

---

## Recommendations

### For This Repository

1. **Schedule Fasten backups:** Add `-IncludeFasten` to the scheduled backup task
2. **Test backup restoration:** Periodically verify backups can be restored
3. **Document encryption key location:** Even if not used, keep for potential future re-encryption

### For Future Database Migrations

1. **Always backup to separate physical location first**
2. **Use explicit file paths, never wildcards for deletion**
3. **Verify backup integrity before proceeding**
4. **Use `-WhatIf` parameter to preview destructive commands**
5. **Keep backups until migration is fully verified working**

### For Claude Code Assistant

1. **Preview destructive commands:** Always show what will be affected before executing
2. **Avoid wildcards in Remove-Item:** Use explicit file lists
3. **Suggest backup verification:** Prompt user to verify backup location before proceeding
4. **Use safer patterns:** Prefer `Move-Item` over `Remove-Item` + `Move-Item`

---

## Appendix A: Safe Database Swap Procedure

For future reference, here is the correct procedure to swap database files:

```powershell
$dbDir = "C:\Users\ranand\workspace\personal\software\fasten-deploy\db"
$backupDir = "D:\Backups\fasten-health"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# 1. Stop the container
docker stop fasten-deploy-fasten-prod-1

# 2. Create backup in SEPARATE location
$safeBackup = "$backupDir\pre-swap-$timestamp"
New-Item -ItemType Directory -Path $safeBackup -Force
Copy-Item "$dbDir\fasten.db" "$safeBackup\" -Force
Copy-Item "$dbDir\fasten.db.encrypted.bak" "$safeBackup\" -Force -ErrorAction SilentlyContinue

# 3. Verify backup exists
if (-not (Test-Path "$safeBackup\fasten.db")) {
    throw "Backup verification failed - aborting"
}

# 4. Remove ONLY the specific active database files (explicit paths)
Remove-Item "$dbDir\fasten.db" -Force -ErrorAction SilentlyContinue
Remove-Item "$dbDir\fasten.db-shm" -Force -ErrorAction SilentlyContinue
Remove-Item "$dbDir\fasten.db-wal" -Force -ErrorAction SilentlyContinue

# 5. Move the new database into place
Move-Item "$dbDir\fasten.db.decrypted" "$dbDir\fasten.db" -Force

# 6. Verify new database exists
if (-not (Test-Path "$dbDir\fasten.db")) {
    # Restore from backup
    Copy-Item "$safeBackup\fasten.db" "$dbDir\" -Force
    throw "Swap failed - restored from backup"
}

# 7. Start the container
docker start fasten-deploy-fasten-prod-1

# 8. Verify application works
Start-Sleep -Seconds 10
$status = curl.exe -s -o NUL -w "%{http_code}" http://localhost:9090/web/
if ($status -ne "200") {
    throw "Application failed to start - check logs"
}

Write-Host "Database swap completed successfully"
Write-Host "Backup retained at: $safeBackup"
```

---

## Appendix B: SQLCipher Decryption Reference

Complete Docker-based decryption procedure:

```powershell
# Run decryption in Docker container
docker run --rm -v "C:/path/to/db:/data" python:3.11-slim bash -c "
pip install sqlcipher3-binary -q && python3 -c \"
import sqlcipher3

conn = sqlcipher3.connect('/data/fasten.db.encrypted')
conn.execute(\\\"PRAGMA key = 'YOUR_KEY_HERE'\\\")
conn.execute('PRAGMA cipher_compatibility = 3')
conn.execute('PRAGMA cipher_use_hmac = OFF')
conn.execute('PRAGMA kdf_iter = 4000')
conn.execute('PRAGMA cipher_page_size = 1024')

# Verify
tables = conn.execute('SELECT count(*) FROM sqlite_master').fetchone()[0]
print(f'Found {tables} objects')

# Export
conn.execute(\\\"ATTACH DATABASE '/data/fasten.db.decrypted' AS plaintext KEY ''\\\")
conn.execute(\\\"SELECT sqlcipher_export('plaintext')\\\")
conn.execute('DETACH DATABASE plaintext')
print('Export completed')
conn.close()
\"
"
```

---

## Sign-Off

| Role | Name | Date |
|------|------|------|
| Incident Handler | Claude Code Assistant | 2025-12-29 |
| Repository Owner | User | 2025-12-29 |
