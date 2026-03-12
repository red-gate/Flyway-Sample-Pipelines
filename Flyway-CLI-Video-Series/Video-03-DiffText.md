# Video 03: Visualizing Changes with `flyway diffText`

## Overview
Learn how to use `flyway diffText` to see the actual SQL differences between sources.

## Duration
3-5 minutes

## Learning Objectives
- Understand when to use diffText vs diff
- View actual SQL changes
- Filter diffText output to specific changes

---

## Script

### Intro (20 seconds)
"While `flyway diff` shows you WHAT changed, `flyway diffText` shows you HOW it changed. This command displays the actual SQL code differences, making it perfect for code review and understanding the impact of changes."

### Part 1: Basic diffText Usage (1.5 minutes)

**Talking Points:**
- diffText uses the same source/target parameters as diff
- Output is formatted like a traditional diff (--- and +++ notation)
- Green (+) lines are additions, Red (-) lines are removals

**Command:**
```powershell
flyway diffText "-diff.source=development" "-diff.target=schemaModel"
```

**Expected Output:**
```
--- none
+++ Schema/Sales (PwXWuQdzc56HshulrPGy0QFAdOA)
CREATE SCHEMA [Sales]
AUTHORIZATION [dbo]
GO
--- none
+++ Table/Sales.Products (cesR4V7ULE8it4G_ftbKCMoII8E)
CREATE TABLE [Sales].[Products]
(
[ProductId] [int] NOT NULL IDENTITY(1, 1),
[ProductName] [nvarchar] (100) NOT NULL,
[Price] [decimal] (10, 2) NOT NULL,
[CreatedDate] [datetime2] NULL DEFAULT (getdate())
)
GO
ALTER TABLE [Sales].[Products] ADD CONSTRAINT [PK__Products__B40CC6CD...]
PRIMARY KEY CLUSTERED ([ProductId])
GO
```

**Explain the output:**
- `--- none` means the object doesn't exist in the target
- `+++ Table/Sales.Products` shows what's being added
- The change ID in parentheses matches the diff output
- Full SQL DDL is displayed

### Part 2: Filtering to Specific Changes (1.5 minutes)

**Talking Points:**
- You can filter output to specific change IDs
- Useful when you only want to see certain objects
- Get change IDs from the `flyway diff` output first

**Commands:**
```powershell
# First, run diff to see change IDs
flyway diff "-diff.source=development" "-diff.target=schemaModel"

# Then view specific changes (use actual IDs from your diff)
flyway diffText "-diff.source=development" "-diff.target=schemaModel" "-diffText.changes=cesR4V7ULE8it4G_ftbKCMoII8E"

# Multiple changes (comma-separated)
flyway diffText "-diff.source=development" "-diff.target=schemaModel" "-diffText.changes=id1,id2,id3"
```

### Part 3: Edit vs Add Visualization (1 minute)

**Talking Points:**
- For edits, diffText shows before and after
- Very helpful for column additions or type changes

**Example Edit Output:**
```
--- Table/Sales.Products (BEFORE)
CREATE TABLE [Sales].[Products]
(
[ProductId] [int] NOT NULL IDENTITY(1, 1),
[ProductName] [nvarchar] (100) NOT NULL,
[Price] [decimal] (10, 2) NOT NULL
)
+++ Table/Sales.Products (AFTER) (6uis6n8KHjZqPA6awLHbPs4BGHY)
CREATE TABLE [Sales].[Products]
(
[ProductId] [int] NOT NULL IDENTITY(1, 1),
[ProductName] [nvarchar] (100) NOT NULL,
[Price] [decimal] (10, 2) NOT NULL,
[Category] [nvarchar] (50) NULL        <-- New column!
)
```

### Closing (20 seconds)
"Use `diffText` whenever you need to understand the exact SQL impact of your changes. It's invaluable for code reviews and verifying that your changes are correct before generating migrations."

---

## Commands Summary

```powershell
# View all differences as SQL
flyway diffText "-diff.source=development" "-diff.target=schemaModel"

# View specific changes only
flyway diffText "-diff.source=development" "-diff.target=schemaModel" "-diffText.changes=changeId1,changeId2"

# Compare schema model to migrations
flyway diffText "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
```

## Workflow Tip

A typical workflow:
1. `flyway diff` - See what changed (get change IDs)
2. `flyway diffText` - Review the actual SQL
3. `flyway model` / `flyway generate` - Act on the changes

## Output Formats

| Prefix | Meaning |
|--------|---------|
| `--- none` | Object doesn't exist in source |
| `+++ Type/Name` | Object being added to target |
| `--- Type/Name` | Object being removed from target |
| Shows both | Object being modified (edit) |
