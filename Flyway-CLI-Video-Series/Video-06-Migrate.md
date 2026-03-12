# Video 06: Applying Migrations with `flyway migrate`

## Overview
Learn how to use `flyway migrate` to apply pending migrations to your databases.

## Duration
5-7 minutes

## Learning Objectives
- Understand how migrate works
- Apply migrations to different environments
- Target specific versions
- Handle common migration scenarios

---

## Script

### Intro (30 seconds)
"The `flyway migrate` command is where the magic happens - it takes your migration scripts and applies them to your database, transforming it to the desired state. Let's learn how to use it safely and effectively."

### Part 1: How Migrate Works (1.5 minutes)

**Talking Points:**
- Flyway tracks applied migrations in `flyway_schema_history` table
- Compares scripts in your migrations folder to what's already applied
- Only runs migrations that haven't been applied yet (pending)
- Applies migrations in version order

**The schema history table:**
```sql
SELECT version, description, type, installed_on, success
FROM flyway_schema_history;
```

| version | description | type | installed_on | success |
|---------|-------------|------|--------------|---------|
| 001.20260312... | Initial Schema | SQL | 2026-03-12 | 1 |

### Part 2: Basic Migrate Usage (1.5 minutes)

**Commands:**
```powershell
# Migrate the test environment
flyway migrate -environment=test
```

**Expected Output:**
```
Database: jdbc:sqlserver://localhost;databaseName=TestDB...
Schema history table [TestDB].[dbo].[flyway_schema_history] does not exist yet
Successfully validated 2 migrations (execution time 00:00.028s)
Creating Schema History table [TestDB].[dbo].[flyway_schema_history] ...
Current version of schema [dbo]: << Empty Schema >>
Migrating schema [dbo] to version "001.20260312155434 - Initial Schema"
Creating schemas
Creating [Sales].[Customers]
Creating [Sales].[Products]
Creating [Sales].[ProductSummary]
Successfully applied 1 migration to schema [dbo], now at version v001.20260312155434
```

**Key points:**
- Creates schema history table if it doesn't exist
- Shows each object being created
- Reports final version number

### Part 3: Migrating Different Environments (1 minute)

**Commands:**
```powershell
# Development environment
flyway migrate -environment=development

# Test environment
flyway migrate -environment=test

# Shadow environment (typically uses provisioner)
flyway migrate -environment=shadow

# Production environment
flyway migrate -environment=production
```

**Important:** Environments are defined in your `flyway.toml`:
```toml
[environments.test]
url = "jdbc:sqlserver://server;databaseName=TestDB;..."

[environments.production]
url = "jdbc:sqlserver://prodserver;databaseName=ProdDB;..."
```

### Part 4: Targeting Specific Versions (1 minute)

**Talking Points:**
- By default, migrate applies ALL pending migrations
- Use `-target` to stop at a specific version
- Useful for staged deployments or testing

**Commands:**
```powershell
# Migrate up to version 003 only
flyway migrate -environment=test "-target=003"

# Migrate to latest
flyway migrate -environment=test
```

### Part 5: Incremental Migrations (1 minute)

**Scenario:** You have 5 migrations, test DB is at v003

**Commands:**
```powershell
# Check current state
flyway info -environment=test
# Shows: v001 Success, v002 Success, v003 Success, v004 Pending, v005 Pending

# Apply remaining migrations
flyway migrate -environment=test
# Only v004 and v005 will be applied
```

### Closing (30 seconds)
"Migrate is the deployment workhorse of Flyway. Combined with the schema history table, it ensures your databases are always at the right version. In the next video, we'll learn how to check migration status with `flyway info`."

---

## Commands Summary

```powershell
# Basic migrate
flyway migrate -environment=test

# Migrate to specific version
flyway migrate -environment=test "-target=003"

# Migrate with verbose output
flyway migrate -environment=test -X

# Check what would be migrated (dry run via info)
flyway info -environment=test
```

## Understanding Migration States

After migrate, check `flyway info`:

| State | Meaning |
|-------|---------|
| Success | Migration applied successfully |
| Pending | Migration not yet applied |
| Failed | Migration failed (needs repair) |
| Future | Applied migration no longer in folder |

## Common Scenarios

### New Database
```powershell
flyway migrate -environment=newenv
# Creates schema history table
# Applies all migrations from V001
```

### Existing Database
```powershell
flyway migrate -environment=existingenv
# Only applies pending migrations
# Skips already-applied versions
```

### Out of Order Migrations
With `outOfOrder = true` in flyway.toml:
```powershell
# Team member committed V005 before V004
# Both will be applied in order
flyway migrate -environment=test
```

## Safety Tips

1. **Always check info first** - See what will be applied
2. **Use prepare for production** - Generate deployment script for review
3. **Backup before production migrate** - Safety net
4. **Test in lower environments first** - Catch issues early
