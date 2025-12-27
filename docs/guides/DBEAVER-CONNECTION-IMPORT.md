# DBeaver Connection Import Guide

This guide explains how to import database connections into DBeaver using the pre-configured CSV files in this repository.

## Quick Start

### Import PostgreSQL Connections

1. Open DBeaver
2. Go to **File → Import → DBeaver → Custom**
3. Select driver: **PostgreSQL**
4. Browse to `config/dbeaver/postgresql-connections.csv`
5. Click **Next**, verify column mappings, then **Finish**

### Import MySQL Connections

1. Open DBeaver
2. Go to **File → Import → DBeaver → Custom**
3. Select driver: **MySQL 8+**
4. Browse to `config/dbeaver/mysql-connections.csv`
5. Click **Next**, verify column mappings, then **Finish**

## Available Connection Files

| File | Database | Connections |
|------|----------|-------------|
| `config/dbeaver/postgresql-connections.csv` | PostgreSQL | ra-infrastructure inventory |
| `config/dbeaver/mysql-connections.csv` | MySQL 8 | HomeAutomation, MQTT |

## Adding New Connections

### Using the Script

```powershell
# Add a PostgreSQL connection
.\scripts\New-DbeaverConnection.ps1 `
    -Name "MyApp DB" `
    -Type postgresql `
    -Host localhost `
    -Database myapp `
    -User myuser `
    -Password secret

# Add a MySQL connection
.\scripts\New-DbeaverConnection.ps1 `
    -Name "Analytics" `
    -Type mysql `
    -Host 192.168.1.100 `
    -Database analytics `
    -User analyst `
    -Password pass123
```

### Manual CSV Format

If you prefer to edit CSV files directly, use this format:

```csv
name,host,port,database,user,password,url
Connection Name,hostname,port,dbname,username,password,jdbc:driver://hostname:port/dbname
```

**JDBC URL formats by database type:**

| Database | URL Format |
|----------|------------|
| PostgreSQL | `jdbc:postgresql://host:port/database` |
| MySQL | `jdbc:mysql://host:port/database?allowPublicKeyRetrieval=true&useSSL=false` |

## Why Separate CSV Files?

DBeaver's Custom import wizard requires selecting a database driver **before** selecting the CSV file. This means:

- All connections in a single CSV must use the same driver
- PostgreSQL and MySQL connections cannot be in the same file
- Each database type needs its own CSV file

## Alternative: Manual JSON Copy

For advanced users, you can copy the `config/dbeaver-connections.json` file directly to DBeaver's workspace:

```
%APPDATA%\DBeaverData\workspace6\General\.dbeaver\data-sources-ra.json
```

Restart DBeaver to auto-load the connections. Note that passwords in this file are stored in plain text; DBeaver will encrypt them on first use.

## Troubleshooting

### "Cannot open archive" Error

If you see "zip END header not found", you're using **Project Import** instead of **Custom Import**:

- **Wrong**: File → Import → DBeaver → Project (expects .dbp ZIP archive)
- **Correct**: File → Import → DBeaver → Custom (accepts CSV files)

### Connection Test Fails

1. Verify the database server is running
2. Check firewall allows connections on the specified port
3. Verify credentials are correct
4. For MySQL, ensure `allowPublicKeyRetrieval=true` is in the URL

## References

- [DBeaver Pre-configured Connections](https://dbeaver.com/docs/dbeaver/Admin-Manage-Connections/)
- [DBeaver GitHub Wiki](https://github.com/dbeaver/dbeaver/wiki/Admin-Manage-Connections)
