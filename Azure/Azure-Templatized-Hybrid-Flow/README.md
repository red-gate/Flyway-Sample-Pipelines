# Azure DevOps templatized hybrid flow

Three pipelines share one set of templates. Each pipeline only contains the stages it runs, so no run shows skipped stages.

1. **Generate** runs when `schema-model/`, `flyway.toml` or `Filter.scpf` changes on `dev`. If the schema model is ahead of the migrations, it generates the versioned script and its undo script, and opens a **review PR** into `dev`. Edit the scripts on that PR's branch if you need to, then approve it. If a review PR is already open, the new scripts are added to that PR instead, so one approval covers everything.
2. **Integration** runs on every change to `dev` except schema-model-only ones, for example when a review PR merges. It runs `flyway check -dryrun -code` against **integration**, publishes the HTML and JSON report as an artifact, deploys to integration, and opens a PR from `dev` to `main`. Code analysis findings are flagged as warnings on the run and listed in the report, and never stop the deployment. Set `failOnCodeError: true` to block on error-level findings instead.
3. **Release** runs when that PR merges into `main`. It deploys to **test**, then **prod**. Before each deploy it runs `flyway check -drift -code -changes -dryrun` and `flyway info` against that database, and publishes the results as HTML and JSON in the `check-report-test` or `check-report-prod` artifact, with a summary on the run. Drift and code findings are warnings, and the deployment carries on. Drift and changes are worked out in a separate build database that Flyway cleans.

Straight after any step that opens a PR, a step named **➜ Link to the review PR** or **➜ Link to the pull request** has the link in its log. The run title also says what to do next, for example "20261026.5 - approve review PR 8", and a warning on the run summary repeats the link.

Schema-model changes can be committed on a feature branch and merged into `dev`, or committed straight to `dev`.

## Project setup: two repos

The templates go in their own repo so every project can reuse them.

```
your-flyway-project/                  Repo 1: one per database project
├── flyway.toml
├── Filter.scpf
├── schema-model/
├── migrations/
├── azure-pipelines-generate.yml      ← sample-generate-pipeline.yml
├── azure-pipelines-integration.yml   ← sample-integration-pipeline.yml
└── azure-pipelines-release.yml       ← sample-release-pipeline.yml

flyway-templates-hybrid/              Repo 2: shared by all projects
├── stage-pr-review.yml
├── stage-generate-review.yml         generate versioned + undo scripts into a review PR (used by Generate)
├── stage-generate.yml                generate and commit straight to dev (alternative)
├── stage-check-report.yml
├── stage-deploy.yml
├── stage-promote.yml
├── job-dry-run.yml
├── steps-check-summary.yml           summary + warnings for any check report
├── steps-deploy-checks.yml           drift, changes, code, dry-run and migrations reports before a deploy
├── steps-checkout-commit.yml
├── steps-pr-link.yml                 "➜ Link to the PR" step, right after a PR is opened
└── steps-resolve-auth.yml
```

- **Your Flyway project repo:** copy the three `sample-*-pipeline.yml` files into the root of your Flyway project.
- **Templates repo:** copy everything in `flyway-templates-hybrid/` into a separate repo called `flyway-templates-hybrid`. The pipelines reference it as `@templates`.

To keep everything in one repo instead, put the templates in a `flyway-templates-hybrid/` folder and drop the `@templates` suffix from each `template:` line.

## In Azure DevOps

1. **Pipelines:** create three pipelines from the same project repo, one for each YAML file. Name them in order, for example `1 Generate`, `2 Integration` and `3 Release`, so they sort in flow order.
2. **Variable groups:** under Pipelines > Library, create `<project>_pipeline_vars`, `<project>_build_credentials`, `<project>_integration_credentials`, `<project>_test_credentials` and `<project>_prod_credentials`, plus `<project>_release_build_credentials` (build_database_JDBC, build_databaseName, build_userName, build_password) for a scratch build database the release reports can clean. The header of each YAML file lists their keys.
3. **Environments:** create `<Project>Integration`, `<Project>Test` and `<Project>Prod`.
4. **Branches:** create `dev` and `main`.
5. **Policy on `dev`:** require at least one reviewer, so review PRs need an approval before they auto-complete. If people commit straight to `dev`, give them "Bypass policies when pushing" on `dev`.
6. **Policy on `main`:** require at least one reviewer, and require the status `flyway/validated`, reset on every push. Integration posts that status only for the exact commit it checked and deployed.
7. **Branch control:** add a Branch control check on the test and prod environments and their credential groups. Allow `refs/heads/main` and require it to be protected. The check covers the templates repo too, so protect its `main` as well.
8. **Build service permissions:** give the build service Contribute and Contribute to pull requests on the project repo, plus Create branch and Force push under `migrations/`. Force push lets it delete review branches.

## Azure DevOps Server (on-premises)

These templates use Build Artifacts rather than Pipeline Artifacts, so they also run on Azure DevOps Server.
