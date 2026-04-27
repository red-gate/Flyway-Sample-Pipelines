# Branching Strategy: Dev → Integration → QA → Prod

## Overview

This project uses a four-branch promotion model for Flyway database migrations:

```
┌─────────┐  MR  ┌─────────────┐  MR  ┌─────────┐  MR  ┌──────────┐
│   dev   │─────▶│ integration │─────▶│   qa    │─────▶│   prod   │
│ (schema │      │  (generate  │      │ (manual │      │ (manual  │
│  model) │      │   scripts)  │      │  deploy)│      │  deploy) │
└─────────┘      └─────────────┘      └─────────┘      └──────────┘
```

| Branch        | What lives here                          | Pipeline behaviour                        |
|---------------|------------------------------------------|-------------------------------------------|
| `dev`         | `schema-model/` edits only               | Validates schema-model is well-formed      |
| `integration` | `schema-model/` + generated `migrations/`| Auto-generates migration SQL, manual commit + MR → qa |
| `qa`          | `schema-model/` + `migrations/`          | Per-region deploy buttons (manual)         |
| `prod`        | `schema-model/` + `migrations/`          | Per-region deploy buttons (manual)         |

## Key Design Decision

**Migration scripts must never exist on `dev`.**

Developers only edit `schema-model/` (the declarative SQL object definitions). The CI pipeline on `integration` runs `flyway diff` to compare the schema-model against existing migrations and auto-generates new versioned SQL scripts (`V*__*.sql`, `U*__*.sql`). These scripts flow forward to `qa` and `prod` but are blocked from flowing back to `dev`.

### Why?

- `dev` stays clean — developers think in terms of "what the database should look like", not individual migration steps.
- Migration scripts are a build artifact of the schema-model, generated consistently by CI.
- Prevents accidental manual edits to migration scripts on the development branch.
- Merge conflicts in auto-generated SQL are avoided entirely.

## How It Works: CI Pipeline Guards

Two CI guard jobs enforce the branching policy. They run automatically in every **merge request pipeline** and must pass before the MR can be merged. No special Git configuration, merge drivers, or per-branch `.gitignore` files are needed.

### 1. Merge Direction Guard

Defines the promotion order (`dev → integration → qa → prod`) and **fails the MR pipeline** if the source branch is at the same level or downstream of the target.

| Merge request          | Result  | Reason                           |
|------------------------|---------|----------------------------------|
| `dev → integration`    | ✅ Pass | Forward promotion                |
| `dev → qa`             | ✅ Pass | Forward promotion (skipping)     |
| `integration → qa`     | ✅ Pass | Forward promotion                |
| `qa → prod`            | ✅ Pass | Forward promotion                |
| `prod → qa`            | ❌ Fail | Reverse merge                    |
| `qa → dev`             | ❌ Fail | Reverse merge                    |
| `prod → dev`           | ❌ Fail | Reverse merge                    |
| `feature/xyz → dev`    | ✅ Pass | Feature branches are unrestricted|
| `hotfix/abc → prod`    | ✅ Pass | Feature branches are unrestricted|

The promotion order is configured via the `PROMOTION_ORDER` variable and supports wildcard prefixes (e.g. `qa*` matches `qa`, `qa-london`, `qa-staging`).

### 2. Migration File Guard

**Fails the MR pipeline** if the merge request introduces any changes under `migrations/**` when targeting a protected branch.

| MR target       | `migrations/` changed? | Result  |
|------------------|------------------------|---------|
| `dev`            | Yes                    | ❌ Fail |
| `dev`            | No                     | ✅ Pass |
| `integration`    | Yes                    | ❌ Fail |
| `integration`    | No                     | ✅ Pass |
| `qa`             | Yes                    | ✅ Pass |
| `prod`           | Yes                    | ✅ Pass |

Protected branches are configured via `MIGRATION_PROTECTED_BRANCHES`. Migration scripts committed directly by CI (e.g. the `flyway diff` auto-generation on `integration`) are **not affected** — the guard only runs in MR pipelines.

### How it looks in `.gitlab-ci.yml`

Consumer pipelines include the template and instantiate the guards:

```yaml
include:
  - project: 'root/templatized-with-parser'
    ref: 'main'
    file:
      - '/.gitlab/ci/flyway.yml'
      - '/.gitlab/ci/generate-deployment-scripts.yml'
      - '/.gitlab/ci/merge-guard.yml'

stages:
  - guard        # ← MR pipeline: merge direction + migration checks
  - generate
  - review
  - pipeline
  - deploy

guard:merge-direction:
  extends: .merge_direction_guard
  variables:
    PROMOTION_ORDER: "dev,integration,qa,prod"

guard:migration-files:
  extends: .migration_guard
  variables:
    MIGRATION_PROTECTED_BRANCHES: "dev,integration"
```

## GitLab Project Settings

Two manual settings complete the enforcement. These are configured once per project in the GitLab UI.

### Branch protection

**Settings → Repository → Protected Branches**

Protect each long-lived branch (`dev`, `integration`, `qa*`, `prod`):

