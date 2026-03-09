# GitLab Flyway CI/CD Pipeline

This repository contains reusable GitLab CI/CD pipelines for Flyway database migrations.

## Structure

```
.gitlab/
  └── ci/
      └── flyway.yml          # Shared Flyway job templates (DRY)
.gitlab-ci.yml                # Your main pipeline
sql/                          # Your SQL migration files
```

## Quick Start

### 1. Choose a Pipeline Template

Copy one of the example files to `.gitlab-ci.yml`:

```bash
# Development pipeline
cp .gitlab-ci-example-dev.yml .gitlab-ci.yml

# Production pipeline  
cp .gitlab-ci-example-prod.yml .gitlab-ci.yml

# Multi-database pipeline
cp .gitlab-ci-example-multi-db.yml .gitlab-ci.yml
```

### 2. Configure CI/CD Variables

In GitLab: **Settings → CI/CD → Variables**

Add:
- `DB_PASSWORD` (Protected: Yes, Masked: Yes)
- `DB_URL` (example: `jdbc:postgresql://hostname:5432/dbname`)
- `DB_USER`

### 3. Add SQL Migrations

Create migrations in the `sql/` directory:

```sql
-- sql/V1__initial_schema.sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);
```

### 4. Push to GitLab

```bash
git add .
git commit -m "Add Flyway pipeline"
git push
```

## Available Flyway Jobs

All jobs are defined in `.gitlab/ci/flyway.yml`:

- **`.flyway_validate`** - Validate migrations
- **`.flyway_info`** - Show migration status  
- **`.flyway_migrate`** - Run migrations
- **`.flyway_repair`** - Repair migration history (manual)
- **`.flyway_clean`** - Clean database (manual)
- **`.flyway_baseline`** - Baseline existing database (manual)

## Customization Example

```yaml
include:
  - local: '.gitlab/ci/flyway.yml'

stages:
  - deploy

migrate:custom:
  extends: .flyway_migrate
  variables:
    FLYWAY_URL: "jdbc:postgresql://my-db:5432/mydb"
    FLYWAY_LOCATIONS: "filesystem:./sql/custom"
  only:
    - main
```

## Database Connection Strings

- **PostgreSQL**: `jdbc:postgresql://hostname:5432/database`
- **MySQL**: `jdbc:mysql://hostname:3306/database`
- **SQL Server**: `jdbc:sqlserver://hostname:1433;databaseName=database`
- **Oracle**: `jdbc:oracle:thin:@hostname:1521:database`

## Docker Image

Using: `redgate/flyway:12-alpine`

See: https://hub.docker.com/r/redgate/flyway
