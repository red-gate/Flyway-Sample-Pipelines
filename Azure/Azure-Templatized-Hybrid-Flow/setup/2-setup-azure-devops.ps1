<#
Step 2: sets up Azure DevOps for the flow. Safe to re-run: it reuses what exists and only adds
what is missing (variable group values and policies are brought back in line with settings.ps1).

  .\2-setup-azure-devops.ps1

Creates, in project <prefix>:
  repos          <prefix>                  the Flyway project (setup\northwind-hybrid) plus the three
                                           pipeline files, on branches dev (default) and main
                 flyway-templates-hybrid   the templates (..\flyway-templates-hybrid), branch main
                 (a repo that already has commits is left alone)
  variable groups <prefix>-pipeline-vars, <prefix>-{shadow,integration,test,prod}-credentials,
                 <prefix>-check-credentials (build database for the release drift/changes reports)
  environments   <prefix>-integration, <prefix>-test, <prefix>-prod
  pipelines      "<prefix> - 1 Generate", "<prefix> - 2 Integration", "<prefix> - 3 Release",
                 each authorized only for the resources it uses
  policies       dev:  1 reviewer, your own vote counts, reset on push (review PRs, feature PRs)
                 main: 1 reviewer, creator vote doesn't count, reset on push + required status
                       flyway/validated (only the commit Integration checked can merge)
                 templates repo main: 1 reviewer (Branch control checks need it protected)
  permissions    build service: contribute + contribute to PRs on the repo; create/delete branches
                 under migrations/; bypass denied on main. You: bypass policies when pushing to dev
                 (so schema changes can be committed straight to dev; -NoDevBypass to skip)
  checks         Branch control on the test/prod environments and credential groups: only runs
                 from the protected main branch can deploy there
#>
param([switch]$NoDevBypass)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
$PU = "$C/$($Names.Project)"

# --- project ----------------------------------------------------------------------------------
Write-Step "Project $($Names.Project)"
$proj = (Invoke-Ado GET "$C/_apis/projects?`$top=500&api-version=7.1").value | Where-Object name -eq $Names.Project
if (-not $proj) {
    $process = (Invoke-Ado GET "$C/_apis/process/processes?api-version=7.1").value | Where-Object name -eq 'Agile' | Select-Object -First 1
    $op = Invoke-Ado POST "$C/_apis/projects?api-version=7.1" @{
        name = $Names.Project; description = 'Flyway hybrid flow: schema model -> review PR -> integration -> main -> test, prod'
        capabilities = @{ versioncontrol = @{ sourceControlType = 'Git' }; processTemplate = @{ templateTypeId = $process.id } }
    }
    do { Start-Sleep -Seconds 3; $st = Invoke-Ado GET "$C/_apis/operations/$($op.id)?api-version=7.1" } while ($st.status -in 'notSet', 'queued', 'inProgress')
    if ($st.status -ne 'succeeded') { throw "Project creation failed: $($st.status) $($st.resultMessage)" }
    $proj = (Invoke-Ado GET "$C/_apis/projects?`$top=500&api-version=7.1").value | Where-Object name -eq $Names.Project
    Write-Host "  created"
} else { Write-Host "  exists" }
$projId = $proj.id

# --- agent queue ------------------------------------------------------------------------------
$queue = (Invoke-Ado GET "$PU/_apis/distributedtask/queues?queueName=$([uri]::EscapeDataString($S.AgentPool))&api-version=7.1").value | Select-Object -First 1
if (-not $queue) {
    $pool = (Invoke-Ado GET "$C/_apis/distributedtask/pools?poolName=$([uri]::EscapeDataString($S.AgentPool))&api-version=7.1").value | Select-Object -First 1
    if (-not $pool) {
        # A pool of its own keeps runs off agents that have no Flyway. autoProvision off: only this
        # project gets a queue for it.
        $pool = Invoke-Ado POST "$C/_apis/distributedtask/pools?api-version=7.1" @{ name = $S.AgentPool; autoProvision = $false }
        Write-Host "  created agent pool $($S.AgentPool)"
    }
    $queue = Invoke-Ado POST "$PU/_apis/distributedtask/queues?api-version=7.1" @{ name = $S.AgentPool; pool = @{ id = $pool.id } }
    Write-Host "  added agent queue $($S.AgentPool)"
}

