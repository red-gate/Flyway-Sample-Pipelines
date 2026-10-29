<#
Step 4 (optional, Azure DevOps Server on this machine): run after a reboot, or whenever pipelines
queue but never start. Not needed with Azure DevOps Services.

  .\4-start-local-ado.ps1

  1. If SQL Server or the server's job agent (TFSJobAgent) is down, or AUTO_CLOSE is on for the
     Azure DevOps databases, fixes that as administrator (one UAC prompt): starts the services,
     turns AUTO_CLOSE off (SQL Express turns it on, and the reopen delay makes the job agent's
     database lease time out and the agent exit), makes Windows always restart the job agent, and
     delays its start at boot until SQL Server is up.
  2. Waits for the server to answer, then starts the pipelines agent (3-setup-agent.ps1) if it isn't
     running, and waits for it to come online.
#>
param([int]$TimeoutSeconds = 180)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

function Wait-Until([scriptblock]$Test, [string]$What) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) { try { if (& $Test) { return $true } } catch { }; Start-Sleep -Seconds 5 }
    Write-Warning "Timed out after $TimeoutSeconds s waiting for $What."; return $false
}

Write-Step 'Server services'
# SQL Server service for SqlCmdServer: MSSQL$<instance> for a named instance, MSSQLSERVER for the
# default one; if that doesn't exist, the only SQL Server service on the machine.
$instance = if ($S.SqlCmdServer -match '\\([^\\,]+)') { $Matches[1] } else { 'MSSQLSERVER' }
$sqlSvc = Get-Service -Name $(if ($instance -eq 'MSSQLSERVER') { 'MSSQLSERVER' } else { "MSSQL`$$instance" }) -ErrorAction SilentlyContinue
if (-not $sqlSvc) { $all = @(Get-Service | Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' }); if ($all.Count -eq 1) { $sqlSvc = $all[0] } }
$job = Get-Service TFSJobAgent -ErrorAction SilentlyContinue
if (-not $job) { throw 'TFSJobAgent not found: Azure DevOps Server is not installed on this machine.' }
$autoClose = '0'
try { $autoClose = "$(Invoke-Sql "SELECT COUNT(*) FROM sys.databases WHERE is_auto_close_on = 1 AND (name LIKE N'AzureDevOps%' OR name LIKE N'$Prefix-%')")".Trim() } catch { $autoClose = '?' }
if (($sqlSvc -and $sqlSvc.Status -ne 'Running') -or $job.Status -ne 'Running' -or $autoClose -ne '0') {
    Write-Host "SQL: $($sqlSvc.Status). Job agent: $($job.Status). Databases with AUTO_CLOSE on: $autoClose. Fixing as administrator (UAC prompt)..."
    $sqlName = if ($sqlSvc) { $sqlSvc.Name } else { '' }
    $q = "DECLARE @s nvarchar(max) = N''; SELECT @s += N'ALTER DATABASE ' + QUOTENAME(name) + N' SET AUTO_CLOSE OFF;' FROM sys.databases WHERE is_auto_close_on = 1 AND (name LIKE N'AzureDevOps%' OR name LIKE N'$Prefix-%'); EXEC (@s);"
    $sqlArgs = if ($S.SqlUser) { "-U '$($S.SqlUser)' -P '$($S.SqlPassword)'" } else { '-E' }
    $cmd = @"
`$ErrorActionPreference = 'Stop'
if ('$sqlName') { Start-Service '$sqlName' }
& sqlcmd -S '$($S.SqlCmdServer)' $sqlArgs -C -b -Q "$q"
sc.exe failure TFSJobAgent reset= 3600 actions= restart/60000/restart/60000/restart/60000 | Out-Null
sc.exe config  TFSJobAgent start= delayed-auto | Out-Null
Start-Service TFSJobAgent
"@
    # Written to a file and run with -File: quotes inside a -Command string don't survive the
    # trip through Start-Process.
    $fix = Join-Path $env:TEMP "$Prefix-elevated-fix.ps1"
    Set-Content -Path $fix -Value $cmd -Encoding UTF8
    $proc = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$fix`""
    Remove-Item $fix -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0) { throw "The elevated fix exited with code $($proc.ExitCode)." }
    Write-Host "Job agent: $((Get-Service TFSJobAgent).Status)"
} else { Write-Host 'SQL Server and the job agent are running; AUTO_CLOSE is off.' }

Write-Step "Waiting for $C"
if (Wait-Until { (Invoke-Ado GET "$C/_apis/connectionData") } 'the server') { Write-Host 'Server is up.' }

Write-Step 'Pipelines agent'
& "$PSScriptRoot\3-setup-agent.ps1"
$pool = (Invoke-Ado GET "$C/_apis/distributedtask/pools?poolName=$([uri]::EscapeDataString($S.AgentPool))&api-version=7.1").value | Select-Object -First 1
if (Wait-Until { (Invoke-Ado GET "$C/_apis/distributedtask/pools/$($pool.id)/agents?api-version=7.1").value | Where-Object status -eq 'online' } 'an agent to come online') {
    Write-Host "Ready: $C/$($Names.Project)/_build" -ForegroundColor Green
}
exit 0
