# GitLab Flyway Pipeline Templates

Reusable GitLab CI/CD templates for Flyway Enterprise database migrations. Supports 1 to 100+ databases.

Your Flyway project repo includes these templates via GitLab's cross-project `include:`. Migration scripts stay in your project; deployment logic lives here.

## Repository Structure

```
.gitlab/ci/flyway.yml                        # Flyway job templates (.flyway_migrate, .flyway_check, etc.)
.gitlab/ci/generate-deployment-scripts.yml   # Schema-model → migration generation templates
.gitlab/ci/generate.yml                      # Dynamic pipeline generation template
scripts/generate_pipeline.py                 # Queries registry sproc → writes child pipeline YAML
scripts/requirements.txt                     # Python dependencies (pymssql, PyYAML)
scripts/client_registry_setup.sql            # Registry database setup + sample data (large estate)
scripts/northwind_registry_setup.sql         # Registry database setup + sample data (Northwind demo)
usage-examples/                              # Ready-to-copy .gitlab-ci.yml files for consumer repos
```

## CI/CD Variables

Set these in your consumer project under **Settings → CI/CD → Variables**.

### Required

- `FLYWAY_EMAIL` — Redgate account email (Flyway Enterprise license)
- `FLYWAY_TOKEN` — Redgate auth token (Protected, Masked)
- `TARGET_DATABASE_JDBC` — JDBC URL for the dev/default database
- `TARGET_DATABASE_USER` — Login for the dev/default database
- `TARGET_DATABASE_PASSWORD` — Password (Protected, Masked)

### Schema-Model Workflows

