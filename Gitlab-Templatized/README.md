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
| `.flyway_undo` | `flyway undo` | Revert the last applied migration (manual; needs `U*__*.sql` undo scripts) |
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

## Undo Pipeline

Undo reverts the most recently applied migration on your targets. It runs as a
**separate pipeline** — never as part of the deploy pipeline — so it has its own
run, its own approval gate, and its own audit trail. The deploy pipeline never
shows undo jobs, and the undo pipeline never shows deploy jobs.

The same generator (`generate_pipeline.py`) powers it: set `PIPELINE_MODE: "undo"`
and it emits one `flyway undo` job per target (extending `.flyway_undo`) instead
of check + migrate. Region selection via `FILTER_LOCATION` works exactly as it
does for deploys.

### What lives where

The undo pipeline is a collaboration between **this templates repo** (the reusable
building blocks) and **your consumer project** (the control structure). Neither
half is the whole pipeline on its own:

| Piece | Lives in | What it provides |
|-------|----------|------------------|
| `.flyway_undo` job template | **templates repo** — [`.gitlab/ci/flyway.yml`](.gitlab/ci/flyway.yml) | Runs `flyway undo` (+ snapshot/info); manual by default |
| `PIPELINE_MODE=undo` | **templates repo** — [`scripts/generate_pipeline.py`](scripts/generate_pipeline.py) | Emits one undo job per registry target |
| `PIPELINE_TYPE` gating | **consumer project** — its `.gitlab-ci.yml` | Makes undo a *separate* pipeline from deploy |
| `generate:undo:*` jobs | **consumer project** | Call the generator per region with `PIPELINE_MODE=undo` |
| `approve:undo:*` gate | **consumer project** | The manual approval gate |
| `undo:*` trigger buttons | **consumer project** | Per-region + all-regions undo, gated behind approval |

In other words, the templates repo knows *how to undo one database*; the consumer
project decides *when, where, and with what approvals*. The consumer-side half is
illustrated fully in the sample consumer pipeline
[`usage-examples/undo-dynamic.gitlab-ci.yml`](usage-examples/undo-dynamic.gitlab-ci.yml),
and the key jobs are walked through under [Wiring it into a consumer pipeline](#wiring-it-into-a-consumer-pipeline) below.

### Prerequisites

- **Undo scripts** (`U*__*.sql`) must sit alongside your versioned migrations —
  Flyway can only undo a version that ships an undo script.
- Undo is a **Flyway Enterprise/Teams** feature (your `FLYWAY_TOKEN` must cover it).
- By default `flyway undo` reverts only the **last** applied migration on each
  target. To undo down to a specific version, set `FLYWAY_TARGET` (e.g.
  `FLYWAY_TARGET: "3"` undoes everything applied above V3).

### How to run it

The undo pipeline is gated by a top-level `PIPELINE_TYPE` variable. Normal runs
default to `deploy`; you launch undo on demand:

1. **Build → Pipelines → Run pipeline**
2. Pick the branch you want to undo on (e.g. `qa` or `prod`)
3. Add a variable: **`PIPELINE_TYPE`** = **`undo`**
4. **Run pipeline**

You get a pipeline containing only the undo flow:

```
generate:undo:<region>   ← auto: queries the registry, builds the undo plan
        │
        ▼
approve:undo:<env>       ← manual approval gate — blocks everything below
        │
        ▼
undo:<region>            ← manual, per-region: all / london / new-york / tokyo
                            each triggers a child pipeline of `flyway undo` jobs
```

Click the approval gate first, then the specific region button(s) you want to
undo — or `undo:*:all` to undo every region.

### Wiring it into a consumer pipeline

Gate every existing (deploy-side) job with `$PIPELINE_TYPE != "undo"` so they sit
out undo runs, and add the undo jobs gated on `$PIPELINE_TYPE == "undo"`. Set the
default in your top-level `variables:`:

```yaml
variables:
  PIPELINE_TYPE: "deploy"   # overridden to "undo" at run time

# --- deploy-side job: excluded from undo runs ---
generate:qa:all:
  extends: .generate_base
  variables:
    FILTER_LOCATION: "all"
    OUTPUT_FILE: "dynamic-pipeline-qa-all.yml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "qa" && $PIPELINE_TYPE != "undo"'

# --- undo plan generation: only in undo runs ---
generate:undo:qa:all:
  extends: .generate_base
  variables:
    PIPELINE_MODE: "undo"           # ← emit `flyway undo` jobs
    FILTER_LOCATION: "all"
    OUTPUT_FILE: "undo-pipeline-qa-all.yml"
  artifacts:
    paths: ["undo-pipeline-qa-all.yml"]
  rules:
    - if: '$PIPELINE_TYPE == "undo" && $CI_COMMIT_BRANCH == "qa"'

# --- approval gate: blocks the undo buttons until played ---
approve:undo:qa:
  stage: approve
  script: [ 'echo "QA undo approved by ${GITLAB_USER_LOGIN}"' ]
  rules:
    - if: '$PIPELINE_TYPE == "undo" && $CI_COMMIT_BRANCH == "qa"'
      when: manual
      allow_failure: false

# --- per-region undo button (gated behind the approval) ---
undo:qa:all:
  stage: undo
  needs: ["generate:undo:qa:all", "approve:undo:qa"]
  trigger:
    include:
      - artifact: undo-pipeline-qa-all.yml
        job: generate:undo:qa:all
    strategy: depend
  rules:
    - if: '$PIPELINE_TYPE == "undo" && $CI_COMMIT_BRANCH == "qa"'
      when: manual
```

Add `approve` and `undo` to your `stages:` list.

**Two ways to keep undo separate** — pick whichever fits your repo:

- **Variable-gated (shown above):** undo jobs live in the same `.gitlab-ci.yml`
  as deploy but are gated by `PIPELINE_TYPE`, so only one set runs per pipeline.
  Launch via *Run pipeline* + `PIPELINE_TYPE=undo`. Lowest friction.
- **Standalone config:** undo lives in its own file that is *entirely* an undo
  pipeline (no gating needed). Run it via a pipeline schedule or trigger. See
  [`usage-examples/undo-dynamic.gitlab-ci.yml`](usage-examples/undo-dynamic.gitlab-ci.yml)
  for a complete, ready-to-copy example with per-region and all-regions buttons.

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
| `undo-dynamic.gitlab-ci.yml` | Registry-driven `flyway undo` with per-region + all-regions buttons |

## Further Reading

- [SETUP_GUIDE.md](SETUP_GUIDE.md) — detailed walkthrough
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — one-page cheat sheet
- [Flyway docs](https://documentation.red-gate.com/flyway)
