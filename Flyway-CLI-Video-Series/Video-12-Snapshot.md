# Video 12: Creating Snapshots with `flyway snapshot`

## Overview
Learn how to use `flyway snapshot` to capture database states for comparison and provisioning.

## Duration
5-7 minutes

## Learning Objectives
- Understand snapshot use cases
- Create snapshots from different sources
- Use snapshots for drift detection
- Provision from snapshots

---

## Script

### Intro (30 seconds)
"A snapshot is a point-in-time capture of your database schema. `flyway snapshot` lets you save this state to a file, which can then be used for comparisons, drift detection, and even provisioning environments."

### Part 1: What is a Snapshot? (1 minute)

**Talking Points:**
- A binary file capturing complete schema state
- Contains all objects: tables, views, procedures, etc.
- **Important:** Captures schema structure only, NOT data
- Can be used as a diff source/target

**Key Limitation:**
- Snapshots capture DDL (CREATE statements), not DML (INSERT/data)
- The flyway_schema_history table structure is captured, but NOT the migration history records
- Provisioning from a snapshot creates an empty schema_history table - you lose version history

**Use cases:**
- **Drift detection**: Compare production to expected state
- **Provisioning**: Restore databases from snapshot
- **Baselining**: Capture state before major changes
- **Archiving**: Save historical schema versions

### Part 2: Creating a Snapshot from Database (1.5 minutes)

**Command:**
```powershell
flyway snapshot "-snapshot.source=production" "-snapshot.filename=prod_v002.snp"
```

**Expected Output:**
```
Snapshot successfully written to location with path "prod_v002.snp"
```

**What's captured:**
- All database objects (tables, views, stored procedures, etc.)
- Object definitions (CREATE statements / DDL only)
- **NOT captured:** Table data, including migration history records

### Part 3: Creating Snapshot from Schema Model (1 minute)

**Command:**
```powershell
flyway snapshot "-snapshot.source=schemaModel" "-snapshot.filename=model_snapshot.snp"
```

**Use case:**
- Save the "expected" state from version control
- Compare against actual databases for drift

### Part 4: Using Snapshots for Drift Detection (1.5 minutes)

**Talking Points:**
- Compare a live database to a saved snapshot
- Detect unauthorized changes (drift)
- Critical for production monitoring

**Workflow:**
```powershell
# 1. Save expected state after deployment
flyway snapshot "-snapshot.source=production" "-snapshot.filename=prod_baseline.snp"

# 2. Later, check for drift
flyway diff "-diff.source=production" "-diff.target=snapshot" "-diff.targetSnapshot=prod_baseline.snp"
```

**If drift detected:**
```
+-----------------------------+--------+-------------+--------+----------------+
| Id                          | Change | Object Type | Schema | Name           |
+-----------------------------+--------+-------------+--------+----------------+
| xxx123                      | Add    | Table       | dbo    | unauthorized   |
+-----------------------------+--------+-------------+--------+----------------+
```

### Part 5: Snapshot Provisioning (1 minute)

**Critical Warning:**
When provisioning from a snapshot, the flyway_schema_history table is created but **empty**. You must specify a `snapshotVersion` to tell Flyway what version the provisioned database represents.

**Configuration in flyway.toml:**
```toml
[environments.dev]
url = "jdbc:sqlserver://localhost;databaseName=DevDB;..."
provisioner = "snapshot"

[environments.dev.resolvers.snapshot]
snapshotFilePath = "baseline.snp"
snapshotVersion = "005"  # Required! Tells Flyway what version this represents
```

**Why snapshotVersion matters:**
- Snapshot contains NO migration history data
- Without snapshotVersion, Flyway won't know which migrations have been applied
- Flyway will insert a baseline record at this version when provisioning

### Closing (30 seconds)
"Snapshots are your time machine for database **schemas** - not data. They capture structure, not content. Use them to track drift and provision environments, but remember: when provisioning, always specify the snapshotVersion so Flyway knows which migrations have been applied. Next, we'll learn about `flyway baseline` for working with existing databases."

---

## Commands Summary

```powershell
# Snapshot from database
flyway snapshot "-snapshot.source=production" "-snapshot.filename=prod.snp"

# Snapshot from schema model
flyway snapshot "-snapshot.source=schemaModel" "-snapshot.filename=model.snp"

# Drift detection using snapshot
flyway diff "-diff.source=production" "-diff.target=snapshot" "-diff.targetSnapshot=baseline.snp"
```

## Snapshot Use Cases

| Scenario | Workflow |
|----------|----------|
| Drift detection | Snapshot after deploy, compare later |
| Provisioning | Use snapshot to restore dev/test |
| Archiving | Save snapshots at releases |
| Comparison baseline | Snapshot before major changes |

## Enterprise Feature

Snapshots require Flyway Enterprise Edition for:
- Creating snapshots
- Provisioning from snapshots
- Advanced comparison features
