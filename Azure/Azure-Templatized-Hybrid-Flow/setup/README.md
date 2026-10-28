# Setup: the Northwind hybrid flow on your own machine

These scripts build the whole flow on one machine: the databases, the Azure DevOps project, its repos, pipelines, variable groups, environments, policies and permissions, and a pipelines agent. You end up with a working demo you can change from Flyway Desktop.

```
schema change on dev ──> 1 Generate ──> review PR (versioned + undo scripts) ──> approve
                     ──> 2 Integration: check -dryrun -code, deploy integration ──> PR dev -> main ──> approve
                     ──> 3 Release: check -drift -code -changes -dryrun, deploy test, then prod
```

## What gets created

Every name comes from `Prefix` in `settings.ps1`, which defaults to `northwind`. Variable group and environment names come from `..\pipeline-settings.yml`, the file the pipelines read, with `projectName` set to `Prefix`, so the scripts and the pipelines always agree.

| What | Names |
|---|---|
| Databases | `northwind-dev` (Flyway Desktop), `-shadow` and `-check` (build databases that Flyway restores from the baseline backup), `-integration`, `-test`, `-prod`, and `-baseline` (the schema at V001, the source of the backup) |
| Baseline backup | `northwind-baseline.bak`, schema only, in SQL Server's default backup folder (or `BaselineBackupPath` in `settings.ps1`) |
| Azure DevOps project | `northwind` |
| Repos | `northwind` (the Flyway project, branches `dev` and `main`), `flyway-templates-hybrid` (the templates) |
| Pipelines | `northwind - 1 Generate`, `- 2 Integration`, `- 3 Release` |
| Variable groups | `northwind_pipeline_vars`, `northwind_build_credentials` (shadow database), `northwind_integration_credentials`, `northwind_test_credentials`, `northwind_prod_credentials`, `northwind_release_build_credentials` (check database). Same names as the other Flyway samples |
| Environments | `northwind-integration`, `-test`, `-prod` |

## Before you start