# --- repos ------------------------------------------------------------------------------------
function Get-Repo([string]$name) {
    $r = (Invoke-Ado GET "$PU/_apis/git/repositories?api-version=7.1").value | Where-Object name -eq $name
    if (-not $r) { $r = Invoke-Ado POST "$PU/_apis/git/repositories?api-version=7.1" @{ name = $name; project = @{ id = $projId } }; Write-Host "  created repo $name" }
    $r
}
function Test-RepoEmpty($repo) { -not (Invoke-Ado GET "$PU/_apis/git/repositories/$($repo.id)/refs?filter=heads/&api-version=7.1").value }
function New-Workdir { $d = Join-Path $env:TEMP "$($Names.Project)-seed-$([guid]::NewGuid().ToString('N').Substring(0,8))"; New-Item -ItemType Directory $d | Out-Null; $d }

Write-Step "Repo $($Names.TemplatesRepo)"
$tmplRepo = Get-Repo $Names.TemplatesRepo
if (Test-RepoEmpty $tmplRepo) {
    $w = New-Workdir
    Copy-Item "$Kit\flyway-templates-hybrid\*.yml" $w
    Push-Folder $w $tmplRepo.remoteUrl @($Names.MainBranch) 'Flyway hybrid flow templates'
    Write-Host "  seeded $($Names.MainBranch) from $Kit\flyway-templates-hybrid"
} else { Write-Host '  has commits: left as it is' }

Write-Step "Repo $($Names.Repo)"
$repo = Get-Repo $Names.Repo
if (Test-RepoEmpty $repo) {
    $w = New-Workdir
    Copy-Item -Recurse "$SeedProject\*" $w
    Copy-Item "$SeedProject\.gitignore" $w
    @{ 'sample-generate-pipeline.yml' = 'azure-pipelines-generate.yml'; 'sample-integration-pipeline.yml' = 'azure-pipelines-integration.yml'; 'sample-release-pipeline.yml' = 'azure-pipelines-release.yml' }.GetEnumerator() |
        ForEach-Object { Copy-Item "$Kit\$($_.Key)" (Join-Path $w $_.Value) }
    # Point the files at this setup: names (if the prefix changed), file names, SQL Server, auth, pool.
    foreach ($f in Get-ChildItem $w -File | Where-Object { $_.Extension -in '.yml', '.toml' }) {
        $t = [IO.File]::ReadAllText($f.FullName)
        $t = $t.Replace('northwind-hybrid', $Prefix).Replace('sample-generate-pipeline.yml', 'azure-pipelines-generate.yml').Replace('sample-integration-pipeline.yml', 'azure-pipelines-integration.yml').Replace('sample-release-pipeline.yml', 'azure-pipelines-release.yml')
        $t = $t.Replace('jdbc:sqlserver://localhost:1433;', "jdbc:sqlserver://$($S.JdbcServer);")
        if ($S.SqlUser) { $t = $t.Replace('integratedSecurity=true;', '') }
        $t = $t -replace '(?m)^(pool:\s*\r?\n\s*name:\s*)Default\b', "`${1}$($S.AgentPool)"
        [IO.File]::WriteAllText($f.FullName, $t, (New-Object Text.UTF8Encoding $false))
    }
    Push-Folder $w $repo.remoteUrl @($Names.DevBranch, $Names.MainBranch) "Flyway project $Prefix with the generate, integration and release pipelines"
    Write-Host "  seeded $($Names.DevBranch) and $($Names.MainBranch) from $SeedProject"
} else { Write-Host '  has commits: left as it is' }
Invoke-Ado PATCH "$PU/_apis/git/repositories/$($repo.id)?api-version=7.1" @{ defaultBranch = "refs/heads/$($Names.DevBranch)" } | Out-Null
Invoke-Ado PATCH "$PU/_apis/git/repositories/$($tmplRepo.id)?api-version=7.1" @{ defaultBranch = "refs/heads/$($Names.MainBranch)" } | Out-Null

