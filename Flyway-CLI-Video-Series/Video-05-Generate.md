# Video 05: Generating Migrations with `flyway generate`

## Overview
Learn how to use `flyway generate` to create versioned migration scripts from your changes.

## Duration
9-12 minutes

## Learning Objectives
- Understand the migration generation workflow
- Generate migrations from diff artifacts
- Customize migration descriptions
- Generate specific changes vs all changes
- Use `-generate.types` to control which script types are produced
- Generate a baseline script that builds the entire schema from scratch
- Generate paired versioned and undo (rollback) scripts

---

## Script

### Intro (30 seconds)
"Migration scripts are the heart of database version control - they contain the SQL commands that transform your database from one version to the next. In this video, we'll learn how `flyway generate` creates these scripts automatically."

### Part 1: Understanding the Generate Workflow (1.5 minutes)

**Talking Points:**
- Generate uses a diff artifact to create migration scripts
- Typically compares schema model (or development) to migrations
- Requires a shadow/build environment to determine what's already scripted
- Creates properly named versioned migration files

**The workflow:**
1. Make changes in development database
2. Run `flyway diff` (schemaModel → migrations with buildEnvironment)
3. Run `flyway generate` to create the script
4. Script appears in migrations folder

### Part 2: Basic Generate Usage (2 minutes)

**Commands:**
```powershell
# Step 1: Ensure schema model is up to date
flyway diff "-diff.source=development" "-diff.target=schemaModel"
flyway model

# Step 2: Create diff artifact for generate
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

# Step 3: Generate the migration
flyway generate "-generate.description=Add_Sales_Schema"
```

**Expected Output:**
```
Using diff artifact: C:\...\flyway.artifact.diff
Generating versioned migration: migrations\V001_20260312155434__Add_Sales_Schema.sql
Generated: migrations\V001_20260312155434__Add_Sales_Schema.sql
```

### Part 3: Understanding Generated File Names (1 minute)

**File naming pattern:**
```
V{version}_{timestamp}__{description}.sql
```

**Example:** `V001_20260312155434__Initial_Schema.sql`

| Part | Meaning |
|------|---------|
| `V` | Versioned migration prefix |
| `001` | Version number |
| `20260312155434` | Timestamp (YYYYMMDDHHMMSS) |
| `__` | Double underscore separator |
| `Initial_Schema` | Your description (underscores for spaces) |
| `.sql` | SQL file extension |

### Part 4: Viewing the Generated Script (1.5 minutes)

**Command:**
```powershell
Get-Content "migrations\V001_20260312155434__Add_Sales_Schema.sql"
```

**Example Generated Content:**
```sql
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Creating schemas'
GO
IF SCHEMA_ID(N'Sales') IS NULL
EXEC sp_executesql N'CREATE SCHEMA [Sales]
AUTHORIZATION [dbo]'
GO
PRINT N'Creating [Sales].[Products]'
GO
CREATE TABLE [Sales].[Products]
(
[ProductId] [int] NOT NULL IDENTITY(1, 1),
[ProductName] [nvarchar] (100) NOT NULL,
[Price] [decimal] (10, 2) NOT NULL,
[CreatedDate] [datetime2] NULL DEFAULT (getdate())
)
GO
-- ... more statements
```

**Key features:**
- SET statements for consistent behavior
- PRINT statements for progress visibility
- Existence checks where appropriate
- Proper GO batch separators

### Part 5: Generating Specific Changes (1.5 minutes)

**Talking Points:**
- Use `-generate.changes` to create scripts for specific objects only
- Get change IDs from the diff output

**Commands:**
```powershell
# View available changes
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

# Generate for specific changes only
flyway generate "-generate.changes=cesR4V7ULE8it4G_ftbKCMoII8E" "-generate.description=Add_Products_Table"

# Exclude dependent objects
flyway generate "-generate.changes=changeId" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false" "-generate.description=My_Change"
```

### Part 6: Controlling Script Types with `-generate.types` (2.5 minutes)

**Talking Points:**
- `-generate.types` controls *which kinds* of scripts `flyway generate` produces
- Accepts a comma-separated list of: `versioned`, `undo`, `baseline`
- Defaults to `versioned` when omitted
- Each type answers a different question:
  - `versioned` - "What changed?" → the incremental migration that moves you forward
  - `undo` - "How do I roll this change back?" → the paired reverse script
  - `baseline` - "How do I represent the schema that already exists?" → a full-schema starting point

