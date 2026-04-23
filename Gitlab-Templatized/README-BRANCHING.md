# Branching Strategy: Dev → Integration → QA → Prod

## Overview

This project uses a four-branch promotion model for Flyway database migrations:

```
┌─────────┐  MR  ┌─────────────┐   ▶   ┌─────────┐  MR  ┌──────────┐
│   dev   │─────▶│ integration │──────▶│   qa    │─────▶│   prod   │
│ (schema │      │  (generate  │       │ (manual │      │ (manual  │
│  model) │      │   scripts)  │       │  deploy)│      │  deploy) │
└─────────┘      └─────────────┘       └─────────┘      └──────────┘
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

## How It Works: Per-Branch `.gitignore`

Each branch has a different `.gitignore`:

**`dev` branch `.gitignore`** — excludes migrations:
```gitignore
# Flyway ignores
*.user.toml
*.artifact
report.html
report.json

# Migration scripts are generated on the integration branch.
# They must never be committed to dev.
migrations/
```

**`integration` / `qa` / `prod` branch `.gitignore`** — includes migrations:
```gitignore
# Flyway ignores
*.user.toml
*.artifact
report.html
report.json
```

### Protecting `.gitignore` During Merges

When merging `dev → integration`, Git would normally try to bring dev's `.gitignore` (which ignores `migrations/`) into integration. This would break the pipeline.

The solution is a **custom merge driver** that tells Git: "when merging `.gitignore`, always keep the current branch's version."

Every branch has a `.gitattributes` file:
```
.gitignore merge=ours
```

And Git is configured with:
```ini
[merge "ours"]
    driver = true
```

The `driver = true` means "the merge is already resolved — keep ours." This is fully automatic; no manual conflict resolution is needed.

## Replicating This Setup

### Prerequisites

- A Git repository with `schema-model/` and `migrations/` folders
- A `.gitlab-ci.yml` configured for the four-branch workflow (see the project's `.gitlab-ci.yml`)
- The template project (`root/templatized-with-parser`) available in your GitLab instance

### Step 0: Configure GitLab project merge settings

In your GitLab project, go to **Settings → Merge requests**:

1. **Merge method** — select **Merge commit** (the default)
   - The `merge=ours` driver in `.gitattributes` relies on merge commits to auto-resolve `.gitignore` conflicts between branches
   - This is the **only merge method** compatible with this branching strategy — see warning below

2. **Merge options** — uncheck **"Enable 'Delete source branch' option by default"**
   - Branches (`dev`, `integration`, `qa`, `prod`) are long-lived and must never be deleted

> **⚠ Why merge commit is the only option that works**
>
> `integration` will always be **ahead** of `dev` because auto-generated migration commits only exist on `integration` and never flow back to `dev`. This divergence is inherent to the design — migration scripts flow forward only (`integration → qa → prod`).
>
> Additionally, `dev` and `integration` have intentionally different `.gitignore` files (dev excludes `migrations/`, integration does not).
>
> These two factors rule out the other merge methods:
> - **Fast-forward merge** requires the target branch to be a direct ancestor of the source. Since `integration` has commits `dev` doesn't, fast-forward will always fail with "Fast forward merge is not possible. Please rebase."
> - **Rebase** replays commits individually instead of performing a merge. Merge drivers (`merge=ours` on `.gitignore`) only activate during `git merge`, not `git rebase`, so the `.gitignore` conflict cannot auto-resolve and will block the rebase.
>
> **Merge commit** handles both problems: it combines divergent histories and triggers the merge driver to keep each branch's `.gitignore` intact.

### Step 1: Configure the merge driver

Run this once (per clone, or globally with `--global`):

```bash
git config merge.ours.driver true
```

### Step 2: Set up the `dev` branch

```bash
git checkout dev

# Add migrations/ to .gitignore
echo "" >> .gitignore
echo "# Migration scripts are generated on the integration branch." >> .gitignore
echo "# They must never be committed to dev." >> .gitignore
echo "migrations/" >> .gitignore

# Remove migrations from Git's tracking (files stay on disk but are untracked)
git rm --cached -r migrations/

# Add .gitattributes with the merge driver
cat > .gitattributes << 'EOF'
# Keep dev's .gitignore (which excludes migrations/) when merging.
# Requires: git config merge.ours.driver true
.gitignore merge=ours
EOF

git add .gitignore .gitattributes
git commit -m "chore: exclude migrations/ from dev, add merge driver for .gitignore"
```

### Step 3: Create the `integration` branch

Create it from the commit **before** migrations were removed (so it still tracks them):

```bash
# Go back to the commit that still has migrations tracked
git checkout -b integration HEAD~1

# Add .gitattributes (integration's .gitignore does NOT exclude migrations/)
cat > .gitattributes << 'EOF'
# Keep this branch's .gitignore (which includes migrations/) when merging from dev.
# Requires: git config merge.ours.driver true
.gitignore merge=ours
EOF

git add .gitattributes
git commit -m "chore: add merge driver for .gitignore on integration"
```

### Step 4: Create `qa` and `prod` branches

```bash
git checkout -b qa integration
git checkout -b prod integration
```

### Step 5: Push all branches

```bash
git push -u origin dev integration qa prod
```

### Step 6: Set up CI/CD variables in GitLab

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
3. **Create MR**: `dev → integration`
4. **Merge** — integration pipeline auto-runs `flyway diff` and generates migration SQL
5. **Review** the generated scripts in the pipeline artifacts
6. **Click ▶ Play** on `commit:scripts` — commits scripts to `integration` and opens MR → `qa`
7. **Merge to `qa`** — pipeline generates per-region deploy jobs
8. **Click ▶ Play** on the region deploy buttons (▶ london, ▶ new-york, etc.)
9. **Merge to `prod`** — same deploy flow for production

### What if I accidentally merge integration back to dev?

The `merge=ours` driver on `.gitignore` protects you. Dev's `.gitignore` will remain unchanged (still excluding `migrations/`), so the migration files won't appear in dev's working tree. The files would technically be in the merge commit's tree but Git will continue to ignore them.

## Troubleshooting

### "merge driver not found" warnings
Run `git config merge.ours.driver true` in your local clone. This must be set per-clone (it's in `.git/config`, not committed to the repo).

### Migrations appearing on `dev` after a merge
Check that `dev`'s `.gitignore` still contains `migrations/`. If it was overwritten, restore it and re-commit.

### CI pipeline not running on a branch
Ensure the branch name matches exactly (`dev`, `integration`, `qa`, `prod`). The `workflow.rules` in `.gitlab-ci.yml` filter by branch name.

### New developer setup
After cloning, every developer must run:
```bash
git config merge.ours.driver true
```
Consider adding this to a setup script or documenting it in your project's contributing guide.
