# GitLab Flyway Pipeline Templates

DRY CI/CD templates for Flyway database migrations. Supports 1 to 100+ databases.

## Setup

### 1. Create a GitLab project

GitLab  **New project  Create blank project**, then push this folder's contents:

```bash
git clone <this-repo-url>
cd Flyway-Sample-Pipelines/Gitlab-Templatized
git init
git remote add origin <your-gitlab-project-url>
git add .
git commit -m "Initial Flyway pipeline setup"
git push -u origin main
```

> Use **Create blank project**  "Import project" cannot target a subfolder, and "Create from template" has no Flyway templates.

### 2. Add CI/CD variables

GitLab  **Settings  CI/CD  Variables**:

| Variable | Example | Masked |
|----------|---------|--------|
| `TARGET_DATABASE_JDBC` | `jdbc:sqlserver://host:1433;databaseName=mydb` | No |
| `TARGET_DATABASE_USER` | `flyway_user` | No |
| `TARGET_DATABASE_PASSWORD` | `secret` |  |

For multiple databases append a suffix: `TARGET_DATABASE_JDBC_1`, `TARGET_DATABASE_JDBC_2`, etc.

### 3. Pick a pipeline template

Copy an example to `.gitlab-ci.yml`:

| File | Use when |
|------|----------|
| `.gitlab-ci-example-dev.yml` | Single database, dev workflow |
| `.gitlab-ci-example-prod.yml` | Staging + production with manual approval |
| `.gitlab-ci-example-multi-db.yml` | 210 databases, explicit jobs |
| `.gitlab-ci-example-matrix.yml` | 10100+ databases, parallel matrix |
| `.gitlab-ci-example-all-regions.yml` | Multi-region, dynamically generated from registry |

### 4. Add SQL migrations

Put versioned scripts in `sql/`:

```
sql/V1__create_schema.sql
sql/V2__add_users_table.sql
```

### 5. Push and run

```bash
git add .gitlab-ci.yml sql/
git commit -m "Add migrations"
git push
```

Pipeline runs automatically. Check **CI/CD  Pipelines**.

## Key files

```
.gitlab/ci/flyway.yml       # Single source of truth  all Flyway job templates
scripts/                    # Registry DB setup + Python pipeline generator
sql/                        # Your migration files go here
```

## Further reading

- [SETUP_GUIDE.md](SETUP_GUIDE.md)  detailed walkthrough
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md)  one-page cheat sheet
- [Flyway docs](https://documentation.red-gate.com/flyway)
