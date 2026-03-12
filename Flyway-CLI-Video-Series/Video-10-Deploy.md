# Video 10: Deploying with `flyway deploy`

## Overview
Learn how to use `flyway deploy` to execute prepared deployment scripts.

## Duration
5-7 minutes

## Learning Objectives
- Execute prepared deployment scripts
- Understand deploy options
- Save deployment snapshots
- Handle deployment errors

---

## Script

### Intro (30 seconds)
"`flyway deploy` is the counterpart to `prepare` - it executes the deployment script that was generated and reviewed. This command ensures proper tracking while giving you control over exactly what runs."

### Part 1: Deploy Workflow (1 minute)

**Talking Points:**
- Deploy executes a pre-generated SQL script
- Script must have been created by `flyway prepare`
- Maintains schema history tracking
- Can save snapshots for rollback planning

**The complete workflow:**
```
prepare → review → approve → deploy
```

### Part 2: Basic Deploy Usage (1.5 minutes)

**Command:**
```powershell
flyway deploy "-deploy.scriptFilename=deploy_test.sql" -environment=test
```

**Expected Output:**
```
Executing script: C:\project\deploy_test.sql
WARNING: DB: Changed database context to 'TestDB'
Altering [Sales].[Products]
Refreshing [Sales].[ProductSummary]
Successfully executed
```

**Key points:**
- Script runs against specified environment
- PRINT statements appear in output
- Success message confirms completion

### Part 3: Deploy with Snapshot (1.5 minutes)

**Talking Points:**
- Save a snapshot before changes (for comparison/rollback)
- Useful for drift detection post-deployment
- Enterprise feature

**Command:**
```powershell
# Deploy and save post-deployment snapshot
flyway deploy "-deploy.scriptFilename=deploy_prod.sql" -environment=production "-deploy.saveSnapshot=true"
```

**Where snapshot is saved:**
- Default location in project folder
- Can specify custom path

### Part 4: Error Handling (1 minute)

**Scenario: Script fails mid-execution**
```powershell
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=test
# Error occurs during execution
```

**What happens:**
- SQL Server may have partial changes (depending on transaction)
- Schema history may not be updated
- Need to investigate and fix

**Recovery steps:**
```powershell
# 1. Check current state
flyway info -environment=test

# 2. Fix the issue in migration script

# 3. Regenerate prepare script
flyway prepare "-prepare.source=migrations" "-prepare.target=test" "-prepare.scriptFilename=deploy_fixed.sql"

# 4. Re-deploy
flyway deploy "-deploy.scriptFilename=deploy_fixed.sql" -environment=test
```

### Closing (30 seconds)
"With `prepare` and `deploy`, you have a controlled deployment pipeline that satisfies audit requirements while maintaining Flyway's version tracking. Next, we'll learn about `flyway clean` for resetting databases."

---

## Commands Summary

```powershell
# Basic deploy
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=production

# Deploy with snapshot
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=production "-deploy.saveSnapshot=true"

# Full production workflow
flyway prepare "-prepare.source=migrations" "-prepare.target=production" "-prepare.scriptFilename=deploy_prod.sql"
# ... review and approve ...
flyway deploy "-deploy.scriptFilename=deploy_prod.sql" -environment=production
```

## Prepare + Deploy vs Migrate

| Prepare + Deploy | Migrate |
|-----------------|---------|
| Two-step process | Single command |
| Script review possible | Direct execution |
| Change control friendly | Automation friendly |
| Audit trail via script | Audit trail via history |
| Production recommended | Dev/test environments |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Script not found | Check path in -deploy.scriptFilename |
| Connection failed | Verify environment config |
| Permission denied | Check database user permissions |
| Partial failure | Check transaction settings, fix and re-deploy |