**Generating a baseline script (import an existing production schema):**
When you adopt Flyway on a database that's *already* in production, you don't want to
re-create those objects on deploy - production already has them. A baseline represents
the existing production schema as a starting point in version control. Flyway marks that
point as already-applied on production, so every versioned migration you generate afterwards
sits *on top* of the baseline and deploys cleanly to production.

A baseline can take several forms - a backup file, a snapshot (see Video 12), or a SQL
script. Here we're generating the **baseline script** form: a single SQL file that builds
the full existing schema.

```powershell
# Point the schema model at your live production database, then capture it
flyway diff "-diff.source=production" "-diff.target=schemaModel"
flyway model

# Generate a baseline script that represents the existing production schema
flyway generate "-generate.types=baseline" "-generate.description=Production_Baseline"
```

**Expected Output:**
```
Using diff artifact: C:\...\flyway.artifact.diff
Generating baseline migration: migrations\B001_20260312160122__Production_Baseline.sql
Generated: migrations\B001_20260312160122__Production_Baseline.sql
```

> Note the `B` prefix - baseline scripts use `B` instead of `V`. On production, Flyway
> treats the baseline as already-applied (it isn't re-run), so subsequent versioned
> migrations build on top of it and deploy without trying to re-create existing objects.

**Generating versioned + undo together (forward and rollback):**
Asking for both types in one command keeps your forward migration and its rollback
in lockstep - the undo script reverses exactly what the versioned script applies.

```powershell
# Standard diff for what needs scripting
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

# Generate the versioned migration AND its matching undo script
flyway generate "-generate.types=versioned,undo" "-generate.description=Add_Sales_Schema"
```

**Expected Output:**
```
Generating versioned migration: migrations\V002_20260312160233__Add_Sales_Schema.sql
Generating undo migration:      migrations\U002_20260312160233__Add_Sales_Schema.sql
Generated 2 files
```

> The undo script uses the `U` prefix and shares the version number of its versioned
> partner, so `flyway undo` knows which forward migration it reverses.

**Script type prefixes at a glance:**

| Prefix | Type | Purpose |
|--------|------|---------|
| `V` | Versioned | Apply the change going forward |
| `U` | Undo | Roll the change back |
| `B` | Baseline | Represent the existing schema to build on top of |

### Part 7: Custom Output Location (30 seconds)

**Command:**
```powershell
# Generate to a different folder
flyway generate "-generate.location=C:\temp\pending-migrations" "-generate.description=My_Migration"
```

### Closing (30 seconds)
"You've now generated your first migration script! This script can be applied to any database using `flyway migrate`. Remember the workflow: diff, then generate. In the next video, we'll learn how to apply these migrations to target databases."

---

## Commands Summary

```powershell
# Standard generate workflow
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
flyway generate "-generate.description=My_Description"

# Generate specific changes only
flyway generate "-generate.changes=id1,id2" "-generate.description=Specific_Changes"

# Exclude dependencies
flyway generate "-generate.changes=id" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false" "-generate.description=My_Change"

# Generate a baseline script (import an existing production schema)
flyway generate "-generate.types=baseline" "-generate.description=Production_Baseline"

# Generate versioned + undo (rollback) scripts together
flyway generate "-generate.types=versioned,undo" "-generate.description=My_Change"

# Custom output location
flyway generate "-generate.location=C:\path\to\folder" "-generate.description=My_Change"
```

## Complete Development Workflow

```powershell
# 1. Update schema model from development
flyway diff "-diff.source=development" "-diff.target=schemaModel"
flyway model

# 2. Generate migration script
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
flyway generate "-generate.description=Add_New_Feature"

# 3. Apply to shadow to verify
flyway migrate -environment=shadow

# 4. Commit everything to Git
# migrations/V00X__Add_New_Feature.sql
# schema-model/* changes
```

## Tips

1. **Meaningful descriptions** - Use descriptive names that explain the change
2. **One logical change per migration** - Easier to review and troubleshoot
3. **Test before committing** - Run migrate on shadow first
4. **Review generated SQL** - Always check what was generated
