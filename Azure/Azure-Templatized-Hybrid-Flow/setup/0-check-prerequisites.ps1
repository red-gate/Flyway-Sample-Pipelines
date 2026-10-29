<#
Step 0: checks this machine has what the other scripts need. Changes nothing.

  .\0-check-prerequisites.ps1

Each line is OK, WARN (works, but read the note) or FAIL (fix before going on).
#>
. "$PSScriptRoot\common.ps1"
$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$item, [string]$status, [string]$note) { $results.Add([pscustomobject]@{ Check = $item; Status = $status; Note = $note }) }

# PowerShell
Add-Result 'Windows PowerShell 5.1+' $(if ($PSVersionTable.PSVersion.Major -ge 5) { 'OK' } else { 'FAIL' }) "version $($PSVersionTable.PSVersion)"

# git
$git = Get-Command git -ErrorAction SilentlyContinue
Add-Result 'git on PATH' $(if ($git) { 'OK' } else { 'FAIL' }) $(if ($git) { (& git --version) } else { 'Install Git for Windows.' })

# sqlcmd and SQL Server
$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
if (-not $sqlcmd) { Add-Result 'sqlcmd on PATH' 'FAIL' 'Install the SQL Server command line tools (sqlcmd).' }
else {
    Add-Result 'sqlcmd on PATH' 'OK' $sqlcmd.Source
    try {
        $v = Invoke-Sql "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)) + ' ' + CAST(SERVERPROPERTY('Edition') AS varchar(60)) + ' | create db: ' + CAST(HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE ANY DATABASE') AS varchar(1))"
        $line = "$v".Trim()
        $canCreate = $line -match 'create db: 1$'
        Add-Result "SQL Server $($S.SqlCmdServer)" $(if ($canCreate) { 'OK' } else { 'FAIL' }) $(if ($canCreate) { $line } else { "$line. The login can't create databases." })
    } catch { Add-Result "SQL Server $($S.SqlCmdServer)" 'FAIL' "Can't connect: $($_.Exception.Message)" }
}

# Flyway connects over TCP (JDBC). sqlcmd can connect locally without it, and SQL Express has TCP/IP off by default.
if ($S.JdbcServer -match '^(.+):(\d+)$') {
    $tcp = New-Object Net.Sockets.TcpClient
    try { $tcpOk = $tcp.ConnectAsync($Matches[1], [int]$Matches[2]).Wait(3000) -and $tcp.Connected } catch { $tcpOk = $false } finally { $tcp.Close() }
    Add-Result "SQL Server TCP $($S.JdbcServer)" $(if ($tcpOk) { 'OK' } else { 'FAIL' }) $(if ($tcpOk) { 'listening' } else { 'Nothing listening. In SQL Server Configuration Manager, enable TCP/IP for the instance, set TCP Port to 1433 under IPAll, and restart SQL Server.' })
} else { Add-Result "SQL Server TCP $($S.JdbcServer)" 'WARN' 'No port, so not checked. Without one, JDBC needs the SQL Server Browser service running.' }

# Flyway
$flyway = Get-Command flyway -ErrorAction SilentlyContinue
if (-not $flyway) { Add-Result 'flyway on PATH' 'FAIL' 'Install Flyway Desktop (it puts the CLI on PATH) or the Flyway CLI.' }
else {
    Add-Result 'flyway on PATH' 'OK' $flyway.Source
    $lic = Import-FlywayLicence
    $edition = Get-FlywayEdition
    if (-not $lic) { Add-Result 'Flyway licence file' 'FAIL' "Create $($S.FlywayLicenceFile) with token= and email=." }
    elseif ($edition -match 'Enterprise') { Add-Result 'Flyway Enterprise licence' 'OK' $edition }
    else { Add-Result 'Flyway Enterprise licence' 'FAIL' "$edition. diff, check -drift/-changes and undo scripts need Enterprise: check the token in $($S.FlywayLicenceFile)." }
    if ($flyway.Source -notmatch 'Flyway Desktop') {
        Add-Result 'Flyway code analysis' 'WARN' 'check -code uses SQLFluff. Flyway Desktop bundles it; with the standalone CLI make sure SQLFluff is available.'
    }
}

