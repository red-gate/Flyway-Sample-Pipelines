# Video 05: Generating Migrations with `flyway generate`

## Overview
Learn how to use `flyway generate` to create versioned migration scripts from your changes.

## Duration
9-12 minutes

## Learning Objectives
- Understand the migration generation workflow
- Use `-generate.types` to control which script types are produced
- Generate a baseline script that builds the entire schema from scratch (development → empty)
- Make a development change, capture it into the schema model, then generate scripts for it
- Generate paired versioned and undo (rollback) scripts
- Customize migration descriptions
- Generate specific changes vs all changes

---

## Script

### Intro (30 seconds)
"Migration scripts are the heart of database version control - they contain the SQL commands that transform your database from one version to the next. In this video, we'll learn how `flyway generate` creates these scripts automatically."

### Part 1: Understanding the Generate Workflow (1.5 minutes)

**Talking Points:**
- `flyway generate` uses a diff artifact to create migration scripts
- `-generate.types` controls *which kinds* of scripts are produced: `versioned`, `undo`, `baseline`
- A baseline gives you a starting point that builds the whole schema; versioned + undo scripts capture each change going forward and back
- When the diff target is `migrations`, you need a `buildEnvironment` - Flyway runs the existing migrations against this shadow/build database, and the resulting schema becomes the target it compares against to determine what's already scripted

**The workflow we'll follow in this video:**
1. **Start with a baseline** - generate a baseline script that builds the entire schema from scratch (development → empty)
2. **Make a change** in the development database (e.g. add a column or modify a view)
3. **Capture the change** into the schema model (`diff` development → schemaModel, then `model`)
4. **Generate versioned + undo scripts** for that change (`diff` schemaModel → migrations, then `generate`)

### Part 2: Start with a Baseline Script (2.5 minutes)

**Talking Points:**
- A baseline represents the schema that already exists, so you can build on top of it in version control
- When you adopt Flyway on a database that's *already* in production, you don't want to re-create those objects on deploy - production already has them. The baseline is treated as already-applied, and every versioned migration after it builds on top and deploys cleanly to production
- A baseline can take several forms - a backup file, a snapshot, or a SQL script. Here we generate the **baseline script** form: a single SQL file that builds the full schema
- We compare `development` (which mirrors production) against an `empty` target so *every* object is treated as new - giving us a complete from-scratch build script

**Commands:**
```powershell
# Compare development against an empty database so the whole schema is "new"
flyway diff "-diff.source=development" "-diff.target=empty"

# Generate a baseline script that builds the entire schema from scratch
flyway generate "-generate.types=baseline" "-generate.description=Baseline"

# Combining them t
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

### Part 3: Make a Change in Development (1 minute)

**Talking Points:**
- With the baseline in place, all future work is incremental
- Make a real schema change in your development database - this is what we'll script next
- Keep it small and focused so the generated migration is easy to review

**Example change (run against development):**
```sql
-- Add a column to an existing table...
ALTER TABLE [Sales].[Products] ADD [Discontinued] BIT NOT NULL DEFAULT (0)
GO

-- Modify the view
ALTER VIEW [Sales].[ProductSummary]
AS
SELECT ProductId, ProductName, Price, Discontinued
FROM Sales.Products
GO
```

### Part 4: Capture the Change into the Schema Model (1.5 minutes)

**Talking Points:**
- First bring the schema model up to date with what changed in development
- `diff` finds the difference, `model` writes it into the schema model files

**Commands:**
```powershell
# Diff development against the schema model to find your change and model to write the change into the schema model
flyway diff model "-diff.source=development" "-diff.target=schemaModel"

```

**Expected Output:**
```
Differences found between development and schemaModel
+ Sales.Products.Discontinued (column added)
~ Sales.vProductCatalog (view modified)
Schema model updated
```

### Part 5: Generate Versioned + Undo Scripts (2 minutes)

**Talking Points:**
- Now produce the deployable migration *and* its rollback in one step
- `-generate.types=versioned,undo` keeps the forward migration and its undo in lockstep - the undo reverses exactly what the versioned script applies
- The diff here compares the schema model to the existing migrations (using the shadow build environment) so only the *new* change is scripted

**Commands:**
```powershell
# Diff schema model against existing migrations to find what isn't scripted yet
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

