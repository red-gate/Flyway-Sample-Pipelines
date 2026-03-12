# Video 09: Preparing Deployment Scripts with `flyway prepare`

## Overview
Learn how to use `flyway prepare` to generate deployment scripts for review before execution.

## Duration
5-7 minutes

## Learning Objectives
- Understand the prepare command purpose
- Generate deployment scripts
- Review scripts before deployment
- Compare prepare vs migrate workflows

---

## Script

### Intro (30 seconds)
"In production environments, you often can't run migrations directly - you need a script that can be reviewed and executed by a DBA. `flyway prepare` creates exactly that: a single deployment script containing all pending migrations."

### Part 1: Why Use Prepare? (1 minute)

**Talking Points:**
- **Audit requirement**: Many organizations require script review
- **Change control**: Scripts go through approval process
- **Rollback planning**: Review before committing to changes
- **DBA workflow**: DBAs execute scripts, not Flyway directly

**Prepare vs Migrate:**
| Prepare | Migrate |
|---------|---------|
| Generates script file | Executes directly |
| No database changes | Changes database |
| For review/approval | For automated deployment |
| Executed separately | All-in-one |

### Part 2: Basic Prepare Usage (2 minutes)

**Command:**
```powershell
flyway prepare "-prepare.source=migrations" "-prepare.target=test" "-prepare.scriptFilename=deploy_test.sql"
```

**Expected Output:**
```
Dry Run: Database will NOT be modified
Successfully validated 3 migrations
Current version of schema [dbo]: 001.20260312155434
Migrating schema [dbo] to version "002.20260312155616 - Add Category Column"
Migrating schema [dbo] to version "003.20260312160000 - Add Index"
Successfully applied 2 migrations
Generated: C:\project\deploy_test.sql
```

### Part 3: Examining the Deployment Script (1.5 minutes)

**Command:**
```powershell
Get-Content "deploy_test.sql"
```

**Example Content:**
```sql
-- -====================================
-- Flyway Dry Run (2026-03-12 15:56:34)
-- -====================================

USE [TestDB]
GO
SET ANSI_NULLS ON
GO

-- Executing: migrate -> v002.20260312155616 (with callbacks)
-- ----------------------------------------------------------------

-- Source: migrations\V002_20260312155616__Add_Category_Column.sql
-- ----------------------------------------------------------------
SET NUMERIC_ROUNDABORT OFF
GO
PRINT N'Altering [Sales].[Products]'
GO
ALTER TABLE [Sales].[Products] ADD
[Category] [nvarchar] (50) NULL
GO
INSERT INTO [TestDB].[dbo].[flyway_schema_history] 
([installed_rank], [version], [description], [type], [script], 
 [checksum], [installed_by], [execution_time], [success]) 
VALUES (2, '002.20260312155616', 'Add Category Column', 'SQL', 
 'V002_20260312155616__Add_Category_Column.sql', 817759480, 
 'deployer', 11, 1)
GO
```

**Key elements:**
- Header with timestamp
- USE statement for database context
- Actual migration DDL
- Schema history INSERT (tracks the migration)

### Part 4: Prepare from Schema Model (1 minute)

**Alternative workflow - compare-based prepare:**
```powershell
# Generate from schema model comparison
flyway prepare "-prepare.source=schemaModel" "-prepare.target=test" "-prepare.scriptFilename=deploy_compare.sql"
```

**Use cases:**
- Schema model is authoritative source
- Want to see full change, not just migrations
- Drift detection/correction

### Closing (30 seconds)
"With `prepare`, you get the benefits of Flyway's migration tracking while maintaining full control over what gets executed. Send this script through your change control process, then use `flyway deploy` to execute it. Let's learn about deploy next!"

---

## Commands Summary

```powershell
# Prepare from migrations
flyway prepare "-prepare.source=migrations" "-prepare.target=production" "-prepare.scriptFilename=deploy_prod.sql"

# Prepare from schema model
flyway prepare "-prepare.source=schemaModel" "-prepare.target=production" "-prepare.scriptFilename=deploy_schema.sql"

# Prepare with specific version target
flyway prepare "-prepare.source=migrations" "-prepare.target=production" "-prepare.scriptFilename=deploy.sql" "-target=003"
```

## Production Workflow

```powershell
# 1. Generate deployment script
flyway prepare "-prepare.source=migrations" "-prepare.target=production" "-prepare.scriptFilename=deploy_v005.sql"

# 2. Review the script (or send for DBA review)
Get-Content deploy_v005.sql

# 3. Execute via flyway deploy (or DBA runs manually)
flyway deploy "-deploy.scriptFilename=deploy_v005.sql" -environment=production
```

## Prepare Output Contents

The generated script includes:
1. **Header comments** - Timestamp, source info
2. **USE statements** - Database context
3. **Migration SQL** - Actual DDL/DML
4. **History inserts** - Tracking records
5. **Callbacks** - If configured
