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

- **Your Flyway project repo:** copy the three `sample-*-pipeline.yml` files into the root of your Flyway project. Everything that changes from project to project is in the "Per project" block at the top of each file. Usually only `projectName` changes: the variable group and environment names follow from it. Values that appear in more than one file, such as `projectName` and the branch names, must match. The trigger branch, agent pool and templates repo name are written out in full, because Azure Pipelines doesn't allow variables there.
- **Templates repo:** copy everything in `flyway-templates-hybrid/` into a separate repo called `flyway-templates-hybrid`. The pipelines reference it as `@templates`.

To keep everything in one repo instead, put the templates in a `flyway-templates-hybrid/` folder and drop the `@templates` suffix from each `template:` line.

## In Azure DevOps

To build all of this on one machine, including the databases and a pipelines agent, run the scripts in [setup/](setup/README.md). They create everything below, with the `northwind` names the sample pipelines use.

To set it up by hand:

1. **Pipelines:** create three pipelines from the same project repo, one for each YAML file (New pipeline > Azure Repos Git > your repo > Existing Azure Pipelines YAML file). Name them in order, for example `1 Generate`, `2 Integration` and `3 Release`, so they sort in flow order.
   - **Default branch:** Generate and Integration need `dev`, Release needs `main`. It's the branch a manual run (Run pipeline) uses, and it's a setting on each pipeline: the YAML can't set it. Pick that branch in the Branch box when you select the YAML file. To check or change it later, open the pipeline and go to Edit > ⋮ > Triggers > YAML > Get sources > Default branch for manual and scheduled builds.
2. **Variable groups:** under Pipelines > Library, create the six groups named at the top of the pipelines. With `projectName: northwind` they are `northwind_pipeline_vars`, `northwind_build_credentials`, `northwind_integration_credentials`, `northwind_test_credentials`, `northwind_prod_credentials` and `northwind_release_build_credentials`. `northwind_build_credentials` (Generate's shadow database) and `northwind_release_build_credentials` point at empty build databases that Flyway cleans. The header of each YAML file lists their keys.
3. **Environments:** create the three named at the top of the pipelines: `northwind-integration`, `northwind-test` and `northwind-prod`.
4. **Branches:** create `dev` and `main`.
5. **Policy on `dev`:** require at least one reviewer, so review PRs need an approval before they auto-complete. If people commit straight to `dev`, give them "Bypass policies when pushing" on `dev`.
6. **Policy on `main`:** require at least one reviewer, and require the status `flyway/validated`, reset on every push. Integration posts that status only for the exact commit it checked and deployed.
7. **Branch control:** add a Branch control check on the test and prod environments and their credential groups. Allow `refs/heads/main` and require it to be protected. The check covers the templates repo too, so protect its `main` as well.
8. **Build service permissions:** give the build service Contribute and Contribute to pull requests on the project repo, plus Create branch and Force push under `migrations/`. Force push lets it delete review branches.

## Baseline backup for the shadow and check databases

Generate's shadow database and Release's check database start from a schema-only backup instead of being built from the very first migration. Flyway restores the backup, then applies only the later migrations. See [Use a SQL Server backup to baseline a database](https://documentation.red-gate.com/flyway/learn-more-about-flyway/how-to-articles/use-a-sql-server-backup-to-baseline-a-database).

- **Settings:** set `baselineBackupPath` and `baselineBackupVersion` at the top of the Generate and Release pipelines, with the same values in both. Leave the path empty to have Flyway clean those databases and apply every migration instead.
- **Where the backup lives:** SQL Server restores it, so the path is read by the SQL Server that hosts the shadow and check databases, not by the agent. Put the backup on a file share that SQL Server can reach, or on that server itself.
- **Schema only:** make it with `DBCC CLONEDATABASE`, as the Redgate article describes, so no data goes into it.
- **The version:** `baselineBackupVersion` is the version of the newest migration already in the backup. With Flyway Desktop's timestamped file names that's the full version: `V001_20261013185549__Initial.sql` is `001.20261013185549`, not `001`. If the backup includes `flyway_schema_history`, Flyway uses the history recorded there instead, so a backup taken from another Flyway project fails validation ("Detected applied migration not resolved locally"). Drop that table before taking the backup.
- **Licence:** restoring from a backup needs Flyway Enterprise.

## Azure DevOps Server (on-premises)

The templates run on Azure DevOps Server 2020 and later, as well as Azure DevOps Services:

- **Artifacts:** they use Build Artifacts (`PublishBuildArtifacts@1`, `DownloadBuildArtifacts@0`), because Azure DevOps Server doesn't support Pipeline Artifacts.
- **REST API:** the PR and policy calls use REST API version 6.0, the oldest these calls need. Newer servers accept it too. To use a different version, set the `adoApiVersion` parameter of `stage-generate-review.yml` and `stage-promote.yml`.
- **Tested:** end to end on Azure DevOps Server 25H2. Azure DevOps Server 2020 hasn't been confirmed end to end yet.
