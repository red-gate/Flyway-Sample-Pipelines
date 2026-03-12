# Video 14: Undoing Migrations with `flyway undo`

## Overview
Learn how to use `flyway undo` to roll back the most recently applied migration.

## Duration
5-7 minutes

## Learning Objectives
- Understand undo migrations
- Create undo scripts
- Execute undo command
- Plan for rollback scenarios

---

## Script

### Intro (30 seconds)
"Sometimes you need to roll back a migration - maybe it caused issues or was deployed to the wrong environment. `flyway undo` reverses the most recently applied migration using a companion undo script."

### Part 1: Understanding Undo Migrations (1.5 minutes)

**Talking Points:**
- Teams/Enterprise feature
- Requires companion undo scripts
- Naming: `U{version}__description.sql`
- Only undoes ONE migration at a time
- Must be run multiple times for multiple rollbacks

**Migration pairs:**
```
migrations/
├── V002__Add_Category_Column.sql    # Forward migration
├── U002__UNDO_Add_Category.sql      # Undo migration
├── V003__Add_Index.sql
├── U003__UNDO_Add_Index.sql
```

### Part 2: Creating Undo Scripts (2 minutes)

**Option 1: Automatic generation (configure in flyway.toml)**
```toml
[flywayDesktop.generate]
undoScripts = true
```

**Option 2: Manual creation**

Forward migration (V002):
```sql
-- V002__Add_Category_Column.sql
ALTER TABLE [Sales].[Products] ADD [Category] NVARCHAR(50);
```

Undo migration (U002):
```sql
-- U002__UNDO_Add_Category.sql
ALTER TABLE [Sales].[Products] DROP COLUMN [Category];
```

**Important:**
- Undo scripts should reverse the forward migration exactly
- Test undo scripts before needing them!
- Some changes are difficult to undo (data loss)

### Part 3: Executing Undo (1.5 minutes)

**Command:**
```powershell
flyway undo -environment=test
```

**Expected Output:**
```
Database: jdbc:sqlserver://localhost;databaseName=TestDB...
Current version of schema [dbo]: 003.20260312160000
Undoing migration of schema [dbo] to version 003.20260312160000 - Add Index
Successfully undid 1 migration to schema [dbo] (execution time 00:00.025s)
```

**Verify:**
```powershell
flyway info -environment=test
# Now shows v003 as "Undone"
```

### Part 4: Multiple Undos (1 minute)

**To undo multiple migrations:**
```powershell
# Undo v003
flyway undo -environment=test

# Undo v002
flyway undo -environment=test

# Undo v001 (if undo script exists)
flyway undo -environment=test
```

**Check status after each:**
```powershell
flyway info -environment=test
```

### Part 5: Undo Limitations (30 seconds)

**Cannot undo:**
- Migrations without undo scripts
- Data changes (INSERT/UPDATE/DELETE) - data may be lost
- Baseline migrations

**Best practices:**
- Create undo scripts for all migrations
- Test undos in non-production first
- Consider: is deploying a fix faster than undo?

### Closing (30 seconds)
"Undo provides a safety net, but plan for it before you need it. Create and test undo scripts as part of your development process. In our final video, we'll cover `flyway testConnection` for verifying database connectivity."

---

## Commands Summary

```powershell
# Undo most recent migration
flyway undo -environment=test

# Undo multiple (run multiple times)
flyway undo -environment=test
flyway undo -environment=test
```

## Undo Script Naming

| Forward | Undo |
|---------|------|
| V001__Create_Table.sql | U001__UNDO_Create_Table.sql |
| V002__Add_Column.sql | U002__UNDO_Add_Column.sql |
| V003__Create_Procedure.sql | U003__UNDO_Create_Procedure.sql |

## Common Undo Patterns

| Forward Action | Undo Action |
|----------------|-------------|
| CREATE TABLE | DROP TABLE |
| ADD COLUMN | DROP COLUMN |
| CREATE INDEX | DROP INDEX |
| CREATE VIEW | DROP VIEW |
| INSERT data | DELETE data (if possible) |
| ALTER TYPE | ALTER back (may need tricks) |

## Enable Auto-Generation

```toml
[flywayDesktop.generate]
undoScripts = true
```

Now `flyway generate` creates both V and U scripts.

## Teams/Enterprise Feature

Undo requires Flyway Teams or Enterprise edition. Community edition does not support:
- `flyway undo` command
- Undo script processing