# --- variable groups --------------------------------------------------------------------------
Write-Step 'Variable groups'
function Set-Group([string]$name, [string]$description, [System.Collections.IDictionary]$vars) {
    $variables = @{}
    foreach ($k in $vars.Keys) { $variables[$k] = @{ value = [string]$vars[$k]; isSecret = ($k -like '*password') } }
    $body = @{ name = $name; type = 'Vsts'; description = $description; variables = $variables
               variableGroupProjectReferences = @(@{ name = $name; description = $description; projectReference = @{ id = $projId; name = $Names.Project } }) }
    $g = (Invoke-Ado GET "$PU/_apis/distributedtask/variablegroups?groupName=$([uri]::EscapeDataString($name))&api-version=7.1-preview.2").value | Select-Object -First 1
    if ($g) { $g = Invoke-Ado PUT "$C/_apis/distributedtask/variablegroups/$($g.id)?api-version=7.1-preview.2" $body; Write-Host "  updated $name" }
    else    { $g = Invoke-Ado POST "$C/_apis/distributedtask/variablegroups?api-version=7.1-preview.2" $body; Write-Host "  created $name" }
    $g
}
function Get-TargetVars([string]$db) { [ordered]@{ target_database_JDBC = (Get-Jdbc $db); databaseName = $db; userName = $S.SqlUser; password = $S.SqlPassword } }
$groups = [ordered]@{}
$groups.vars        = Set-Group $Names.Group.vars 'Shared pipeline settings' ([ordered]@{ BASELINE_VERSION = '1'; AGENT_POOL = $S.AgentPool; SCHEMAS = 'dbo'; LONG_LIVED_BRANCH = $Names.DevBranch })
$groups.shadow      = Set-Group $Names.Group.shadow 'Shadow (build) database for generate. Flyway cleans it.' (Get-TargetVars $Names.Db.shadow)
$groups.integration = Set-Group $Names.Group.integration 'Integration database' (Get-TargetVars $Names.Db.integration)
$groups.test        = Set-Group $Names.Group.test 'Test database' (Get-TargetVars $Names.Db.test)
$groups.prod        = Set-Group $Names.Group.prod 'Prod database' (Get-TargetVars $Names.Db.prod)
$groups.check       = Set-Group $Names.Group.check 'Build database for the release drift/changes reports. Flyway cleans it: never point it at a real environment.' ([ordered]@{
                          build_database_JDBC = (Get-Jdbc $Names.Db.check); build_databaseName = $Names.Db.check; build_userName = $S.SqlUser; build_password = $S.SqlPassword })

# --- environments -----------------------------------------------------------------------------
Write-Step 'Environments'
$envs = [ordered]@{}
$existing = (Invoke-Ado GET "$PU/_apis/pipelines/environments?`$top=200&api-version=7.1-preview.1").value
foreach ($k in $Names.Env.Keys) {
    $e = $existing | Where-Object name -eq $Names.Env[$k]
    if (-not $e) { $e = Invoke-Ado POST "$PU/_apis/pipelines/environments?api-version=7.1-preview.1" @{ name = $Names.Env[$k]; description = "$k database" }; Write-Host "  created $($Names.Env[$k])" }
    else { Write-Host "  exists  $($Names.Env[$k])" }
    $envs[$k] = $e
}

# --- pipelines --------------------------------------------------------------------------------
Write-Step 'Pipelines'
$files = @{ generate = 'azure-pipelines-generate.yml'; integration = 'azure-pipelines-integration.yml'; release = 'azure-pipelines-release.yml' }
$pipes = [ordered]@{}
$all = (Invoke-Ado GET "$PU/_apis/pipelines?`$top=200&api-version=7.1").value
foreach ($k in $Names.Pipeline.Keys) {
    $pl = $all | Where-Object name -eq $Names.Pipeline[$k]
    if (-not $pl) {
        $pl = Invoke-Ado POST "$PU/_apis/pipelines?api-version=7.1" @{ name = $Names.Pipeline[$k]; folder = '\'
            configuration = @{ type = 'yaml'; path = $files[$k]; repository = @{ id = $repo.id; name = $repo.name; type = 'azureReposGit' } } }
        Write-Host "  created $($Names.Pipeline[$k])"
    } else { Write-Host "  exists  $($Names.Pipeline[$k])" }
    # A YAML pipeline created through the REST API has no default queue, and on Azure DevOps Server
    # every run then fails with "No pool was specified".
    $du = "$PU/_apis/build/definitions/$($pl.id)?api-version=7.1"; $d = Invoke-Ado GET $du
    $d | Add-Member -NotePropertyName queue -NotePropertyValue ([pscustomobject]@{ id = $queue.id; name = $queue.name; pool = $queue.pool }) -Force
    $d.repository.defaultBranch = "refs/heads/$(if ($k -eq 'release') { $Names.MainBranch } else { $Names.DevBranch })"
    Invoke-Ado PUT $du $d | Out-Null
    $pipes[$k] = $pl
}