- `SHADOW_DATABASE_JDBC` — JDBC URL of an empty shadow database Flyway rebuilds from migrations
- `GIT_PUSH_TOKEN` — GitLab PAT with `api` scope for pushing branches and creating MRs (Protected, Masked). Not needed if [CI job token permissions](#git-push-authentication) are enabled.

### Registry-Driven Dynamic Pipelines

- `REGISTRY_SERVER` — SQL Server hostname for the registry database
- `REGISTRY_USER` — Login for the registry database
- `REGISTRY_PASSWORD` — Password (Protected, Masked)

### Multi-Environment (QA / Prod)

When QA and Prod use separate registries or credentials:

- `QA_REGISTRY_SERVER` — SQL Server for QA registry
- `QA_REGISTRY_USER` — Login for QA registry
- `QA_REGISTRY_PASSWORD` — Password (Protected, Masked)
- `QA_TARGET_DATABASE_USER` — Login for QA target databases (if different from `TARGET_DATABASE_USER`)
- `QA_TARGET_DATABASE_PASSWORD` — Password for QA targets (Protected, Masked)
- `PROD_REGISTRY_SERVER` — SQL Server for Prod registry
- `PROD_REGISTRY_USER` — Login for Prod registry
- `PROD_REGISTRY_PASSWORD` — Password (Protected, Masked)

### Optional

- `GITLAB_EXTERNAL_URL` — Browser-reachable GitLab URL (e.g. `http://localhost:8080`); defaults to `CI_SERVER_URL`
- `MR_TARGET_BRANCH` — Branch the auto-created MR targets (default: `main`)
- `FLYWAY_LOCATIONS` — Migration file path (default: `filesystem:./migrations`)
- `FILTER_LOCATION` — Region filter for dynamic pipelines (default: `all`)
- `INCLUDE_REPLICAS` — Include replicated databases (default: `false`)
- `JDBC_PORT` — Port in generated JDBC URLs (default: `1433`)
- `REGISTRY_DATABASE` — Registry DB name (default: `flyway_registry`)
- `REGISTRY_PORT` — Registry SQL Server port (default: `1433`)
- `RUNNER_TAG_DEFAULT` — Single runner tag for all generated jobs
- `RUNNER_TAG_MAP` — JSON map of location → runner tag (e.g. `{"London":"tag1"}`)
- `TEMPLATE_PROJECT` — Path to this templates repo (default: `root/templatized-with-parser`)
- `TEMPLATE_REF` — Git ref for template include (default: `main`)

## How It Works

Three templates, each with a distinct role:

| Template | Purpose |
|----------|---------|
| **generate-deployment-scripts.yml** | *Creates* migration scripts — `flyway diff model` + `flyway diff generate`, then commits them and opens an MR |
| **generate.yml** / **generate_pipeline.py** | *Discovers where to deploy* — queries the target database registry and writes a child pipeline YAML |
| **flyway.yml** | *Runs the migrations* — check, migrate, validate, info, etc. |

**Flow:** schema-model changes → generate migration SQL → discover targets from registry → check + migrate each target.

```
my-flyway-project/               this-repo (flyway-ci-templates)
├── migrations/                   ├── .gitlab/ci/flyway.yml
│   ├── V1__create_schema.sql     ├── .gitlab/ci/generate.yml
│   └── V2__add_users.sql         └── scripts/generate_pipeline.py
└── .gitlab-ci.yml  ──includes──►
```

## Target Database Registry

Dynamic pipelines discover their deployment targets from a SQL Server **registry database** (`flyway_registry` by default). The pipeline generator (`generate_pipeline.py`) connects to this registry, calls a stored procedure, and builds one CI job per returned row.

### Table: `dbo.jdbc_table_store`

Each row represents one target database instance:

| Column | Type | Purpose |
|--------|------|---------|
| `dbserver` | nvarchar(255) | SQL Server hostname — used to build the JDBC URL |
| `db` | nvarchar(255) | Database name on that server |
| `location` | nvarchar(50) | Region/site (e.g. `London`, `New York`, `Tokyo`) — used for filtering and runner tag assignment |
| `id` | nvarchar(50) | Short logical identifier (e.g. `CustHist1`, `CodeBase`) — appears in job names |
| `name` | nvarchar(255) | Human-readable description |
| `available` | bit | `1` = include in deployments, `0` = skip |
| `replicated` | bit | `1` = replica (excluded by default unless `INCLUDE_REPLICAS=true`) |
| `type` | nvarchar(10) | Logical category/group code (e.g. `AW`, `CB`, `CH`) |
| `is_dbmaster` | bit | `1` = authoritative primary for replication |
| `machine` | nvarchar(255) | Physical host (informational) |
| `is_cloud` | bit | `1` = cloud-hosted, `0` = on-premises (informational) |

### Stored Procedure: `dbo.usp_GetFlywayTargets`

```sql
EXEC dbo.usp_GetFlywayTargets
    @location        = NULL,   -- NULL = all locations
    @type            = NULL,   -- NULL = all types
    @available_only  = 1,      -- exclude unavailable databases
    @include_replicas = 0,     -- exclude replicas
    @jdbc_port       = 1433;   -- port for JDBC URL construction
```

Returns all matching rows plus a computed `jdbc_url` column. The Python script calls it with no parameters (gets all rows), then applies its own `FILTER_LOCATION` and `INCLUDE_REPLICAS` filters.

### Setup

Run one of the provided setup scripts against your registry SQL Server:

- `scripts/northwind_registry_setup.sql` — minimal 2-row demo (Northwind Dev + Prod)
- `scripts/client_registry_setup.sql` — larger example with multiple regions and database types

### How the pipeline uses it

1. `generate_pipeline.py` connects to the registry using `REGISTRY_SERVER` / `REGISTRY_USER` / `REGISTRY_PASSWORD`
2. Calls `EXEC dbo.usp_GetFlywayTargets` and receives all rows
3. Filters by `FILTER_LOCATION` and `INCLUDE_REPLICAS`
4. Builds a JDBC URL per target from `dbserver` + `db` + `JDBC_PORT`
5. Writes a child pipeline YAML with a `check:` and `migrate:` job per target
6. Each job sets `FLYWAY_URL`, `FLYWAY_USER`, `FLYWAY_PASSWORD` from the registry data and CI/CD credential variables

## Quick Start

### 1. Include the templates

```yaml
include:
  - project: 'root/templatized-with-parser'
    ref: 'main'
    file: '/.gitlab/ci/flyway.yml'
```

### 2. Set CI/CD variables

See the [CI/CD Variables](#cicd-variables) section above for the full list.

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
| `.flyway_check` | `flyway check -drift -code` | Drift + code analysis report (runs before migrate) |
| `.flyway_validate` | `flyway validate` | Check migrations are valid |
| `.flyway_info` | `flyway info` | Show migration status |
| `.flyway_migrate` | `flyway migrate` | Apply pending migrations + take snapshot |
| `.flyway_migrate_full` | `flyway check` + `flyway migrate` | Combined check → migrate in one job |
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

### generate-deployment-scripts.yml — Schema Model → Migration Generation

| Template | Purpose |
|----------|---------|
| `.flyway_generate_migrations` | `flyway diff model` + `flyway diff generate` — auto-generates V*__*.sql, commits to branch, and pushes |
| `.flyway_commit_migrations` | Pushes branch + creates a merge request for script review |

#### Git Push Authentication

The commit/MR jobs need write access. Two options:

**Option A — Personal Access Token** (recommended for self-hosted): create a token with `api` scope and add it as `GIT_PUSH_TOKEN` (Protected, Masked).

**Option B — CI Job Token** (GitLab 15.9+): enable "Allow CI job token to push to this project" in Settings → CI/CD → Token permissions. No extra variable needed.

### generate.yml — Dynamic Pipeline (100+ Databases)

For deployments driven by the [target database registry](#target-database-registry). Queries the registry, generates a child pipeline YAML with one check + migrate job per target.

```yaml
include:
  - project: 'root/templatized-with-parser'
    ref: 'main'
    file:
      - '/.gitlab/ci/flyway.yml'
      - '/.gitlab/ci/generate.yml'

stages:
  - generate
  - deploy

generate:all:
  extends: .generate_pipeline

deploy:all:
  stage: deploy
  trigger:
    include:
      - artifact: dynamic-pipeline.yml
        job: generate:all
    strategy: depend
```

### Deploying to Specific Regions

Set `FILTER_LOCATION` to deploy a single region instead of all:

```yaml
variables:
  FILTER_LOCATION: "London"    # only London targets
```

Or override at run time: **Build → Pipelines → Run pipeline** → add variable `FILTER_LOCATION` = `London`.

## Runner Tags

Generated jobs get runner tags from the target's `location`. Override precedence:

1. `RUNNER_TAG_DEFAULT` — one tag for all jobs
2. `RUNNER_TAG_MAP` — JSON map: `{"London":"prod-runner","Tokyo":"asia-runner"}`
3. Individual variables: `RUNNER_TAG_LONDON`, `RUNNER_TAG_NEW_YORK`, etc.
4. Auto-generated from location name (e.g. `runner-london`)

## Branch Promotion Strategy

For branch-based promotion (e.g. `dev` → `qa` → `prod`):

### Recommended Project Settings

**Settings → Merge Requests:**

| Setting | Value | Why |
|---------|-------|-----|
| **Merge method** | **Fast-forward merge** | Prevents merge commits that cause branches to diverge |
| **Delete source branch** | **Unchecked** | Prevents `dev`/`qa` from being deleted after each MR |

### Branch protection

| Branch | Allowed to push | Allowed to merge |
|--------|----------------|-----------------|
| `dev` | Developers + Maintainers | Developers + Maintainers |
| `qa` | No one | Maintainers |
| `prod` | No one | Maintainers |

### Recovery: branches deleted or diverged

```bash
git fetch origin
git checkout -b qa origin/prod
git push origin qa
git checkout -b dev origin/prod
git push origin dev
```

## Usage Examples

See [`usage-examples/`](usage-examples/):

| File | Scenario |
|------|----------|
| `schema-model-dynamic.gitlab-ci.yml` | Schema-model + registry-driven dynamic deploy (dev → main) |
| `staging-and-production.gitlab-ci.yml` | Dev → QA → Prod with per-region manual deploy buttons |

## Further Reading

- [SETUP_GUIDE.md](SETUP_GUIDE.md) — detailed walkthrough
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — one-page cheat sheet
- [Flyway docs](https://documentation.red-gate.com/flyway)