- Windows with PowerShell 5.1, Git, and the SQL Server command line tools (`sqlcmd`).
- SQL Server. Express is fine, but turn on TCP/IP with a fixed port (1433) in SQL Server Configuration Manager, because Flyway connects over TCP. Step 0 checks this.
- Azure DevOps. If the machine already has Azure DevOps Server, use it (see [Azure DevOps already installed](#azure-devops-already-installed)). Otherwise `install-azure-devops-server.ps1` installs the free Express edition. An Azure DevOps Services organisation with a PAT works too.
- Flyway Desktop, which puts the Flyway CLI on PATH, and a Flyway Enterprise licence. Put your token in `setup\.env`:

  ```
  token=<personal access token>
  email=<your email>
  ```

  `.env` is git-ignored. Never run `flyway auth` on the agent. The agent reads this file every time it starts.

## Steps

Edit `settings.ps1` first. The defaults suit a local Azure DevOps Server and SQL Server on `localhost:1433` with Windows auth. Then, from this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass   # this window only; needed for scripts from a downloaded zip
.\0-check-prerequisites.ps1     # changes nothing; fix any FAIL lines
.\1-create-databases.ps1        # databases (dev, integration, test, prod migrated) and the baseline backup
.\2-setup-azure-devops.ps1      # project, repos, groups, environments, pipelines, policies, permissions, checks
.\3-setup-agent.ps1             # downloads, registers and starts a pipelines agent (leave its window open)
```

All four are safe to re-run. Add `-EmptyTargets` to step 1 to leave integration, test and prod empty, so the first pipeline runs deploy everything.

With Azure DevOps Server on the same machine, run `.\4-start-local-ado.ps1` after every reboot, and whenever runs queue but never start. It starts whatever has stopped, including the pipelines agent.

Then clone the `northwind` repo and open it in Flyway Desktop. `setup\northwind` is only the seed the repo was created from. Change the schema model and push to `dev`, or merge a feature branch into `dev`. Approve the PRs as they appear: each run has a "➜ Link to the …" step with the link.

## Azure DevOps already installed

For example, a VM with its own Azure DevOps Server. Skip `install-azure-devops-server.ps1` and run steps 0 to 3 as usual. Step 2 creates a new project, and everything else it adds goes inside that project, apart from a new agent pool if you name one.

- **`CollectionUrl`:** the server's collection, for example `http://<server>/DefaultCollection`. Run the scripts as someone who can create projects, for example a Project Collection Administrator. Step 0 checks this.
- **`AgentPool`:** if the `Default` pool already has agents, give the flow a pool of its own, for example `flyway`, or runs can land on agents without Flyway. Step 2 creates the pool, and step 3 adds this machine's agent to it. Step 0 warns when the pool has other agents.
- **Version:** step 0 shows the server's REST API version. The scripts were tested on Azure DevOps Server 25H2. On Azure DevOps Server 2022 they fall back to its API version, 7.0. Step 2 also runs cleanly with every call forced to 7.0, but nothing has been run on a real 2022 server. Step 3 installs the agent version the server hands out.
- **SQL Server:** the databases can go on the instance that hosts Azure DevOps, or any other. Set `SqlCmdServer` and `JdbcServer` to it.

## Things the scripts take care of

These are easy to miss when doing it by hand:

- **Default queue:** a pipeline created through the API has no default queue, and on Azure DevOps Server every run then fails with "No pool was specified".
- **Default branch:** Generate and Integration default to `dev`, Release to `main`, so Run pipeline starts on the right branch. It's a pipeline setting, not something the YAML can set.
- **Pre-authorized resources:** each pipeline is authorized up front, and only for the resources it uses, so the first runs don't stop at "Permission needed". Only Release can reach the test and prod groups and environments.
- **Branch policies:**
  - `dev` needs one reviewer, and votes reset on push, so scripts added to an open review PR need a fresh approval.
  - `main` needs one reviewer and the status `flyway/validated`, so only the commit Integration checked can merge.
  - The templates repo's `main` is protected too.
- **Branch control checks:** test and prod only accept runs from a protected `main`. The check covers every repo a run uses, which is why the templates repo is protected.
- **Build service permissions:**
  - It can push generated scripts under `migrations/` and delete those branches when their PRs complete.
  - It can open and complete PRs.
  - It can never bypass the policies on `main`.
- **Direct pushes to `dev`:** you get "Bypass policies when pushing" on `dev`, so schema changes can be committed straight there. Use `-NoDevBypass` to skip this.
- **Baseline backup:** step 1 backs up `-baseline` (the schema at V001, no data) and step 2 writes its path and version into `pipeline-settings.yml`. On every run Flyway restores that backup into `-shadow` and `-check` and applies the later migrations, so don't keep anything in them. SQL Server reads the backup path, so with SQL Server on another machine, put the backup on a file share it can reach and set `BaselineBackupPath`. Run step 1 with `-RefreshBaseline` to remake it. The release check refuses to run if its build database is ever the target.
- **AUTO_CLOSE:** it's turned off on every database. SQL Express turns it on by default, and with it on, connections get slow and the Azure DevOps job agent's database lease times out.
- **Flyway Desktop's project file:** `flyway.toml` in the repo points at your `-dev`, `-shadow` and `-integration` databases. With a SQL login instead of Windows auth, put user and password in `flyway.user.toml`, which isn't committed.

## Not covered

- **Azure DevOps Services:** the scripts take a PAT and use the Services endpoints. They were only run against Azure DevOps Server 25H2.
- **Code analysis:** `check -code` uses SQLFluff. Flyway Desktop bundles it. The standalone Flyway CLI needs SQLFluff available.
- **Removing it:** delete the project in Collection settings > Projects, drop the seven databases and delete the baseline backup. No script does this.
