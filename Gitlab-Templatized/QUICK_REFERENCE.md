# GitLab Flyway Quick Reference

## One-Page Cheat Sheet for Users

### Initial Setup (5 Minutes)

1. **Import project to GitLab**
   - Projects → New project → Import project → Repository by URL
   - Choose project name, set visibility to Private

2. **Configure CI/CD Variables** (Settings → CI/CD → Variables)
   ```
   TARGET_DATABASE_JDBC     = jdbc:postgresql://host:5432/db
   TARGET_DATABASE_USER     = flyway_user
   TARGET_DATABASE_PASSWORD = your-password (Protected + Masked)
   ```

3. **Choose pipeline template** from `usage-examples/`
   ```bash
   cp usage-examples/single-db-dev.gitlab-ci.yml .gitlab-ci.yml
   ```

4. **Add SQL migrations**
   ```
   sql/V1__initial_schema.sql
   sql/V2__add_tables.sql
   ```

5. **Push and deploy**
   ```bash
   git add .gitlab-ci.yml sql/
   git commit -m "Setup Flyway pipeline"
   git push
   ```

---

## Variable Naming Quick Reference

### Single Database
```yaml
TARGET_DATABASE_JDBC
TARGET_DATABASE_USER
TARGET_DATABASE_PASSWORD
```

### Multiple Databases (Numbered)
```yaml
TARGET_DATABASE_JDBC_1, _2, _3, ..., _N
TARGET_DATABASE_USER_1, _2, _3, ..., _N
TARGET_DATABASE_PASSWORD_1, _2, _3, ..., _N
```

### Multiple Databases (Named)
```yaml
TARGET_DATABASE_JDBC_USERS, _ORDERS, _ANALYTICS
TARGET_DATABASE_USER_USERS, _ORDERS, _ANALYTICS
TARGET_DATABASE_PASSWORD_USERS, _ORDERS, _ANALYTICS
```

### Environment Scoped (Same Names)
```yaml
# Use Environment Scope in GitLab:
TARGET_DATABASE_JDBC     (scope: dev)
TARGET_DATABASE_JDBC     (scope: staging)
TARGET_DATABASE_JDBC     (scope: production)
```

---

## JDBC Connection Strings

| Database | Connection String |
|----------|-------------------|
| **PostgreSQL** | `jdbc:postgresql://host:5432/database?ssl=true` |
| **MySQL** | `jdbc:mysql://host:3306/database?useSSL=true` |
| **SQL Server** | `jdbc:sqlserver://host:1433;databaseName=db;encrypt=true` |
| **Oracle** | `jdbc:oracle:thin:@//host:1521/service` |
| **MariaDB** | `jdbc:mariadb://host:3306/database` |

---

## Pipeline Template Selection

| Databases | Template (in `usage-examples/`) | Command |
|-----------|--------------------------------|--------|
| **1 database** | `single-db-dev.gitlab-ci.yml` | `cp usage-examples/single-db-dev.gitlab-ci.yml .gitlab-ci.yml` |
| **Schema-model workflow** | `schema-model.gitlab-ci.yml` | `cp usage-examples/schema-model.gitlab-ci.yml .gitlab-ci.yml` |
| **Dev + Staging + Prod** | `staging-and-production.gitlab-ci.yml` | `cp usage-examples/staging-and-production.gitlab-ci.yml .gitlab-ci.yml` |
| **2-10 databases** | `multi-database.gitlab-ci.yml` | `cp usage-examples/multi-database.gitlab-ci.yml .gitlab-ci.yml` |
| **10-100 databases** | `matrix.gitlab-ci.yml` | `cp usage-examples/matrix.gitlab-ci.yml .gitlab-ci.yml` |
| **100+ databases** | `dynamic-pipeline.gitlab-ci.yml` | `cp usage-examples/dynamic-pipeline.gitlab-ci.yml .gitlab-ci.yml` |

---

## Available Flyway Jobs (Extend These)

| Template | Purpose | Example Usage |
|----------|---------|---------------|
| `.flyway_validate` | Validate SQL syntax | Run on every MR |
| `.flyway_info` | Show migration status | Check before deploy |
| `.flyway_migrate` | Apply migrations | Deploy changes |
| `.flyway_repair` | Fix history table | Manual, when corrupted |
| `.flyway_baseline` | Baseline existing DB | Manual, initial setup |
| `.flyway_clean` | Drop all objects | Manual, dev only, DANGER |

---

## Migration File Naming

### Versioned (Applied Once)
```
V1__description.sql
V1.1__another_change.sql
V2__major_update.sql
```

