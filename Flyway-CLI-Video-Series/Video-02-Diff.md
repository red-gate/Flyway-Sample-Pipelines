# Video 02: Comparing Changes with `flyway diff`

## Overview
Learn how to use `flyway diff` to compare different sources and identify schema differences.

## Duration
5-7 minutes

## Learning Objectives
- Understand comparison sources in Flyway
- Compare development database to schema model
- Compare schema model to migrations
- Interpret diff output

---

## Script

### Intro (30 seconds)
"In this video, we'll explore the `flyway diff` command - one of the most powerful features in Flyway. Diff allows you to compare different sources like databases, schema models, and migrations to identify exactly what has changed."

### Part 1: Understanding Comparison Sources (1.5 minutes)

**Talking Points:**
Flyway can compare between multiple source types:

| Source Type | Description |
|-------------|-------------|
| `development` | Your development database (live) |
| `shadow` | Build/test database |
| `schemaModel` | File-based schema representation |
| `migrations` | Applied migrations (requires buildEnvironment) |
| `empty` | An empty database state |
| `snapshot` | A saved snapshot file |

**The diff produces:**
- A list of objects that differ
- Change IDs (unique identifiers for each change)
- Change types: Add, Edit, Delete

### Part 2: Prerequisites Setup (1 minute)

**Talking Points:**
- We need objects in our development database to compare
- Let's create some sample tables first

**Setup Commands:**
```powershell
# Verify connection first
flyway testConnection -environment=development

# In SQL Server, create sample objects:
# (Show in SSMS or via sqlcmd)
```

**Sample SQL to run in development DB:**
```sql
CREATE SCHEMA Sales;
GO

CREATE TABLE Sales.Products (
    ProductId INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE Sales.Customers (
    CustomerId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255)
);

CREATE VIEW Sales.ProductSummary AS
SELECT ProductId, ProductName, Price FROM Sales.Products;
```

### Part 3: Comparing Development to Schema Model (2 minutes)

**Talking Points:**
- This is the most common diff operation
- Shows what's in your database but not in your schema model

**Command:**
```powershell
flyway diff "-diff.source=development" "-diff.target=schemaModel"
```

**Expected Output:**
```
+-----------------------------+--------+-------------+--------+----------------+
| Id                          | Change | Object Type | Schema | Name           |
+-----------------------------+--------+-------------+--------+----------------+
| PwXWuQdzc56HshulrPGy0QFAdOA | Add    | Schema      |        | Sales          |
| jtJGiu461jOkRty3A83UVHNNlz8 | Add    | Table       | Sales  | Customers      |
| cesR4V7ULE8it4G_ftbKCMoII8E | Add    | Table       | Sales  | Products       |
| 3uM3sT8WCuqMmlq8KhZ3J8Z66Fs | Add    | View        | Sales  | ProductSummary |
+-----------------------------+--------+-------------+--------+----------------+
```

**Explain each column:**
- **Id**: Unique hash for this change (used by other commands)
- **Change**: Add, Edit, or Delete
- **Object Type**: Table, View, Stored Procedure, etc.
- **Schema**: Database schema name
- **Name**: Object name

### Part 4: Comparing Schema Model to Migrations (1.5 minutes)

**Talking Points:**
- Use this to generate migration scripts
- Requires a build environment (shadow database)
- Shows what changes need to be scripted

**Command:**
```powershell
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
```

**Explain:**
- The shadow database is used to "build" the migrations
- Flyway applies all existing migrations to shadow first
- Then compares schema model to that result
- This ensures you only generate scripts for new changes

### Part 5: Other Diff Scenarios (1 minute)

**Additional examples:**

```powershell
# Compare two databases directly
flyway diff "-diff.source=development" "-diff.target=test"

# Compare to an empty database (see all objects)
flyway diff "-diff.source=development" "-diff.target=empty"

# Compare using a snapshot
flyway diff "-diff.source=development" "-diff.target=snapshot" "-diff.targetSnapshot=baseline.snp"
```

### Closing (30 seconds)
"The `flyway diff` command is your tool for understanding what has changed. The change IDs it produces are essential for the next commands we'll learn - `diffText` to see the actual SQL differences, and `model` and `generate` to act on those changes."

---

## Commands Summary

```powershell
# Compare development database to schema model
flyway diff "-diff.source=development" "-diff.target=schemaModel"

# Compare schema model to migrations (for generating scripts)
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

# Compare development to migrations
flyway diff "-diff.source=development" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

# Compare two databases
flyway diff "-diff.source=development" "-diff.target=production"

# Compare to empty state
flyway diff "-diff.source=development" "-diff.target=empty"
```

## Understanding the Diff Artifact

After running diff, Flyway creates a diff artifact file:
```
diff artifact generated: C:\Users\...\flyway.artifact.diff
```

This artifact is used by subsequent commands like `diffText`, `model`, and `generate`.

## Tips

1. **Always run diff before model or generate** - The artifact must be fresh
2. **Use buildEnvironment for migrations** - Required when comparing to migrations
3. **Change IDs are unique per diff** - They change if you re-run diff