# Generate the versioned migration AND its matching undo script
flyway generate "-generate.types=versioned,undo" "-generate.description=Add_Discontinued_Flag"
```

**Expected Output:**
```
Generating versioned migration: migrations\V002_20260312160233__Add_Discontinued_Flag.sql
Generating undo migration:      migrations\U002_20260312160233__Add_Discontinued_Flag.sql
Generated 2 files
```

> The undo script uses the `U` prefix and shares the version number of its versioned
> partner, so `flyway undo` knows which forward migration it reverses.

### Part 6: Understanding Generated File Names (1 minute)

**File naming pattern:**
```
{prefix}{version}_{timestamp}__{description}.sql
```

**Example:** `V002_20260312160233__Add_Discontinued_Flag.sql`

| Part | Meaning |
|------|---------|
| `V` | Migration prefix (see prefix table below) |
| `002` | Version number |
| `20260312160233` | Timestamp (YYYYMMDDHHMMSS) |
| `__` | Double underscore separator |
| `Add_Discontinued_Flag` | Your description (underscores for spaces) |
| `.sql` | SQL file extension |

**Script type prefixes at a glance:**

| Prefix | Type | Purpose |
|--------|------|---------|
| `V` | Versioned | Apply the change going forward |
| `U` | Undo | Roll the change back |
| `B` | Baseline | Represent the existing schema to build on top of |

### Part 7: Viewing the Generated Script (1.5 minutes)

**Command:**
```powershell
Get-Content "migrations\V002_20260312160233__Add_Discontinued_Flag.sql"
```

**Example Generated Content:**
```sql
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Altering [Sales].[Products]'
GO
ALTER TABLE [Sales].[Products] ADD [Discontinued] [bit] NOT NULL CONSTRAINT [DF_Products_Discontinued] DEFAULT (0)
GO
-- ... more statements
```

**Key features:**
- Ordered correctly - effortlessly handles complex dependencies
- For safety purposes - will pull in de-selected dependencies by default
- Warn you about potential data loss and other risky scenarios encountered when generating scripts
- Scripts will run as written - edit them if need be
- SET statements for consistent behavior
- PRINT statements for progress visibility
- Existence checks optional
- Proper GO batch separators


### Part 8: Generating Specific Changes (1.5 minutes)

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

### Part 9: Custom Output Location (30 seconds)

**Command:**
```powershell
# Generate to a different folder
flyway generate "-generate.location=C:\temp\pending-migrations" "-generate.description=My_Migration"
```

### Closing (30 seconds)
"You've now generated your first migration script! This script can be applied to any database using `flyway migrate`. Remember the workflow: initialize the project with a baseline script or backup file, then as you make changes - run diff, model, and generate to produce your versioned and undo scripts."

---

## Commands Summary

```powershell
# Generate a baseline script (full schema from scratch: development → empty)
flyway diff "-diff.source=development" "-diff.target=empty"
flyway generate "-generate.types=baseline" "-generate.description=Production_Baseline"

# Standard generate workflow (versioned only)
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
flyway generate "-generate.description=My_Description"

# Generate versioned + undo (rollback) scripts together
flyway generate "-generate.types=versioned,undo" "-generate.description=My_Change"

# Generate specific changes only
flyway generate "-generate.changes=id1,id2" "-generate.description=Specific_Changes"

# Exclude dependencies
flyway generate "-generate.changes=id" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false" "-generate.description=My_Change"

# Custom output location
flyway generate "-generate.location=C:\path\to\folder" "-generate.description=My_Change"
```

## Complete Development Workflow

```powershell
# 0. (One time) Establish a baseline for the existing schema
flyway diff "-diff.source=development" "-diff.target=empty"
flyway generate "-generate.types=baseline" "-generate.description=Production_Baseline"

# 1. Make a change in development (add a column, modify a view, etc.)

# 2. Capture the change into the schema model
flyway diff "-diff.source=development" "-diff.target=schemaModel"
flyway model

# 3. Generate versioned + undo scripts for the change
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
flyway generate "-generate.types=versioned,undo" "-generate.description=Add_New_Feature"

# 4. Apply to shadow to verify
flyway migrate -environment=shadow

# 5. Commit everything to Git
# migrations/V00X__Add_New_Feature.sql
# migrations/U00X__Add_New_Feature.sql
# schema-model/* changes
```

## Tips

1. **Meaningful descriptions** - Use descriptive names that explain the change
2. **One logical change per migration** - Easier to review and troubleshoot
3. **Test before committing** - Run migrate on shadow first
4. **Review generated SQL** - Always check what was generated