### Repeatable (Applied When Changed)
```
R__update_views.sql
R__update_procedures.sql
```

### Format Rules
- `V<version>__<description>.sql` for versioned
- `R__<description>.sql` for repeatable
- Double underscore `__` separates parts
- Use underscores for spaces in description

---

## Common Pipeline Patterns

### Single Database
```yaml
include:
  - local: '.gitlab/ci/flyway.yml'

migrate:dev:
  extends: .flyway_migrate
  stage: deploy
```

### Multiple Databases (Explicit)
```yaml
migrate:db1:
  extends: .flyway_migrate
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC_1}"
    FLYWAY_USER: "${TARGET_DATABASE_USER_1}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD_1}"

migrate:db2:
  extends: .flyway_migrate
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC_2}"
    FLYWAY_USER: "${TARGET_DATABASE_USER_2}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD_2}"
```

### Matrix (N Databases)
```yaml
migrate:all:
  extends: .flyway_migrate
  parallel:
    matrix:
      - DB_NUMBER: ["1", "2", "3", "4", "5"]
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC_${DB_NUMBER}}"
    FLYWAY_USER: "${TARGET_DATABASE_USER_${DB_NUMBER}}"
    FLYWAY_PASSWORD: "${TARGET_DATABASE_PASSWORD_${DB_NUMBER}}"
```

---

## Customization Examples

### Override Flyway Options
```yaml
migrate:custom:
  extends: .flyway_migrate
  variables:
    FLYWAY_BASELINE_ON_MIGRATE: "false"
    FLYWAY_OUT_OF_ORDER: "true"
    FLYWAY_SCHEMAS: "app,audit"
```

### Different SQL Locations
```yaml
migrate:users:
  extends: .flyway_migrate
  variables:
    FLYWAY_LOCATIONS: "filesystem:./sql/users"
```

### Manual Approval
```yaml
migrate:prod:
  extends: .flyway_migrate
  when: manual  # Requires click in GitLab UI
```

### Branch Control
```yaml
migrate:prod:
  extends: .flyway_migrate
  only:
    - main
    - tags
```

---

## Troubleshooting Quick Fixes

| Problem | Quick Fix |
|---------|-----------|
| "Variable not found" | Add variable in Settings → CI/CD → Variables |
| Connection timeout | Check JDBC URL and firewall rules |
| Secrets in logs | Mark variable as "Masked" in GitLab |
| History corrupted | Run `.flyway_repair` job |
| Wrong database | Verify variable names match `_1`, `_2` suffixes |

---

## DRY Principle Reminder

✅ **DO**: Extend templates
```yaml
migrate:db:
  extends: .flyway_migrate  # ✅ Inherits all logic
  variables:
    FLYWAY_URL: "${TARGET_DATABASE_JDBC}"
```

❌ **DON'T**: Duplicate commands
```yaml
migrate:db:
  script:
    - flyway migrate  # ❌ Should be in template only
```

---

## Testing Locally (Docker)

```bash
# Test connection
docker run --rm redgate/flyway:12-alpine \
  -url="jdbc:postgresql://host:5432/db" \
  -user="user" -password="pass" info

# Validate migrations
docker run --rm -v $(pwd)/sql:/flyway/sql \
  redgate/flyway:12-alpine \
  -url="jdbc:postgresql://host:5432/db" \
  -user="user" -password="pass" validate

# Apply migrations
docker run --rm -v $(pwd)/sql:/flyway/sql \
  redgate/flyway:12-alpine \
  -url="jdbc:postgresql://host:5432/db" \
  -user="user" -password="pass" migrate
```

---

## Best Practices Checklist

- [ ] Secrets stored in GitLab CI/CD variables (not in code)
- [ ] Production passwords marked as Protected + Masked
- [ ] Validate job runs before migrate job
- [ ] Manual approval enabled for production
- [ ] Test in dev/staging before production
- [ ] Migrations follow naming convention (V1__, V2__, etc.)
- [ ] SQL files in version control
- [ ] Database backups exist before migration
- [ ] Pipeline extends templates (no command duplication)
- [ ] Documentation updated when adding databases

---

## Quick Links

- **[README.md](README.md)** - Project overview
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Detailed setup instructions
- **[CLAUDE_INSTRUCTIONS.md](CLAUDE_INSTRUCTIONS.md)** - Maintenance guidelines
- **[Flyway Docs](https://documentation.red-gate.com/flyway)** - Official documentation
- **[GitLab CI/CD](https://docs.gitlab.com/ee/ci/)** - GitLab documentation

---

**Print this page for quick reference!**