# Azure DevOps
try {
    $cd = Invoke-Ado GET "$C/_apis/connectionData"
    Add-Result "Azure DevOps $C" 'OK' "signed in as $($cd.authenticatedUser.providerDisplayName)$(if ($S.Pat) { ' (PAT)' } else { ' (Windows auth)' })"
    # Asking for a version no server has makes the server name its latest one, which Invoke-Ado keeps.
    try { Invoke-Ado GET "$C/_apis/projects?`$top=1&api-version=99.0" | Out-Null } catch { }
    $api = $script:AdoApi
    if (-not $api) { Add-Result 'REST API version' 'WARN' "Couldn't tell which version the server supports." }
    elseif ([version]$api -ge [version]'7.1') { Add-Result 'REST API version' 'OK' $api }
    elseif ([version]$api -ge [version]'7.0') { Add-Result 'REST API version' 'WARN' "$api (Azure DevOps Server 2022). The scripts fall back to it, but were only tested on Azure DevOps Server 25H2." }
    else { Add-Result 'REST API version' 'FAIL' "$api. The scripts need Azure DevOps Server 2022 or later." }
    try {
        $pool = (Invoke-Ado GET "$C/_apis/distributedtask/pools?poolName=$([uri]::EscapeDataString($S.AgentPool))&api-version=7.1").value | Select-Object -First 1
        if ($pool) {
            $agents = @((Invoke-Ado GET "$C/_apis/distributedtask/pools/$($pool.id)/agents?api-version=7.1").value)
            $online = @($agents | Where-Object status -eq 'online').Count
            $others = @($agents | Where-Object name -ne "$env:COMPUTERNAME-flyway")
            if ($others.Count) { Add-Result "Agent pool '$($S.AgentPool)'" 'WARN' "Has $($others.Count) other agent(s): $($others.name -join ', '). Runs can land on them, and they'd need Flyway Enterprise and its licence. To keep runs on this machine, set AgentPool in settings.ps1 to a new name; 2-setup-azure-devops.ps1 creates that pool." }
            else { Add-Result "Agent pool '$($S.AgentPool)'" $(if ($online) { 'OK' } else { 'WARN' }) "$($agents.Count) agent(s), $online online$(if (-not $online) { '. Run 3-setup-agent.ps1 before running the pipelines.' })" }
        } else { Add-Result "Agent pool '$($S.AgentPool)'" 'OK' 'Not found; 2-setup-azure-devops.ps1 creates it.' }
    } catch { Add-Result "Agent pool '$($S.AgentPool)'" 'WARN' "Couldn't list pools: $($_.Exception.Message)" }
    try {
        Invoke-Ado GET "$C/_apis/projects/$([uri]::EscapeDataString($Names.Project))?api-version=7.1" | Out-Null
        Add-Result "Project '$($Names.Project)'" 'WARN' 'Already exists. 2-setup-azure-devops.ps1 reuses it and only adds what is missing.'
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            # Collection namespace, token NAMESPACE, bit 4 = "Create new projects".
            $canCreateProjects = try { (Invoke-Ado GET "$C/_apis/permissions/3e65f728-f8bc-4ecd-8764-7e378b19bfa7/4?tokens=NAMESPACE&api-version=7.1").value[0] } catch { $null }
            if ($canCreateProjects -eq $false) { Add-Result "Project '$($Names.Project)'" 'FAIL' "Does not exist, and you can't create projects. Ask a Project Collection Administrator to add you to that group, or to create the project." }
            else { Add-Result "Project '$($Names.Project)'" 'OK' 'Does not exist yet; 2-setup-azure-devops.ps1 creates it.' }
        } else { Add-Result "Project '$($Names.Project)'" 'WARN' "Couldn't check: $($_.Exception.Message)" }
    }
} catch { Add-Result "Azure DevOps $C" 'FAIL' "Can't connect: $($_.Exception.Message)$(if ($IsServices -and -not $S.Pat) { '. dev.azure.com needs a PAT in settings.ps1.' })" }

# Agent folder
if (Test-Path (Join-Path $S.AgentDir '.agent')) { Add-Result "Agent folder $($S.AgentDir)" 'OK' 'Configured. 3-setup-agent.ps1 starts it.' }
else { Add-Result "Agent folder $($S.AgentDir)" 'OK' 'Not configured yet. 3-setup-agent.ps1 downloads and registers it.' }

$results | Format-Table -AutoSize -Wrap
if ($results | Where-Object Status -eq 'FAIL') { Write-Host 'Fix the FAIL lines, then run this again.' -ForegroundColor Red; exit 1 }
Write-Host 'Ready. Next: .\1-create-databases.ps1' -ForegroundColor Green
exit 0
