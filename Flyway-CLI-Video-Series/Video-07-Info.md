# Video 07: Viewing Migration Status with `flyway info`

## Overview
Learn how to use `flyway info` to view the status of migrations in your databases.

## Duration
3-5 minutes

## Learning Objectives
- Check migration status across environments
- Understand migration states
- Identify pending migrations
- Troubleshoot migration issues

---

## Script

### Intro (20 seconds)
"Before deploying or after running migrations, you need to know the state of your database. `flyway info` gives you a complete picture of applied, pending, and any problematic migrations."

### Part 1: Basic Info Usage (1.5 minutes)

**Command:**
```powershell
flyway info -environment=test
```

**Expected Output:**
```
Schema version: 002.20260312155616

+-----------+--------------------+---------------------+------+---------------------+---------+----------+
| Category  | Version            | Description         | Type | Installed On        | State   | Undoable |
+-----------+--------------------+---------------------+------+---------------------+---------+----------+
| Versioned | 001.20260312155434 | Initial Schema      | SQL  | 2026-03-12 15:54:55 | Success | No       |
| Versioned | 002.20260312155616 | Add Category Column | SQL  | 2026-03-12 15:56:51 | Success | No       |
+-----------+--------------------+---------------------+------+---------------------+---------+----------+
```

**Columns explained:**
- **Category**: Versioned, Repeatable, or Baseline
- **Version**: Migration version number
- **Description**: From filename
- **Type**: SQL, BASELINE, UNDO, etc.
- **Installed On**: When migration was applied
- **State**: Success, Pending, Failed, etc.
- **Undoable**: Whether an undo script exists

### Part 2: Understanding Migration States (1.5 minutes)

**Talking Points:**

| State | Meaning | Action |
|-------|---------|--------|
| **Success** | Applied successfully | None needed |
| **Pending** | Not yet applied | Run migrate |
| **Failed** | Error during apply | Fix and repair |
| **Future** | Applied but script missing | Investigate |
| **Outdated** | Repeatable changed | Re-run migrate |
| **Baseline** | Database baseline marker | Reference point |

**Example with pending migrations:**
```
+-----------+--------------------+---------------------+------+---------------------+---------+----------+
| Category  | Version            | Description         | Type | Installed On        | State   | Undoable |
+-----------+--------------------+---------------------+------+---------------------+---------+----------+
| Versioned | 001.20260312155434 | Initial Schema      | SQL  | 2026-03-12 15:54:55 | Success | No       |
| Versioned | 002.20260312155616 | Add Category Column | SQL  |                     | Pending | No       |
| Versioned | 003.20260312160000 | Add Index           | SQL  |                     | Pending | No       |
+-----------+--------------------+---------------------+------+---------------------+---------+----------+
```

### Part 3: Comparing Environments (1 minute)

**Commands:**
```powershell
# Check each environment
flyway info -environment=development
flyway info -environment=test
flyway info -environment=production

# Quick way to see differences
"Development:"; flyway info -environment=development | Select-String "version:"
"Test:"; flyway info -environment=test | Select-String "version:"
"Production:"; flyway info -environment=production | Select-String "version:"
```

### Closing (20 seconds)
"`flyway info` is your go-to command for understanding database state. Run it before and after migrations to verify everything is as expected. Next, we'll learn about `flyway validate` for catching migration issues early."

---

## Commands Summary

```powershell
# View migration status
flyway info -environment=test

# All environments (run separately)
flyway info -environment=development
flyway info -environment=test
flyway info -environment=production
```

## Migration State Reference

| State | Description | Resolution |
|-------|-------------|------------|
| Success | Migration completed | None |
| Pending | Awaiting application | Run `migrate` |
| Failed | Migration error | Fix script, run `repair`, then `migrate` |
| Future | Script removed after apply | Add script back or document |
| Outdated | Repeatable script changed | Run `migrate` to re-apply |
| Ignored | Matches ignore pattern | Expected behavior |
| Missing (Success) | History exists, no file | Add file or investigate |
| Missing (Failed) | Failed and file missing | Manual intervention |

## Pro Tips

1. **Run info before migrate** - Know what will change
2. **Run info after migrate** - Verify success
3. **Compare environments** - Ensure consistency
4. **Look for Failed state** - Requires attention
