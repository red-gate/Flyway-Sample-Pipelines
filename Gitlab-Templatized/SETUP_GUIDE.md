# GitLab Flyway Pipeline Setup Guide

## Overview
This guide walks you through setting up automated Flyway database migrations in GitLab CI/CD. The templates support single or multiple database targets with minimal configuration.

## Table of Contents
1. [Initial GitLab Setup](#initial-gitlab-setup)
2. [Configuring Secrets](#configuring-secrets)
3. [Single Database Setup](#single-database-setup)
4. [Multiple Database Setup](#multiple-database-setup)
5. [Advanced Configuration](#advanced-configuration)
6. [Troubleshooting](#troubleshooting)

---

## Initial GitLab Setup

### Option A: Import This Repository (Recommended)

1. **In GitLab, go to**: Projects → New project → Import project → Repository by URL

2. **Enter the URL** of this repository:
   ```
   https://github.com/your-org/Flyway-Sample-Pipelines.git
   ```
   Or use SSH if you have access:
   ```
   git@github.com:your-org/Flyway-Sample-Pipelines.git
   ```

3. **Configure project settings:**
   - Project name: `your-app-migrations`
   - Visibility: Private (recommended for database migrations)
   - Click **Create project**

4. **Clone to your local machine:**
   ```bash
   git clone <your-gitlab-project-url>
   cd your-app-migrations/Gitlab-Templatized
   ```

### Option B: Start Fresh and Copy Files

1. **Create a new GitLab project** (blank)

2. **Clone this repository locally** and copy the Gitlab-Templatized folder:
   ```bash
   git clone <this-repo-url>
   cp -r Flyway-Sample-Pipelines/Gitlab-Templatized/* your-new-project/
   cd your-new-project
   ```

3. **Initialize and push:**
   ```bash
   git add .
   git commit -m "Initial Flyway pipeline setup"
   git push
   ```

---

## Configuring Secrets

**CRITICAL**: Never commit database credentials to your repository. All secrets must be stored in GitLab CI/CD variables.

### Navigate to CI/CD Variables

In your GitLab project:
```
Settings → CI/CD → Variables → Expand → Add variable
```

### Single Database Secrets

Add these three variables:

| Key | Value | Type | Protected | Masked | Environment Scope |
|-----|-------|------|-----------|--------|-------------------|
| `TARGET_DATABASE_JDBC` | `jdbc:postgresql://db.example.com:5432/mydb` | Variable | ✓ Yes | No | All |
| `TARGET_DATABASE_USER` | `flyway_user` | Variable | ✓ Yes | No | All |
| `TARGET_DATABASE_PASSWORD` | `your-secure-password` | Variable | ✓ Yes | ✓ Yes | All |

**Notes:**
- **Protected**: Only available to protected branches (main, production)
- **Masked**: Hidden in job logs
- **Environment Scope**: Set to "All" or specific environments (dev, staging, prod)

### Multiple Database Secrets

For multiple databases, use numbered or named suffixes:

#### Approach 1: Numbered Databases (1 to N)
```
TARGET_DATABASE_JDBC_1  = jdbc:postgresql://db1.example.com:5432/users
TARGET_DATABASE_USER_1  = flyway_user
TARGET_DATABASE_PASSWORD_1 = password1

TARGET_DATABASE_JDBC_2  = jdbc:postgresql://db2.example.com:5432/orders
TARGET_DATABASE_USER_2  = flyway_user
TARGET_DATABASE_PASSWORD_2 = password2

... (repeat for N databases)
```

#### Approach 2: Named Databases (Recommended for clarity)
```
TARGET_DATABASE_JDBC_USERS    = jdbc:postgresql://...
TARGET_DATABASE_USER_USERS    = flyway_user
TARGET_DATABASE_PASSWORD_USERS = password1

TARGET_DATABASE_JDBC_ORDERS   = jdbc:postgresql://...
TARGET_DATABASE_USER_ORDERS   = flyway_user
TARGET_DATABASE_PASSWORD_ORDERS = password2
```

#### Approach 3: Environment-Based (Dev/Staging/Prod)
```
TARGET_DATABASE_JDBC          = [different per environment]
TARGET_DATABASE_USER          = [different per environment]
TARGET_DATABASE_PASSWORD      = [different per environment]
```
Set **Environment Scope** to `dev`, `staging`, or `prod` for each variable.

### JDBC Connection String Examples

**PostgreSQL:**
```
jdbc:postgresql://hostname:5432/database_name
jdbc:postgresql://hostname:5432/database_name?ssl=true
```

**MySQL:**
```
jdbc:mysql://hostname:3306/database_name
jdbc:mysql://hostname:3306/database_name?useSSL=true
```

**SQL Server:**
```
jdbc:sqlserver://hostname:1433;databaseName=database_name
jdbc:sqlserver://hostname:1433;databaseName=database_name;encrypt=true
```

**Oracle:**
```
jdbc:oracle:thin:@hostname:1521:SID
jdbc:oracle:thin:@//hostname:1521/service_name
```

---

## Single Database Setup

### Step 1: Choose Pipeline Template

Copy the development example to create your active pipeline:

```bash
cp .gitlab-ci-example-dev.yml .gitlab-ci.yml
```

### Step 2: Review and Customize (Optional)

Edit `.gitlab-ci.yml` if you want to change branch triggers or add more stages:

```yaml
include:
  - local: '.gitlab/ci/flyway.yml'

stages:
  - validate
  - deploy

# Validate migrations on every commit
validate:dev:
  extends: .flyway_validate
  stage: validate
  only:
    - dev
    - merge_requests

# Deploy to database
migrate:dev:
  extends: .flyway_migrate
  stage: deploy
  only:
    - dev
  environment:
    name: development
```

**Key Points:**
- `extends: .flyway_validate` - Inherits all Flyway validation logic (DRY)
- `only: - dev` - Runs only on the `dev` branch
- Variables are inherited from GitLab CI/CD settings

### Step 3: Add SQL Migrations

Create your migration scripts in the `sql/` directory:

```bash
# Version migrations (applied in order)
sql/V1__create_users_table.sql
sql/V2__add_email_column.sql
sql/V3__create_orders_table.sql

# Repeatable migrations (applied after versioned)
sql/R__update_views.sql
```

**Example Migration:**
```sql
-- sql/V1__create_users_table.sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
```

### Step 4: Commit and Push

```bash
git add .gitlab-ci.yml sql/
git commit -m "Configure Flyway pipeline for dev environment"
git push origin dev
```

### Step 5: Monitor Pipeline

1. Go to **CI/CD → Pipelines** in GitLab
2. Watch your pipeline execute
3. Check job logs for any errors

---

## Multiple Database Setup

### Scenario 1: Deploy to 2-10 Databases (Explicit Jobs)

Use the multi-database example:

```bash
cp .gitlab-ci-example-multi-db.yml .gitlab-ci.yml
```

Edit `.gitlab-ci.yml` to match your databases:

```yaml
include:
  - local: '.gitlab/ci/flyway.yml'

stages:
  - validate
  - deploy

variables:
  # Default SQL location (can be overridden per job)
  FLYWAY_LOCATIONS: "filesystem:./sql"

# Validate once (uses first database)
validate:all:
  extends: .flyway_validate
  stage: validate
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC_1}"
    FLYWAY_USER: "${TARGET_DATABASE_USER_1}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD_1}"

# Deploy to Database 1: Users
migrate:users:
  extends: .flyway_migrate
  stage: deploy
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC_1}"
    FLYWAY_USER: "${TARGET_DATABASE_USER_1}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD_1}"
  environment:
    name: db-users

# Deploy to Database 2: Orders
migrate:orders:
  extends: .flyway_migrate
  stage: deploy
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC_2}"
    FLYWAY_USER: "${TARGET_DATABASE_USER_2}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD_2}"
  environment:
    name: db-orders

# Add more databases as needed...
```

### Scenario 2: Deploy to 10-100 Databases (Matrix Strategy)

For many databases, use GitLab's matrix feature:

```yaml
include:
  - local: '.gitlab/ci/flyway.yml'

stages:
  - deploy

migrate:multi:
  extends: .flyway_migrate
  stage: deploy
  parallel:
    matrix:
      - DB_SUFFIX: ["1", "2", "3", "4", "5"]  # Add more as needed
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC_${DB_SUFFIX}}"
    FLYWAY_USER: "${TARGET_DATABASE_USER_${DB_SUFFIX}}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD_${DB_SUFFIX}}"
  environment:
    name: database-${DB_SUFFIX}
```

This creates 5 parallel jobs: `migrate:multi: [1]`, `migrate:multi: [2]`, etc.

### Scenario 3: Deploy to 100+ Databases (Dynamic Pipelines)

For hundreds of databases, create a configuration file and use dynamic child pipelines:

**Step 1:** Create `databases.json`:
```json
[
  {"id": "db1", "jdbc": "jdbc:postgresql://db1.example.com:5432/app"},
  {"id": "db2", "jdbc": "jdbc:postgresql://db2.example.com:5432/app"},
  ...
]
```

**Step 2:** Create a generator script in `.gitlab/ci/generate-pipeline.sh`:
```bash
#!/bin/bash
cat << EOF
include:
  - local: '.gitlab/ci/flyway.yml'

stages:
  - deploy

EOF

# Generate jobs from JSON
jq -r '.[] | "
migrate:\(.id):
  extends: .flyway_migrate
  stage: deploy
  variables:
    FLYWAY_URL: \"${TARGET_DATABASE_JDBC_\(.id | ascii_upcase)}\"
    FLYWAY_USER: \"${TARGET_DATABASE_USER_\(.id | ascii_upcase)}\"
    FLYWAY_PASSWORD: \"${TARGET_DATABASE_PASSWORD_\(.id | ascii_upcase)}\"
  environment:
    name: \(.id)
"' databases.json
```

**Step 3:** Update `.gitlab-ci.yml`:
```yaml
stages:
  - generate
  - deploy

generate:pipeline:
  stage: generate
  image: alpine:latest
  script:
    - apk add --no-cache jq bash
    - bash .gitlab/ci/generate-pipeline.sh > generated-pipeline.yml
  artifacts:
    paths:
      - generated-pipeline.yml

child:pipeline:
  stage: deploy
  trigger:
    include:
      - artifact: generated-pipeline.yml
        job: generate:pipeline
    strategy: depend
```

---

## Advanced Configuration

### Custom Flyway Options

Override Flyway settings per job:

```yaml
migrate:custom:
  extends: .flyway_migrate
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC}"
    FLYWAY_USER: "${TARGET_DATABASE_USER}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD}"
    # Custom Flyway options
    FLYWAY_BASELINE_ON_MIGRATE: "false"
    FLYWAY_OUT_OF_ORDER: "true"
    FLYWAY_SCHEMAS: "app_schema,audit_schema"
    FLYWAY_TABLE: "custom_flyway_history"
    FLYWAY_PLACEHOLDERS_APP_VERSION: "${CI_COMMIT_TAG}"
```

### SQL Location Strategies

**Single shared location:**
```yaml
variables:
  FLYWAY_LOCATIONS: "filesystem:./sql"
```

**Per-database locations:**
```yaml
migrate:users:
  extends: .flyway_migrate
  variables:
    FLYWAY_LOCATIONS: "filesystem:./sql/users"

migrate:orders:
  extends: .flyway_migrate
  variables:
    FLYWAY_LOCATIONS: "filesystem:./sql/orders"
```

**Multiple locations:**
```yaml
variables:
  FLYWAY_LOCATIONS: "filesystem:./sql/common,filesystem:./sql/specific"
```

### Manual Approval for Production

```yaml
migrate:production:
  extends: .flyway_migrate
  stage: deploy
  when: manual  # Requires manual click in GitLab UI
  only:
    - tags
  environment:
    name: production
```

### Conditional Migrations

```yaml
migrate:feature:
  extends: .flyway_migrate
  only:
    variables:
      - $ENABLE_FEATURE_MIGRATIONS == "true"
```

---

## Troubleshooting

### Pipeline Fails: "Variable not found"

**Cause:** CI/CD variable not configured in GitLab.

**Solution:** 
1. Go to Settings → CI/CD → Variables
2. Verify all required variables exist
3. Check spelling matches exactly (case-sensitive)
4. Verify Environment Scope if using scoped variables

### Connection Refused / Timeout

**Cause:** GitLab Runner cannot reach database server.

**Solutions:**
- Verify JDBC URL is correct
- Check database server allows connections from GitLab Runner IP
- Verify firewall rules
- Test connection from runner: `flyway info` in a manual job

### Secrets Exposed in Logs

**Cause:** Variable not marked as "Masked" in GitLab.

**Solution:**
1. Edit the variable in Settings → CI/CD → Variables
2. Check the "Mask variable" checkbox
3. Note: Very short values cannot be masked

### Migration Fails: "Schema history table corrupted"

**Cause:** Schema history table is out of sync.

**Solution:** Run manual repair job:
```yaml
repair:manual:
  extends: .flyway_repair
  when: manual
  environment:
    name: your-environment
```

### Multiple Databases: Wrong Credentials Used

**Cause:** Variable name mismatch.

**Solution:** 
- Verify `${TARGET_DATABASE_JDBC_1}` syntax is correct
- Check GitLab logs to see which variable value is being used
- Ensure variable names match between `.gitlab-ci.yml` and GitLab settings

### Flyway Command Not Found

**Cause:** Docker image issue.

**Solution:** Verify image in `.gitlab/ci/flyway.yml` is accessible:
```yaml
.flyway_base:
  image: redgate/flyway:12-alpine
```

---

## Next Steps

- [ ] Configure GitLab CI/CD variables for your databases
- [ ] Choose and copy an example pipeline to `.gitlab-ci.yml`
- [ ] Add your SQL migration files to `sql/`
- [ ] Test with a non-production database first
- [ ] Set up protected branches for production deployments
- [ ] Configure manual approvals for production pipelines
- [ ] Review Flyway documentation: https://documentation.red-gate.com/flyway

---

## Need Help?

- **Flyway Documentation**: https://documentation.red-gate.com/flyway
- **GitLab CI/CD Variables**: https://docs.gitlab.com/ee/ci/variables/
- **GitLab Environments**: https://docs.gitlab.com/ee/ci/environments/

## Best Practices

1. ✅ Always validate before migrating
2. ✅ Use protected variables for production
3. ✅ Enable manual approval for production
4. ✅ Test migrations in dev/staging first
5. ✅ Keep migration scripts in version control
6. ✅ Use semantic versioning for migration numbers
7. ✅ Never commit credentials to git
8. ✅ Monitor pipeline logs for warnings
9. ✅ Maintain backups before migrations
10. ✅ Document breaking changes in migration comments
