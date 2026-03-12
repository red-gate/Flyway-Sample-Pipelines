# Video 11: Managing Database Cleanup with `flyway clean`

## Overview
Learn how to use `flyway clean` to drop all objects in a database - useful for testing and development.

## Duration
5-7 minutes

## Learning Objectives
- Understand when to use clean
- Safely execute clean command
- Configure clean protection
- Use provisioner for automatic cleaning

---

## Script

### Intro (30 seconds)
"`flyway clean` is the 'nuclear option' - it drops ALL objects in your database. It's incredibly useful for testing and resetting development environments, but requires careful handling to avoid disasters."

### Part 1: What Clean Does (1 minute)

**Talking Points:**
- Drops all tables, views, procedures, functions, schemas
- Removes the flyway_schema_history table
- Leaves you with an empty database
- Cannot be undone!

**Use cases:**
- Resetting a test database
- Rebuilding from migrations
- Shadow/build database cleanup
- Starting fresh in development

**DO NOT use on:**
- Production databases
- Databases with important data
- Shared development databases (without coordination)

### Part 2: Clean Protection (1.5 minutes)

**Talking Points:**
- By default, Flyway projects have `cleanDisabled = true`
- This prevents accidental clean operations
- Must explicitly override to run clean

**Default behavior (blocked):**
```powershell
flyway clean -environment=shadow
# ERROR: flyway.cleanDisabled is set to 'true'
```

**Override to allow clean:**
```powershell
flyway clean -environment=shadow "-cleanDisabled=false"
```

### Part 3: Running Clean (1.5 minutes)

**Command:**
```powershell
flyway clean -environment=shadow "-cleanDisabled=false"
```

**Expected Output:**
```
Database: jdbc:sqlserver://localhost;databaseName=ShadowDB...
Successfully dropped pre-schema database level objects (execution time 00:00.003s)
Successfully cleaned schema [dbo] (execution time 00:00.162s)
Successfully cleaned schema [Sales] (execution time 00:00.166s)
Successfully dropped schema [Sales] (execution time 00:00.038s)
```

**Verify it's clean:**
```powershell
flyway info -environment=shadow
# Schema history table does not exist yet
```

### Part 4: Provisioner-Based Cleaning (1.5 minutes)

**Talking Points:**
- Shadow databases often use `provisioner = "clean"`
- Automatically cleaned during operations like `diff` with buildEnvironment
- No need to manually clean

**Configuration in flyway.toml:**
```toml
[environments.shadow]
url = "jdbc:sqlserver://localhost;databaseName=ShadowDB;..."
provisioner = "clean"
```

**Automatic clean happens during:**
```powershell
# Shadow is cleaned before building migrations
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
```

### Closing (30 seconds)
"Clean is a powerful tool - use it wisely. Configure your flyway.toml to protect important databases, and leverage provisioners for automatic cleanup in your workflow. Next, let's learn about `flyway snapshot` for capturing database states."

---

## Commands Summary

```powershell
# Clean with protection override
flyway clean -environment=shadow "-cleanDisabled=false"

# Cannot clean protected database
flyway clean -environment=production
# ERROR: cleanDisabled is set to 'true'
```

## Configuration

**In flyway.toml - protect all environments by default:**
```toml
[flyway]
cleanDisabled = true
```

**Environment with provisioner (auto-clean):**
```toml
[environments.shadow]
url = "jdbc:sqlserver://localhost;databaseName=ShadowDB;..."
provisioner = "clean"
```

## Clean + Migrate Workflow

```powershell
# Reset and rebuild from migrations
flyway clean -environment=shadow "-cleanDisabled=false"
flyway migrate -environment=shadow
flyway info -environment=shadow
# Shows all migrations freshly applied
```

## Safety Checklist

Before running clean:
- [ ] Verified correct environment
- [ ] No important data to lose
- [ ] Backups exist (if needed)
- [ ] Team is aware (shared DBs)
- [ ] Not a production database!