# --- pipeline permissions (pre-authorized, least privilege) ------------------------------------
Write-Step 'Pipeline permissions'
function Permit([string]$type, [string]$id, [int]$pipelineId) {
    Invoke-Ado PATCH "$PU/_apis/pipelines/pipelinepermissions/${type}/${id}?api-version=7.1-preview.1" @{ pipelines = @(@{ id = $pipelineId; authorized = $true }) } | Out-Null
}
$uses = @{
    generate    = @{ groups = @('vars', 'shadow');                 envs = @() }
    integration = @{ groups = @('vars', 'integration');            envs = @('integration') }
    release     = @{ groups = @('vars', 'test', 'prod', 'check');  envs = @('test', 'prod') }
}
foreach ($k in $pipes.Keys) {
    $id = $pipes[$k].id
    Permit 'queue' "$($queue.id)" $id
    Permit 'repository' "$projId.$($tmplRepo.id)" $id
    foreach ($g in $uses[$k].groups) { Permit 'variablegroup' "$($groups[$g].id)" $id }
    foreach ($e in $uses[$k].envs)   { Permit 'environment' "$($envs[$e].id)" $id }
    Write-Host "  $($Names.Pipeline[$k]): $((@($uses[$k].groups | ForEach-Object { $Names.Group[$_] }) + @($uses[$k].envs | ForEach-Object { $Names.Env[$_] })) -join ', ')"
}

# --- branch policies ----------------------------------------------------------------------------
Write-Step 'Branch policies'
$allPolicies = (Invoke-Ado GET "$PU/_apis/policy/configurations?api-version=7.1").value   # matched by scope below: some servers ignore query filters
function Set-Policy([string]$repoId, [string]$branch, [string]$typeId, [string]$label, [hashtable]$settings) {
    $ref = "refs/heads/$branch"
    $settings.scope = @(@{ repositoryId = $repoId; refName = $ref; matchKind = 'exact' })
    $body = @{ isEnabled = $true; isBlocking = $true; type = @{ id = $typeId }; settings = $settings }
    $cur = $allPolicies | Where-Object { $_.type.id -eq $typeId -and ($_.settings.scope | Where-Object { $_.repositoryId -eq $repoId -and $_.refName -eq $ref }) -and
                                         ($typeId -ne 'cbdc66da-9728-4af8-aada-9a5a32e4a226' -or $_.settings.statusName -eq $settings.statusName) } | Select-Object -First 1
    if ($cur) { Invoke-Ado PUT "$PU/_apis/policy/configurations/$($cur.id)?api-version=7.1" $body | Out-Null; Write-Host "  updated $label" }
    else      { Invoke-Ado POST "$PU/_apis/policy/configurations?api-version=7.1" $body | Out-Null;           Write-Host "  created $label" }
}
$reviewers = 'fa4e907d-c16b-4a4c-9dfa-4906e5d171dd'; $status = 'cbdc66da-9728-4af8-aada-9a5a32e4a226'
Set-Policy $repo.id $Names.DevBranch $reviewers "$($Names.Repo)/$($Names.DevBranch): 1 reviewer (own vote counts, reset on push)" @{ minimumApproverCount = 1; creatorVoteCounts = $true; allowDownvotes = $false; resetOnSourcePush = $true }
Set-Policy $repo.id $Names.MainBranch $reviewers "$($Names.Repo)/$($Names.MainBranch): 1 reviewer (creator vote doesn't count, reset on push)" @{ minimumApproverCount = 1; creatorVoteCounts = $false; allowDownvotes = $false; resetOnSourcePush = $true }
Set-Policy $repo.id $Names.MainBranch $status "$($Names.Repo)/$($Names.MainBranch): required status flyway/validated" @{ statusGenre = 'flyway'; statusName = 'validated'; invalidateOnSourceUpdate = $true; defaultDisplayName = 'Flyway: checked and deployed to integration'; policyApplicability = $null }
Set-Policy $tmplRepo.id $Names.MainBranch $reviewers "$($Names.TemplatesRepo)/$($Names.MainBranch): 1 reviewer (own vote counts)" @{ minimumApproverCount = 1; creatorVoteCounts = $true; allowDownvotes = $false; resetOnSourcePush = $true }

