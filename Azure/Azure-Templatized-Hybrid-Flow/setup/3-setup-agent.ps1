<#
Step 3: a self-hosted pipelines agent on this machine. Downloads it if needed, registers it in the
pool from settings.ps1, and starts it in its own window. Run as the Windows user the agent should
run as (not elevated): with Windows auth to SQL Server, that user needs access to the databases.

  .\3-setup-agent.ps1            set up if needed, then start the agent in a new window
  .\3-setup-agent.ps1 -Foreground   start it in this window instead

The agent reads the Flyway licence (token= / email=) from the file in settings.ps1 every time it
starts, so `flyway auth` is never needed on the agent. Leave the agent window open.
Skip this script if the pool already has an online agent that can reach the databases.
#>
param([switch]$Foreground)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
$dir = $S.AgentDir

if (Get-Process Agent.Listener -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$dir*" }) {
    Write-Host "An agent is already running from $dir. Nothing to do." -ForegroundColor Green
    exit 0
}

if (-not $Foreground) {
    # --- download --------------------------------------------------------------------------------
    if (-not (Test-Path "$dir\config.cmd")) {
        New-Item -ItemType Directory -Force $dir | Out-Null
        # The agent this server hands out (Agent pools > New agent), so the versions match. Older
        # servers still point at the retired vstsagentpackage.azureedge.net host: same paths, new host.
        $pkg = $null
        try { $pkg = (Invoke-Ado GET "$C/_apis/distributedtask/packages/agent?platform=win-x64&`$top=1&api-version=7.1").value | Select-Object -First 1 } catch { }
        if ($pkg) {
            $version = "$($pkg.version.major).$($pkg.version.minor).$($pkg.version.patch)"
            $url = $pkg.downloadUrl -replace '^https://vstsagentpackage\.azureedge\.net/', 'https://download.agent.dev.azure.com/'
        } else {
            $version = $S.AgentVersion
            $url = "https://download.agent.dev.azure.com/agent/$version/vsts-agent-win-x64-$version.zip"
        }
        $zip = Join-Path $dir "vsts-agent-win-x64-$version.zip"
        if (-not (Test-Path $zip)) {
            Write-Step "Downloading agent $version"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -UseBasicParsing $url -OutFile $zip
        }
        Write-Step "Extracting to $dir"
        Expand-Archive -Path $zip -DestinationPath $dir -Force
    }
    # --- register --------------------------------------------------------------------------------
    if (-not (Test-Path "$dir\.agent")) {
        Write-Step "Registering in pool $($S.AgentPool)"
        $auth = if ($S.Pat) { @('--auth', 'pat', '--token', $S.Pat) } else { @('--auth', 'integrated') }
        Push-Location $dir
        try {
            & .\config.cmd --unattended --url $C @auth --pool $S.AgentPool --agent "$env:COMPUTERNAME-flyway" --replace --acceptTeeEula --work _work
            if ($LASTEXITCODE -ne 0) { throw "config.cmd failed ($LASTEXITCODE)." }
        } finally { Pop-Location }
    } else { Write-Host "Agent in $dir is already registered." }

    Write-Step 'Starting the agent in a new window (leave it open)'
    Start-Process powershell.exe -WorkingDirectory $dir -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Foreground'
    exit 0
}

# --- foreground: licence, then run --------------------------------------------------------------
Import-FlywayLicence -Required | Out-Null
$edition = Get-FlywayEdition
if (-not $edition) { throw 'flyway is not on PATH for this user.' }
Write-Host "Agent will use: $edition"
if ($edition -notmatch 'Enterprise') { throw "Flyway didn't license as Enterprise from $($S.FlywayLicenceFile). Check the token." }
Push-Location $dir
try { & .\run.cmd } finally { Pop-Location }
