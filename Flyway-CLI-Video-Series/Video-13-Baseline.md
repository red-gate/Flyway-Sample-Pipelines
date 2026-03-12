# Video 13: Baselining Existing Databases with `flyway baseline`

## Overview
Learn how to use `flyway baseline` to bring an existing database under Flyway control.

## Duration
7-10 minutes

## Learning Objectives
- Understand when baseline is needed
- Execute baseline command
- Handle existing databases with data
- Baseline migration workflow

---

## Script

### Intro (30 seconds)
"What if you have an existing database with years of history, and you want to start using Flyway? `flyway baseline` solves this problem by marking the database at a specific version, allowing you to manage future changes with Flyway."

### Part 1: When to Use Baseline (1.5 minutes)

**Talking Points:**
- Database exists but wasn't managed by Flyway
- Want to start version control without losing existing schema
- Moving from another migration tool to Flyway
- Recovering from a complex situation

**Scenario:**
```
Existing Production DB → Add Flyway → Continue with migrations
(v1-v10 manually applied)  (baseline at v10)  (v11+ managed by Flyway)
```

### Part 2: The Baseline Process (2 minutes)

**Step 1: Create baseline migration script**
- Capture current schema as a migration
- This represents the "starting point"

```powershell
# Generate schema from existing database
flyway snapshot "-snapshot.source=production" "-snapshot.filename=current_state.snp"

# Or capture as schema model
flyway diff "-diff.source=production" "-diff.target=empty"
flyway model
```

**Step 2: Create baseline script**
```powershell
# Create B001__baseline.sql with current schema
# This is your reference script
```

**Step 3: Run baseline command**
```powershell
flyway baseline -environment=production "-baselineVersion=001" "-baselineDescription=Initial_Baseline"
```

### Part 3: Running Baseline (1.5 minutes)

**Command:**
```powershell
flyway baseline -environment=production "-baselineVersion=001" "-baselineDescription=Initial_Baseline"
```

**Expected Output:**
```
Database: jdbc:sqlserver://prodserver;databaseName=ProdDB...
Creating Schema History table [ProdDB].[dbo].[flyway_schema_history] ...
Successfully baselined schema with version: 001
```

**What this does:**
- Creates flyway_schema_history table
- Inserts baseline marker at version 001
- Future migrations start from v002

**Verify with info:**
```powershell
flyway info -environment=production
```

```
+-----------+---------+------------------+-----------+---------------------+----------+
| Category  | Version | Description      | Type      | Installed On        | State    |
+-----------+---------+------------------+-----------+---------------------+----------+
| Baseline  | 001     | Initial_Baseline | BASELINE  | 2026-03-12 16:00:00 | Baseline |
+-----------+---------+------------------+-----------+---------------------+----------+
```

### Part 4: Baseline on Migrate (1.5 minutes)

**Talking Points:**
- Alternative: Use `baselineOnMigrate` setting
- Automatically baselines on first migrate
- Useful for automated provisioning

**Configuration:**
```toml
[flyway]
baselineOnMigrate = true
baselineVersion = "001"
baselineDescription = "Auto baseline"
```

**Behavior:**
```powershell
flyway migrate -environment=newdb
# If no schema history exists:
# 1. Creates schema history table
# 2. Baselines at configured version
# 3. Applies migrations > baseline version
```

### Part 5: Important Considerations (1 minute)

**Talking Points:**
- Baseline only creates the marker - doesn't run scripts
- Your baseline script (B001) is for documentation/rebuilding
- Make sure baseline version matches your script
- Test on non-production first!

**Migration naming:**
```
migrations/
├── B001__baseline.sql      # Baseline script (full schema)
├── V002__First_Change.sql  # Starts at v002
├── V003__Second_Change.sql
```

### Closing (30 seconds)
"Baseline is your bridge from unmanaged to managed databases. Once baselined, you have the full power of Flyway for all future changes. Up next, we'll explore `flyway undo` for rolling back migrations."

---

## Commands Summary

```powershell
# Basic baseline
flyway baseline -environment=production "-baselineVersion=001" "-baselineDescription=Initial_Baseline"

# With specific version
flyway baseline -environment=production "-baselineVersion=010" "-baselineDescription=Production_State_v10"
```

## Configuration Options

```toml
[flyway]
baselineVersion = "001"
baselineDescription = "Baseline"
baselineOnMigrate = true  # Auto-baseline on first migrate
```

## Complete Baseline Workflow

```powershell
# 1. Capture current state
flyway snapshot "-snapshot.source=production" "-snapshot.filename=baseline.snp"

# 2. Generate baseline script (manual step - save schema CREATE statements)
# Save as migrations/B001__baseline.sql

# 3. Baseline the database
flyway baseline -environment=production "-baselineVersion=001" "-baselineDescription=Production_Baseline"

# 4. Verify
flyway info -environment=production

# 5. Future migrations start at V002
```

## When NOT to Use Baseline

- Empty databases (just use migrate)
- Already managed by Flyway
- When you need to replay all migrations
