<#
Optional, before step 0: installs Azure DevOps Server Express on this machine. Skip it if you already
have Azure DevOps Server, or use Azure DevOps Services (dev.azure.com).

Run from an ELEVATED PowerShell:
  .\install-azure-devops-server.ps1
  .\install-azure-devops-server.ps1 -SqlSetupPath D:\SQL2025\Express_ENU\SETUP.EXE   (to add Full-Text)

  1. Checks the SQL Server instance has Full-Text Search, which the server's readiness check
     requires. If it's missing and -SqlSetupPath points at the SQL Server setup.exe for this
     instance, adds it. Otherwise tells you to add it with SQL Server setup.
  2. Downloads the Azure DevOps Server Express installer and runs it. When it finishes, the
     Configuration Center opens. Choose:
       - New Deployment - Basic
       - SQL Server: the existing instance (Express is fine; the Azure DevOps databases are created there)
       - Application tier: a free port (80, or 8085 if something else uses 80)
       - Search: untick "Install and configure Search" (not needed, saves memory)
       - SSH: off, or a port other than 22 if something else (e.g. GitLab) uses it
     The collection URL is then http://localhost[:port]/DefaultCollection: put it in settings.ps1.
  3. Afterwards, run .\4-start-local-ado.ps1 once: it turns AUTO_CLOSE off for the Azure DevOps
     databases and makes Windows always restart the server's job agent.
#>
param([string]$SqlSetupPath = '')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    throw 'Run this from an elevated PowerShell (Run as administrator).'
}

Write-Step "Full-Text Search on $($S.SqlCmdServer)"
$ft = "$(Invoke-Sql "SELECT FULLTEXTSERVICEPROPERTY('IsFullTextInstalled')")".Trim()
if ($ft -eq '1') { Write-Host '  installed' }
elseif ($SqlSetupPath) {
    $instance = if ($S.SqlCmdServer -match '\\([^\\,]+)') { $Matches[1] } else { 'MSSQLSERVER' }
    Write-Host "  adding it to instance $instance (quiet install, a few minutes)..."
    & $SqlSetupPath /Q /ACTION=Install /FEATURES=FullText /INSTANCENAME=$instance /IACCEPTSQLSERVERLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE
    if ($LASTEXITCODE -ne 0) { throw "SQL Server setup exited with $LASTEXITCODE. See its Summary.txt log." }
    Write-Host '  added'
} else {
    throw 'Full-Text Search is not installed. Add it with SQL Server setup (Add features), or pass -SqlSetupPath <setup.exe>.'
}

Write-Step 'Azure DevOps Server Express installer'
$exe = Join-Path $env:TEMP 'AzureDevOpsServerExpress.exe'
if (-not (Test-Path $exe)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing 'https://go.microsoft.com/fwlink/?LinkId=2330454' -OutFile $exe
}
Write-Host '  Follow the choices at the top of this script in the Configuration Center.'
Start-Process -FilePath $exe -Wait
Write-Host 'When the Configuration Center reports success: set CollectionUrl in settings.ps1, run .\4-start-local-ado.ps1 once, then .\0-check-prerequisites.ps1.' -ForegroundColor Green
exit 0
