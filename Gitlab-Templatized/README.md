# GitLab Flyway Pipeline Templates

Reusable GitLab CI/CD templates for Flyway Enterprise database migrations. Supports 1 to 100+ databases.

Your Flyway project repo includes these templates via GitLab's cross-project `include:`. Migration scripts stay in your project; deployment logic lives here.

## Repository Structure

```
.gitlab/ci/flyway.yml         # Flyway job templates (.flyway_validate, .flyway_migrate, etc.)
.gitlab/ci/generate.yml       # Dynamic pipeline generation template (.generate_pipeline)
scripts/generate_pipeline.py  # Queries registry sproc → builds JDBCs → writes child pipeline YAML
scripts/requirements.txt      # Python dependencies (pymssql, PyYAML)
scripts/client_registry_setup.sql  # SQL to create the registry database + sample data
usage-examples/               # Ready-to-copy .gitlab-ci.yml files for consumer repos
```

## How It Works

**Your Flyway project repo** includes templates from **this repo**:

```
my-flyway-project/               this-repo (flyway-ci-templates)
├── migrations/                   ├── .gitlab/ci/flyway.yml
│   ├── V1__create_schema.sql     ├── .gitlab/ci/generate.yml
│   └── V2__add_users.sql         └── scripts/generate_pipeline.py
└── .gitlab-ci.yml  ──includes──►
```

## Quick Start

### 1. Include the templates

In your Flyway project's `.gitlab-ci.yml`:

```yaml
include:
  - project: 'your-group/flyway-ci-templates'   # path to THIS repo
    ref: 'v1.0.0'                                # pin to a tag
    file: '/.gitlab/ci/flyway.yml'
```

### 2. Set CI/CD variables

In your project: **Settings → CI/CD → Variables**:

| Variable | Example | Protected | Masked |
|----------|---------|-----------|--------|
| `TARGET_DATABASE_JDBC` | `jdbc:sqlserver://host:1433;databaseName=mydb;encrypt=true` | ✓ | |
| `TARGET_DATABASE_USER` | `flyway_user` | ✓ | |
| `TARGET_DATABASE_PASSWORD` | `secret` | ✓ | ✓ |
| `FLYWAY_EMAIL` | `you@company.com` | | |
| `FLYWAY_TOKEN` | `flyway-license-token` | ✓ | ✓ |

### 3. Extend the templates

```yaml
stages:
  - validate
  - deploy

validate:
  extends: .flyway_validate
  stage: validate
  rules:
    - if: $CI_MERGE_REQUEST_IID
    - if: $CI_COMMIT_BRANCH == "dev"

migrate:dev:
  extends: .flyway_migrate
  stage: deploy
  environment: { name: development }
  rules:
    - if: $CI_COMMIT_BRANCH == "dev"
```

## Available Templates

### flyway.yml — Job Templates

| Template | Flyway Command | Notes |
|----------|---------------|-------|
| `.flyway_validate` | `flyway validate` | Check migrations are valid |
| `.flyway_info` | `flyway info` | Show migration status |
| `.flyway_migrate` | `flyway migrate` | Apply pending migrations |
| `.flyway_repair` | `flyway repair` | Fix schema history (manual) |
| `.flyway_clean` | `flyway clean` | Wipe database (manual, dev only) |
| `.flyway_baseline` | `flyway baseline` | Baseline existing DB (manual) |

Override any Flyway setting at the job level:

```yaml
migrate:custom:
  extends: .flyway_migrate
  variables:
    FLYWAY_LOCATIONS: "filesystem:./db/scripts"
    FLYWAY_OUT_OF_ORDER: "true"
```

### generate.yml — Dynamic Pipeline (100+ Databases)

For large-scale deployments driven by a SQL Server registry database. A single Python script (`scripts/generate_pipeline.py`) calls `dbo.usp_GetFlywayTargets`, builds JDBC URLs from the `dbserver` and `db` columns, and writes a child pipeline with one migrate job per target.

```yaml
include:
  - project: 'your-group/flyway-ci-templates'
    ref: 'v1.0.0'
    file:
      - '/.gitlab/ci/flyway.yml'
      - '/.gitlab/ci/generate.yml'

stages:
  - generate
  - deploy

generate:all:
  extends: .generate_pipeline
  # variables:
  #   FILTER_LOCATION: "London"    # optional: filter to one region

deploy:all:
  stage: deploy
  trigger:
    include:
      - artifact: dynamic-pipeline.yml
        job: generate:all
    strategy: depend
```

Additional CI/CD variables for registry access:

| Variable | Purpose | Masked |
|----------|---------|--------|
| `REGISTRY_SERVER` | Registry SQL Server hostname | |
| `REGISTRY_USER` | Registry login | |
| `REGISTRY_PASSWORD` | Registry password | ✓ |

Optional `generate_pipeline.py` settings:

| Variable | Default | Purpose |
|----------|---------|---------|
| `FILTER_LOCATION` | `all` | Region filter (`London`, `New York`, `Tokyo`) |
| `INCLUDE_REPLICAS` | `false` | Include replicated databases |
| `JDBC_PORT` | `1433` | Port in generated JDBC URLs |
| `TEMPLATE_PROJECT` | _(empty)_ | Templates repo path for child pipeline include |
| `TEMPLATE_REF` | `main` | Git ref for cross-project child pipeline include |

## Usage Examples

See [`usage-examples/`](usage-examples/) for complete `.gitlab-ci.yml` files:

| File | Scenario |
|------|----------|
| `single-db-dev.gitlab-ci.yml` | Single database, dev branch |
| `staging-and-production.gitlab-ci.yml` | Staging → production with manual approval |
| `multi-database.gitlab-ci.yml` | 2–10 databases with explicit jobs |

For parallel matrix (10–100 DBs), see `.gitlab-ci-example-matrix.yml`.
For registry-driven dynamic pipelines (100+ DBs), see `.gitlab-ci-example-all-regions.yml`.

## Environment-Scoped Variables

For staging/production with different credentials, set the **Environment scope** when creating CI/CD variables:

- Scope `staging` → `TARGET_DATABASE_JDBC = jdbc:sqlserver://staging-db:1433;...`
- Scope `production` → `TARGET_DATABASE_JDBC = jdbc:sqlserver://prod-db:1433;...`

GitLab automatically selects the right variable based on the job's `environment:` setting.

## Further Reading

- [SETUP_GUIDE.md](SETUP_GUIDE.md) — detailed walkthrough
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — one-page cheat sheet
- [Flyway docs](https://documentation.red-gate.com/flyway)
