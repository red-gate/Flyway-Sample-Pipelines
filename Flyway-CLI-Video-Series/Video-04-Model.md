# Video 04: Building Your Schema Model with `flyway model`

## Overview
Learn how to use `flyway model` to update your schema-model folder with database changes.

## Duration
5-7 minutes

## Learning Objectives
- Understand what the schema model represents
- Update schema model from development database
- Apply specific changes vs all changes
- Understand the schema model folder structure

---

## Script

### Intro (30 seconds)
"The schema model is a file-based representation of your database schema - think of it as your 'source of truth' stored in version control. In this video, we'll learn how to use `flyway model` to keep it in sync with your development database."

### Part 1: What is the Schema Model? (1.5 minutes)

**Talking Points:**
- The schema model is a folder containing SQL files for each database object
- Each object (table, view, procedure) has its own .sql file
- Files contain CREATE statements representing the current state
- This is what you commit to Git - your versioned database schema

**Benefits:**
- Version control for your database structure
- Code review for schema changes
- Clear history of when objects changed
- Comparison baseline for generating migrations

### Part 2: Running flyway model (2 minutes)

**Prerequisite:**
- Must run `flyway diff` first to create the diff artifact

**Commands:**
```powershell
# Step 1: Run diff to create the artifact
flyway diff "-diff.source=development" "-diff.target=schemaModel"

# Step 2: Apply ALL changes to schema model
flyway model
```

**Expected Output:**
```
Saved to schema model
 File updated: schema-model\Security\Schemas\Sales.sql
 File updated: schema-model\Tables\Sales.Customers.sql
 File updated: schema-model\Tables\Sales.Products.sql
 File updated: schema-model\Views\Sales.ProductSummary.sql
```

### Part 3: Applying Specific Changes (1.5 minutes)

**Talking Points:**
- Often you don't want ALL changes - just specific ones
- Use `-model.changes` with change IDs from diff
- Useful when working on specific features

**Commands:**
```powershell
# Get change IDs from diff output first
flyway diff "-diff.source=development" "-diff.target=schemaModel"

# Apply only specific changes
flyway model "-model.changes=cesR4V7ULE8it4G_ftbKCMoII8E"

# Apply multiple specific changes
flyway model "-model.changes=id1,id2,id3"
```

**Important Flag:**
```powershell
# Exclude dependent objects (recommended for targeted changes)
flyway model "-model.changes=cesR4V7ULE8it4G_ftbKCMoII8E" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false"
```

### Part 4: Exploring the Schema Model Structure (1.5 minutes)

**Command:**
```powershell
Get-ChildItem -Path "schema-model" -Recurse
```

**Folder Structure:**
```
schema-model/
├── RedGateDatabaseInfo.xml      # Database metadata
├── Security/
│   └── Schemas/
│       └── Sales.sql            # Schema definition
├── Tables/
│   ├── Sales.Customers.sql      # Table definitions
│   └── Sales.Products.sql
└── Views/
    └── Sales.ProductSummary.sql # View definitions
```

**View a file:**
```powershell
Get-Content "schema-model\Tables\Sales.Products.sql"
```

**Example content:**
```sql
CREATE TABLE [Sales].[Products]
(
[ProductId] [int] NOT NULL IDENTITY(1, 1),
[ProductName] [nvarchar] (100) NOT NULL,
[Price] [decimal] (10, 2) NOT NULL,
[CreatedDate] [datetime2] NULL DEFAULT (getdate())
)
GO
ALTER TABLE [Sales].[Products] ADD CONSTRAINT [PK__Products__...]
PRIMARY KEY CLUSTERED ([ProductId])
GO
```

### Closing (30 seconds)
"Your schema model is now in sync with your development database. Commit these files to Git to version control your database schema. In the next video, we'll learn how to use `flyway generate` to create migration scripts from these changes."

---

## Commands Summary

```powershell
# Update schema model with ALL diff changes
flyway diff "-diff.source=development" "-diff.target=schemaModel"
flyway model

# Update schema model with SPECIFIC changes
flyway diff "-diff.source=development" "-diff.target=schemaModel"
flyway model "-model.changes=changeId1,changeId2"

# Exclude dependencies (recommended)
flyway model "-model.changes=changeId" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false"
```

## Best Practices

1. **Always run diff first** - model uses the diff artifact
2. **Review changes before applying** - use `flyway diffText` first
3. **Commit frequently** - small, focused commits are easier to review
4. **Exclude dependencies for targeted changes** - prevents unintended updates
5. **Use with version control** - the schema model should be in Git

## Schema Model vs Migrations

| Schema Model | Migrations |
|-------------|------------|
| Current state (CREATE statements) | Change history (ALTER statements) |
| One file per object | One file per version |
| Easy to read current schema | Shows evolution over time |
| Used for comparison | Used for deployment |