# --- permissions --------------------------------------------------------------------------------
Write-Step 'Permissions'
$gitNs = '2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87'
$idBase = Get-IdentityBase
$collectionName = ($C -split '/')[-1]
$bsName = "$($Names.Project) Build Service ($collectionName)"
$bs = (Invoke-Ado GET "$idBase/_apis/identities?searchFilter=General&filterValue=$([uri]::EscapeDataString($bsName))&api-version=7.1").value | Select-Object -First 1
if (-not $bs) { throw "Build service identity '$bsName' not found." }
function Set-Ace([string]$token, [string]$descriptor, [int]$allow, [int]$deny) {
    Invoke-Ado POST "$C/_apis/accesscontrolentries/${gitNs}?api-version=7.1" @{ token = $token; merge = $false; accessControlEntries = @(@{ descriptor = $descriptor; allow = $allow; deny = $deny }) } | Out-Null
}
function Get-BranchToken([string]$repoId, [string]$path) { "repoV2/$projId/$repoId/refs/heads/" + ((($path -split '/') | ForEach-Object { Get-Hex16 $_ }) -join '/') + '/' }
# GenericContribute(4) + PullRequestContribute(16384) on the repo; CreateBranch(16) + ForcePush(8, to
# delete review branches) under migrations/; PolicyExempt(128) and PullRequestBypassPolicy(32768)
# denied on main, so nothing but an approved, validated PR reaches it.
Set-Ace "repoV2/$projId/$($repo.id)" $bs.descriptor 16388 0
Set-Ace (Get-BranchToken $repo.id 'migrations') $bs.descriptor 24 0
Set-Ace (Get-BranchToken $repo.id $Names.MainBranch) $bs.descriptor 0 32896
Write-Host "  ${bsName}: contribute + PR contribute; create/delete under migrations/; no bypass on $($Names.MainBranch)"
if (-not $NoDevBypass) {
    $me = (Invoke-Ado GET "$C/_apis/connectionData").authenticatedUser
    $meDesc = (Invoke-Ado GET "$idBase/_apis/identities?identityIds=$($me.id)&api-version=7.1").value[0].descriptor
    Set-Ace (Get-BranchToken $repo.id $Names.DevBranch) $meDesc 128 0
    Write-Host "  $($me.providerDisplayName): bypass policies when pushing to $($Names.DevBranch)"
}

# --- branch control checks on test and prod -----------------------------------------------------
Write-Step 'Branch control checks'
function Set-BranchCheck([string]$resType, [string]$resId, [string]$label) {
    $have = (Invoke-Ado GET "$PU/_apis/pipelines/checks/configurations?resourceType=$resType&resourceId=$resId&`$expand=settings&api-version=7.1-preview.1").value |
        Where-Object { $_.settings.definitionRef.name -eq 'evaluatebranchProtection' }
    $body = @{
        type     = @{ id = 'fe1de3ee-a436-41b4-bb20-f6eb4cb879a7'; name = 'Task Check' }
        settings = @{
            definitionRef = @{ id = '86b05a0c-73e6-4f7d-b3cf-e38f3b39a75b'; name = 'evaluatebranchProtection'; version = '0.0.1' }
            displayName   = "Branch control: $($Names.MainBranch) only, protected"
            # Verified for every repo a run uses: the project repo's main and the templates repo's main.
            inputs        = @{ allowedBranches = "refs/heads/$($Names.MainBranch)"; ensureProtectionOfBranch = 'true'; allowUnknownStatusBranch = 'false' }
            retryInterval = 5
        }
        timeout  = 1440
        resource = @{ type = $resType; id = $resId }
    }
    if ($have) { Invoke-Ado PATCH "$PU/_apis/pipelines/checks/configurations/$($have[0].id)?api-version=7.1-preview.1" $body | Out-Null; Write-Host "  updated $label" }
    else       { Invoke-Ado POST  "$PU/_apis/pipelines/checks/configurations?api-version=7.1-preview.1" $body | Out-Null;                Write-Host "  added   $label" }
}
foreach ($k in 'test', 'prod') {
    Set-BranchCheck 'environment' "$($envs[$k].id)" "environment $($Names.Env[$k])"
    Set-BranchCheck 'variablegroup' "$($groups[$k].id)" "variable group $($Names.Group[$k])"
}

Write-Step 'Done'
Write-Host "  Pipelines:  $PU/_build"
Write-Host "  Repo:       $PU/_git/$($Names.Repo)"
Write-Host '  Next: .\3-setup-agent.ps1 (if no agent is online in the pool), then make a schema change on dev.' -ForegroundColor Green
exit 0
