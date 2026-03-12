# Video 08: Validating Migrations with `flyway validate`

## Overview
Learn how to use `flyway validate` to verify migration integrity and catch issues early.

## Duration
3-5 minutes

## Learning Objectives
- Understand what validate checks
- Catch modified migration scripts
- Handle validation failures
- Configure validation rules

---

## Script

### Intro (20 seconds)
"`flyway validate` is your safety check - it ensures that the migrations in your folder match what was applied to the database. This catches accidental modifications and checksum mismatches before they cause problems."

### Part 1: What Validate Checks (1 minute)

**Talking Points:**
- **Checksums**: Verifies script content hasn't changed
- **Naming**: Confirms migration names are valid
- **Order**: Checks version number sequence
- **Completeness**: All applied migrations still exist

**Why this matters:**
- Someone might accidentally edit a migration that's already applied
- Script could be corrupted or modified
- Migration files could be deleted
- Prevents "works on my machine" issues

### Part 2: Basic Validate Usage (1 minute)

**Command:**
```powershell
flyway validate -environment=test
```

**Successful Output:**
```
Successfully validated 2 migrations (execution time 00:00.052s)
```

**Failed Output (modified script):**
```
ERROR: Validate failed: Migrations have failed validation
Migration checksum mismatch for migration version 001.20260312155434
-> Applied to database : -123456789
-> Resolved locally    : 987654321
Either revert the changes to the migration or repair the database.
```

### Part 3: Handling Validation Failures (1.5 minutes)

**Scenario 1: Accidental modification**
```powershell
# Someone edited V001__Initial_Schema.sql after it was applied
flyway validate -environment=test
# ERROR: checksum mismatch

# Solution: Revert the file to original
git checkout migrations/V001_20260312155434__Initial_Schema.sql
flyway validate -environment=test
# Successfully validated
```

**Scenario 2: Intentional change (use repair)**
```powershell
# You intentionally fixed a comment - want to update checksum
flyway repair -environment=test
# Updates checksums in schema_history

flyway validate -environment=test
# Successfully validated
```

**Scenario 3: Ignore pending migrations**
```powershell
# Only validate applied migrations
flyway validate -environment=test "-ignoreMigrationPatterns=*:pending"
```

### Closing (20 seconds)
"Run `validate` as part of your CI/CD pipeline to catch issues early. It's a quick command that can save hours of debugging. Up next, we'll learn about `flyway prepare` for creating deployment scripts."

---

## Commands Summary

```powershell
# Basic validation
flyway validate -environment=test

# Ignore pending migrations
flyway validate -environment=test "-ignoreMigrationPatterns=*:pending"

# Fix validation failures (repair checksums)
flyway repair -environment=test
```

## Common Validation Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Checksum mismatch | Script modified | Revert or repair |
| Missing migration | File deleted | Restore file |
| Future migration | Applied but no file | Investigate |
| Invalid version | Bad naming | Rename file correctly |

## Best Practice: CI/CD Integration

```yaml
# Example pipeline step
- name: Validate migrations
  run: flyway validate -environment=production
  
# Fails pipeline if validation fails
# Prevents deploying modified scripts
```
