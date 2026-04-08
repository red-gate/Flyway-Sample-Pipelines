# GitLab Flyway Pipeline Templates

Reusable GitLab CI/CD templates for Flyway Enterprise database migrations. Supports 1 to 100+ databases.

Your Flyway project repo includes these templates via GitLab's cross-project `include:`. Migration scripts stay in your project; deployment logic lives here.

## Repository Structure

```
.gitlab/ci/flyway.yml         # Flyway job templates (.flyway_validate, .flyway_migrate, etc.)
.gitlab/ci/generate-deployment-scripts.yml  # Schema-model → migration generation templates (.flyway_generate_migrations, etc.)
.gitlab/ci/generate.yml       # Dynamic pipeline generation template (.generate_pipeline)
scripts/generate_pipeline.py  # Queries registry sproc → builds JDBCs → writes child pipeline YAML
scripts/requirements.txt      # Python dependencies (pymssql, PyYAML)
scripts/client_registry_setup.sql  # SQL to create the registry database + sample data
usage-examples/               # Ready-to-copy .gitlab-ci.yml files for consumer repos
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
- `GIT_PUSH_TOKEN` — GitLab PAT with `api` scope for pushing branches and creating MRs (Protected, Masked)

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

schema-model-dynamic.gitlab-ci.yml is the pipeline that builds both the YML pipeline and the migration scripts from captured schema model

### Template Overview

| Template | Purpose |
|----------|---------|
| **flyway.yml** | Core Flyway job templates (`.flyway_base`, `.flyway_migrate`, `.flyway_validate`, etc.) — the building blocks for running Flyway commands against any database |
| **generate-deployment-scripts.yml** | Schema-model workflow — `.flyway_generate_migrations` runs `flyway diff` to produce migration SQL, `.flyway_commit_migrations` commits them and opens an MR. Uses the Flyway image directly. |
| **generate.yml** | Registry-driven dynamic pipeline — `.generate_pipeline` queries a SQL Server registry DB, discovers all target databases, and writes a `dynamic-pipeline.yml` child pipeline with one `.flyway_migrate` job per target (from flyway.yml). Uses Python. |

**Flow:** `generate-deployment-scripts.yml` *creates* migration scripts → `generate.yml` *discovers where to deploy them* → `flyway.yml` *runs the actual migrations*.

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
  - project: 'root/templatized-with-parser'      # path to THIS repo
    ref: 'main'                                  # pin to a tag or branch
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

### generate-deployment-scripts.yml — Schema Model → Migration Generation

Generate versioned migration scripts from schema-model changes using `flyway diff model` and `flyway diff generate`.  Includes a manual gate that creates a **merge request** so reviewers can inspect the generated SQL diff before merging.

| Template | Purpose | Notes |
|----------|---------|-------|
| `.flyway_generate_migrations` | `flyway diff model` + `flyway diff generate` | Auto-generates V*__*.sql from schema-model diffs |
| `.flyway_commit_migrations` | Push branch + create merge request | Manual gate — opens MR for script review |

Additional CI/CD variables for schema-model workflows:

| Variable | Example | Required | Notes |
|----------|---------|----------|-------|
| `TARGET_DATABASE_JDBC` | `jdbc:sqlserver://host:1433;databaseName=mydb;encrypt=true` | Yes | Dev database (diff source) |
| `SHADOW_DATABASE_JDBC` | `jdbc:sqlserver://host:1433;databaseName=mydb_shadow;encrypt=true` | Yes | Empty DB Flyway rebuilds from migrations |
| `GIT_PUSH_TOKEN` | `glpat-xxxxxxxxxxxx` | Yes* | PAT with `api` scope — see [Git Push Authentication](#git-push-authentication) |
| `GITLAB_EXTERNAL_URL` | `http://localhost:8080` | No | Browser-reachable GitLab URL for MR links (defaults to `CI_SERVER_URL`; set when behind port mapping) |
| `MR_TARGET_BRANCH` | `main` | No | Branch the MR targets (default: `main`) |

\* Required unless CI job token permissions are enabled (Option B below).

See [`usage-examples/schema-model.gitlab-ci.yml`](usage-examples/schema-model.gitlab-ci.yml) for a complete example.

#### Git Push Authentication

The `.flyway_commit_migrations` job pushes a branch and creates a merge request via the GitLab API. This requires write access. Two options:

**Option A — Personal Access Token (recommended for self-hosted GitLab)**

1. Go to your GitLab instance → **Profile → Access Tokens**
2. Create a token with the **`api`** scope (covers both git push and MR creation)
3. Add it as a **CI/CD variable** in your project:
   - **Key:** `GIT_PUSH_TOKEN`
   - **Value:** the token
   - **Protected:** ✓  **Masked:** ✓

This is the simplest approach and works on all GitLab versions.

**Option B — CI Job Token permissions (GitLab 15.9+, GitLab.com)**

1. Go to your project → **Settings → CI/CD → Token permissions**
2. Enable **"Allow CI job token to push to this project"**
3. Under **Settings → Repository → Protected branches**, ensure the job token role can push

With this option, no `GIT_PUSH_TOKEN` variable is needed — the pipeline uses the built-in `CI_JOB_TOKEN`. However, not all GitLab versions support this, and some self-hosted instances restrict job token API access.

> **Which should I use?** Option A is more reliable, especially for local or self-hosted GitLab. Option B is cleaner for GitLab.com since it requires no extra secrets.

### generate.yml — Dynamic Pipeline (100+ Databases)

For large-scale deployments driven by a SQL Server registry database. A single Python script (`scripts/generate_pipeline.py`) calls `dbo.usp_GetFlywayTargets`, builds JDBC URLs from the `dbserver` and `db` columns, and writes a child pipeline with one migrate job per target.

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

### Deploying to Specific Regions

`FILTER_LOCATION` controls which region(s) get deployed. It defaults to `all`.

**Deploy all regions** — leave the default (no action needed):
```yaml
variables:
  FILTER_LOCATION: "all"    # deploys to London, New York, Tokyo, etc.
```

**Deploy one region** — override at run time:
1. Go to your project → **Build → Pipelines → Run pipeline**
2. Select the `main` branch
3. Add variable: `FILTER_LOCATION` = `London` (or `New York`, `Tokyo`)
4. Click **Run pipeline**

Only databases whose `location` column in the registry matches the filter value will be included in the generated child pipeline.

Optional pipeline settings:
| `JDBC_PORT` | `1433` | Port in generated JDBC URLs |
| `RUNNER_TAG_DEFAULT` | _(empty)_ | Single runner tag for all generated jobs (overrides per-location tags) |
| `TEMPLATE_PROJECT` | _(empty)_ | Templates repo path for child pipeline include |
| `TEMPLATE_REF` | `main` | Git ref for cross-project child pipeline include |

## Runner Tags

Generated pipeline jobs are assigned runner tags based on each target's `location`. By default, a location like `Production` produces the tag `runner-production`.

**Override all tags with one value** — set `RUNNER_TAG_DEFAULT` as a CI/CD variable:

```
RUNNER_TAG_DEFAULT = local-runner
```

Every generated job will use `local-runner` instead of per-location tags.

**Per-location overrides** — set `RUNNER_TAG_MAP` as a JSON CI/CD variable:

```
RUNNER_TAG_MAP = {"Production": "prod-runner", "Development": "dev-runner"}
```

Or use individual variables: `RUNNER_TAG_LONDON`, `RUNNER_TAG_NEW_YORK`, `RUNNER_TAG_TOKYO`.

**Priority order:** `RUNNER_TAG_DEFAULT` → `RUNNER_TAG_MAP` → individual `RUNNER_TAG_*` → auto-generated from location name.

## Branch Promotion Strategy

When using a branch-based promotion model (e.g. `dev` → `qa` → `prod`), configure the following project settings to keep branches clean and in sync.

### Recommended Project Settings

Go to **Settings → Merge Requests** in your consumer project and set:

| Setting | Value | Why |
|---------|-------|-----|
| **Merge method** | **Fast-forward merge** | Prevents merge commits that cause branches to diverge ("N commits behind") |
| **Delete source branch** | **Unchecked** | Prevents `dev`/`qa` from being deleted after each MR |

These can also be set via the API:

```bash
curl --request PUT --header "PRIVATE-TOKEN: <token>" \
  "https://gitlab.example.com/api/v4/projects/<id>" \
  --data "merge_method=ff&remove_source_branch_after_merge=false"
```

### Why fast-forward merge?

With the default **merge commit** strategy, each MR from `qa` → `prod` creates a new commit on `prod` that doesn't exist on `qa`. This causes `qa` to fall "behind" `prod`, and subsequent MRs show inflated commit counts.

**Fast-forward merge** avoids this entirely — the target branch pointer simply moves forward to match the source branch. No extra commits, no divergence.

### Branch protection

Protect `qa` and `prod` so changes can only arrive via merge requests:

| Branch | Allowed to push | Allowed to merge |
|--------|----------------|-----------------|
| `dev` | Developers + Maintainers | Developers + Maintainers |
| `qa` | No one | Maintainers |
| `prod` | No one | Maintainers |

### Recovery: branches deleted or diverged

If source branches were accidentally deleted by a previous MR:

```bash
# Recreate from prod (or whichever branch has the latest state)
git fetch origin
git checkout -b qa origin/prod
git push origin qa
git checkout -b dev origin/prod
git push origin dev
```

Or via the GitLab API:

```bash
# Get prod HEAD SHA
curl -s --header "PRIVATE-TOKEN: <token>" \
  "https://gitlab.example.com/api/v4/projects/<id>/repository/branches/prod" \
  | jq -r '.commit.id'

# Create branch from that SHA
curl --request POST --header "PRIVATE-TOKEN: <token>" \
  "https://gitlab.example.com/api/v4/projects/<id>/repository/branches?branch=qa&ref=<sha>"
```

## Usage Examples

See [`usage-examples/`](usage-examples/) for complete `.gitlab-ci.yml` files:

| File | Scenario |
|------|----------|
| `single-db-dev.gitlab-ci.yml` | Single database, dev branch |
| `schema-model.gitlab-ci.yml` | Schema-model → generated migrations with approval gate |
| `schema-model-dynamic.gitlab-ci.yml` | Schema-model + registry-driven dynamic deploy to all targets |
| `staging-and-production.gitlab-ci.yml` | Staging → production with manual approval |
| `multi-database.gitlab-ci.yml` | 2–10 databases with explicit jobs |
| `variable-driven.gitlab-ci.yml` | Variable-driven, no registry or Python |
| `matrix.gitlab-ci.yml` | Parallel matrix for 10–100 databases |
| `dynamic-pipeline.gitlab-ci.yml` | Registry-driven dynamic child pipeline |
| `all-regions.gitlab-ci.yml` | Dynamic pipeline — all regions |
| `region-london.gitlab-ci.yml` | Dynamic pipeline — London only |
| `region-new-york.gitlab-ci.yml` | Dynamic pipeline — New York only |
| `region-tokyo.gitlab-ci.yml` | Dynamic pipeline — Tokyo only |

## Environment-Scoped Variables

For staging/production with different credentials, set the **Environment scope** when creating CI/CD variables:

- Scope `staging` → `TARGET_DATABASE_JDBC = jdbc:sqlserver://staging-db:1433;...`
- Scope `production` → `TARGET_DATABASE_JDBC = jdbc:sqlserver://prod-db:1433;...`

GitLab automatically selects the right variable based on the job's `environment:` setting.

## Further Reading

- [SETUP_GUIDE.md](SETUP_GUIDE.md) — detailed walkthrough
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — one-page cheat sheet
- [Flyway docs](https://documentation.red-gate.com/flyway)