| Setting             | Value        | Why                                    |
|---------------------|--------------|----------------------------------------|
| Allowed to merge    | Maintainers  | (or your team's preference)            |
| Allowed to push     | No one       | Forces all changes through merge requests |
| Allow force push    | No           | Prevents history rewriting             |
| Allow deletion      | No           | Long-lived branches must not be deleted |

### Merge request requirements

**Settings → Merge requests**

| Setting                                          | Value   |
|--------------------------------------------------|---------|
| **Pipelines must succeed**                       | Enabled |
| **Enable "Delete source branch" option by default** | Unchecked |

With "Pipelines must succeed" enabled, the guard jobs gate every merge. No merge method constraint is required — merge commit, squash, and rebase are all compatible.

## Replicating This Setup

### Prerequisites

- A Git repository with `schema-model/` and `migrations/` folders
- The template project (`root/templatized-with-parser`) available in your GitLab instance

### Step 1: Create the branches

```bash
git checkout -b dev
git checkout -b integration
git checkout -b qa
git checkout -b prod
git push -u origin dev integration qa prod
```

### Step 2: Add your `.gitlab-ci.yml`

Copy one of the usage examples and adjust for your workflow:

- **Four-branch** (`dev → integration → qa → prod`): see `usage-examples/staging-and-production.gitlab-ci.yml`
- **Two-branch** (`dev → main`): see `usage-examples/schema-model-dynamic.gitlab-ci.yml`

The key additions for guard support are:
1. Include `/.gitlab/ci/merge-guard.yml` in your `include:` block
2. Add `guard` as the first stage
3. Add `merge_request_event` to your `workflow:rules`
4. Instantiate the guard jobs with your promotion order

### Step 3: Configure GitLab project settings

Apply the branch protection and merge request settings described above.

### Step 4: Set up CI/CD variables in GitLab

Navigate to **Settings → CI/CD → Variables** and add:

| Variable                    | Required | Notes                              |
|-----------------------------|----------|------------------------------------|
| `TARGET_DATABASE_JDBC`      | Yes      | Dev database JDBC URL              |
| `TARGET_DATABASE_USER`      | Yes      | Dev database login                 |
| `TARGET_DATABASE_PASSWORD`  | Yes      | Protected + Masked                 |
| `SHADOW_DATABASE_JDBC`      | Yes      | Shadow/build database JDBC URL     |
| `QA_REGISTRY_SERVER`        | Yes      | QA registry SQL Server             |
| `QA_REGISTRY_USER`          | Yes      | QA registry login                  |
| `QA_REGISTRY_PASSWORD`      | Yes      | Protected + Masked                 |
| `QA_TARGET_DATABASE_USER`   | Yes      | QA target database login           |
| `QA_TARGET_DATABASE_PASSWORD`| Yes     | Protected + Masked                 |
| `PROD_REGISTRY_SERVER`      | Yes      | Prod registry SQL Server           |
| `PROD_REGISTRY_USER`        | Yes      | Prod registry login                |
| `PROD_REGISTRY_PASSWORD`    | Yes      | Protected + Masked                 |
| `FLYWAY_EMAIL`              | Yes      | Flyway license email               |
| `FLYWAY_TOKEN`              | Yes      | Protected + Masked                 |

## Daily Workflow

### Making a schema change

1. **On `dev`**: Edit files in `schema-model/` (e.g. add a column to `Tables/dbo.Products.sql`)
2. **Push** to `dev` — pipeline validates the schema-model
3. **Create MR**: `dev → integration` — guard pipeline runs and must pass
4. **Merge** — integration pipeline auto-runs `flyway diff` and generates migration SQL
5. **Review** the generated scripts in the pipeline artifacts
6. **Click ▶ Play** on `commit:scripts` — commits scripts to `integration` and opens MR → `qa`
7. **Merge to `qa`** — guard pipeline passes (forward merge, migrations allowed on qa), then per-region deploy jobs appear
8. **Click ▶ Play** on the region deploy buttons (▶ london, ▶ new-york, etc.)
9. **Merge to `prod`** — same deploy flow for production

### What if someone tries to merge backward?

The merge direction guard blocks it. For example, if someone creates an MR from `prod → dev`, the guard pipeline fails with:

```
=========================================
  BLOCKED — reverse merge detected
=========================================

  prod (rank 3) → dev (rank 0)

  Promotions must flow forward:
  dev,integration,qa,prod

  Reverse or same-level merges are not allowed.
=========================================
```

The MR cannot be merged until the pipeline passes, which it never will for a reverse merge.

## Troubleshooting

### Guard pipeline not running on merge requests
Ensure your `workflow:rules` includes `merge_request_event`:
```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "dev"
    # ...
```

### Guard passes but MR still blocked
Check **Settings → Merge requests** — "Pipelines must succeed" must be enabled. Also verify the branch is protected in **Settings → Repository → Protected Branches**.

### CI pipeline not running on a branch
Ensure the branch name matches exactly (`dev`, `integration`, `qa`, `prod`). The `workflow:rules` in `.gitlab-ci.yml` filter by branch name.

### Someone pushed directly to a protected branch
Verify **Allowed to push** is set to "No one" for the branch in **Settings → Repository → Protected Branches**. Direct pushes bypass MR pipelines and therefore bypass the guards.

### Migration guard false positive
If the migration guard blocks an MR that shouldn't be blocked, check the `MIGRATION_PROTECTED_BRANCHES` variable. Only `dev` and `integration` should be listed — `qa` and `prod` need to accept migration file changes via promotion.

### Duplicate pipelines (branch + MR)
When an MR is open, GitLab may run both a branch pipeline (on push) and an MR pipeline. This is expected — the branch pipeline handles the normal workflow (generate scripts, deploy), while the MR pipeline runs the guards. Only the MR pipeline gates the merge.
