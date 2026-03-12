# Video 15: Testing Connections with `flyway testConnection`

## Overview
Learn how to use `flyway testConnection` to verify database connectivity before running operations.

## Duration
2-3 minutes

## Learning Objectives
- Verify environment configurations
- Troubleshoot connection issues
- Use in CI/CD pipelines

---

## Script

### Intro (20 seconds)
"Before running migrations or any Flyway command, you need to ensure you can connect to your database. `flyway testConnection` is a quick way to verify connectivity without modifying anything."

### Part 1: Basic Usage (1 minute)

**Command:**
```powershell
flyway testConnection -environment=development
```

**Successful Output:**
```
Database: jdbc:sqlserver://localhost:1433;databaseName=DevDB... (Microsoft SQL Server 16.0)
Flyway engine connection successful
```

**Failed Output:**
```
ERROR: Unable to obtain connection from database
com.microsoft.sqlserver.jdbc.SQLServerException: The TCP/IP connection to the host localhost, port 1433 has failed.
```

### Part 2: Testing Multiple Environments (1 minute)

**Commands:**
```powershell
# Test all environments
flyway testConnection -environment=development
flyway testConnection -environment=shadow
flyway testConnection -environment=test
flyway testConnection -environment=production
```

**Quick script:**
```powershell
@("development", "shadow", "test", "production") | ForEach-Object {
    Write-Host "Testing $_..." -ForegroundColor Cyan
    flyway testConnection -environment=$_
    Write-Host ""
}
```

### Part 3: Troubleshooting (30 seconds)

**Common issues:**
| Error | Check |
|-------|-------|
| Connection refused | Server running? Firewall? |
| Login failed | Credentials correct? |
| Database not found | Database name correct? |
| Timeout | Network connectivity? |

### Closing (20 seconds)
"Use `testConnection` at the start of your deployment pipeline to fail fast if there are connectivity issues. It's a simple command that can save significant troubleshooting time later."

---

## Commands Summary

```powershell
# Test specific environment
flyway testConnection -environment=production

# Test default environment
flyway testConnection
```

## CI/CD Integration

```yaml
steps:
  - name: Test Database Connection
    run: flyway testConnection -environment=production
    
  - name: Run Migrations
    run: flyway migrate -environment=production
```

## Troubleshooting Connection Strings

Verify your flyway.toml:
```toml
[environments.production]
url = "jdbc:sqlserver://server:1433;databaseName=ProdDB;encrypt=true;trustServerCertificate=true"
user = "${DB_USER}"
password = "${DB_PASSWORD}"
```

Check:
- Server hostname/IP
- Port number
- Database name
- Authentication settings
- Encryption requirements
