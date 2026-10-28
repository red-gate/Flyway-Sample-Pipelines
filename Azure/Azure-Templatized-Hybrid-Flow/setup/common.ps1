# Shared by the numbered setup scripts: names derived from settings.ps1, and helpers for SQL Server,
# Flyway, the Azure DevOps REST API and git. Dot-source it; don't run it.

. "$PSScriptRoot\settings.ps1"
$S = $Settings
$Prefix = $S.Prefix
$Kit = Split-Path -Parent $PSScriptRoot          # the Azure-Templatized-Hybrid-Flow folder
$SeedProject = Join-Path $PSScriptRoot 'northwind'

# Reads the "- name: / value:" pairs of pipeline-settings.yml, with projectName set to $projectName
# and ${{ variables.x }} references resolved, so the scripts use exactly the names the pipelines do.
function Read-PipelineSettings([string]$path, [string]$projectName) {
    $vals = [ordered]@{}; $key = $null
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match '^\s*-\s*name:\s*(\S+)') { $key = $Matches[1] }
        elseif ($key -and $line -match '^\s*value:\s*(.*?)\s*(#.*)?$') { $vals[$key] = $Matches[1] -replace "^'(.*)'$|^`"(.*)`"$", '$1$2'; $key = $null }
    }
    $vals.projectName = $projectName
    foreach ($k in @($vals.Keys)) { $vals[$k] = [regex]::Replace($vals[$k], '\$\{\{\s*variables\.(\w+)\s*\}\}', { param($m) $vals[$m.Groups[1].Value] }) }
    $vals
}
$PipelineSettings = Read-PipelineSettings "$Kit\pipeline-settings.yml" $Prefix
# Sets one "- name: / value:" pair in the text of pipeline-settings.yml.
function Set-PipelineSetting([string]$text, [string]$name, [string]$value) {
    $text -replace "(?m)^(\s*-\s*name:\s*$name\s*\r?\n\s*value:\s*)[^\r\n]*", "`${1}'$($value.Replace('$', '$$'))'"
}

$Names = @{
    Project       = $Prefix
    Repo          = $Prefix                         # Azure DevOps creates this repo with the project
    TemplatesRepo = 'flyway-templates-hybrid'
    DevBranch     = $PipelineSettings.devBranch
    MainBranch    = $PipelineSettings.mainBranch
    Db = [ordered]@{
        dev         = "$Prefix-dev"                 # developers' database (Flyway Desktop)
        shadow      = "$Prefix-shadow"              # build database for generate; Flyway restores/cleans it
        check       = "$Prefix-check"               # build database for drift/changes; Flyway restores/cleans it
        integration = "$Prefix-integration"
        test        = "$Prefix-test"
        prod        = "$Prefix-prod"
        baseline    = "$Prefix-baseline"            # schema at baselineBackupVersion: the source of the baseline backup
    }
    Group = [ordered]@{                             # from pipeline-settings.yml
        vars        = $PipelineSettings.pipelineVarsGroup
        shadow      = $PipelineSettings.shadowCredentialsGroup
        integration = $PipelineSettings.integrationCredentialsGroup
        test        = $PipelineSettings.testCredentialsGroup
        prod        = $PipelineSettings.prodCredentialsGroup
        check       = $PipelineSettings.releaseBuildCredentialsGroup
    }
    Env = [ordered]@{                               # from pipeline-settings.yml
        integration = $PipelineSettings.integrationEnvironment
        test        = $PipelineSettings.testEnvironment
        prod        = $PipelineSettings.prodEnvironment
    }
    Pipeline = [ordered]@{
        generate    = "$Prefix - 1 Generate"
        integration = "$Prefix - 2 Integration"
        release     = "$Prefix - 3 Release"
    }
}

function Write-Step([string]$text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }

# --- SQL Server --------------------------------------------------------------------------------
function Get-Jdbc([string]$db) {
    $auth = if ($S.SqlUser) { '' } else { 'integratedSecurity=true;' }
    "jdbc:sqlserver://$($S.JdbcServer);databaseName=$db;${auth}trustServerCertificate=true"
}
function Invoke-Sql([string]$query, [string]$database = 'master') {
    $ErrorActionPreference = 'Continue'   # native stderr is not an error; the exit code decides
    $a = @('-S', $S.SqlCmdServer, '-d', $database, '-C', '-b', '-W', '-h', '-1', '-Q', "SET NOCOUNT ON; $query")
    if ($S.SqlUser) { $a += @('-U', $S.SqlUser, '-P', $S.SqlPassword) } else { $a += '-E' }
    $out = & sqlcmd @a 2>&1
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed: $out" }
    $out
}

# --- Flyway ------------------------------------------------------------------------------------
# Reads token= / email= into FLYWAY_TOKEN / FLYWAY_EMAIL for this process (and its children).
function Import-FlywayLicence([switch]$Required) {
    $file = $S.FlywayLicenceFile
    if (Test-Path $file) {
        $kv = @{}
        Get-Content $file | ForEach-Object { if ($_ -match '^\s*([A-Za-z_]+)\s*=\s*(.*?)\s*$') { $kv[$Matches[1].ToLower()] = $Matches[2] } }
        if ($kv['token'] -and $kv['email']) { $env:FLYWAY_TOKEN = $kv['token']; $env:FLYWAY_EMAIL = $kv['email']; return $true }
    }
    if ($env:FLYWAY_TOKEN -and $env:FLYWAY_EMAIL) { return $true }
    if ($Required) { throw "No Flyway licence: create $file with token= and email= lines." }
    return $false
}
function Get-FlywayEdition {
    $ErrorActionPreference = 'Continue'
    $line = & flyway -v 2>&1 | Select-String 'Flyway .*Edition' | Select-Object -First 1
    if ($line) { "$line".Trim() } else { $null }
}
# Runs flyway against one database, from the seed project folder.
function Invoke-Flyway([string]$db, [string[]]$arguments) {
    $ErrorActionPreference = 'Continue'
    $a = @('-configFiles=flyway.toml', '-environment=target', "-environments.target.url=$(Get-Jdbc $db)")
    if ($S.SqlUser) { $a += @("-environments.target.user=$($S.SqlUser)", "-environments.target.password=$($S.SqlPassword)") }
    Push-Location $SeedProject
    try { $out = & flyway @($a + $arguments) 2>&1; $code = $LASTEXITCODE } finally { Pop-Location }
    if ($code -ne 0) { throw "flyway $($arguments -join ' ') on $db failed:`n$($out -join "`n")" }
    $out
}

# --- Baseline backup ---------------------------------------------------------------------------
# Where the baseline backup lives, as SQL Server sees it: BaselineBackupPath, or the server's
# default backup folder.
function Get-BaselineBackupPath {
    if ($S.BaselineBackupPath) { return $S.BaselineBackupPath }
    $dir = "$(Invoke-Sql "SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(260))")".Trim()
    "$($dir.TrimEnd('\'))\$Prefix-baseline.bak"
}
# Version of the first versioned migration, the schema the baseline backup holds. Flyway turns the
# underscores in a version into dots: V001_20261013185549__Initial.sql is version 001.20261013185549.
function Get-BaselineVersion {
    $first = Get-ChildItem "$SeedProject\migrations" -Filter 'V*.sql' | Sort-Object Name | Select-Object -First 1
    (($first.BaseName -replace '^V', '') -split '__')[0] -replace '_', '.'
}
# The schema-only backup the shadow and check databases are restored from: the <prefix>-baseline
# database migrated to the first migration (V001 holds no data), backed up to the path above.
# An existing backup is left alone unless -Force.
function New-BaselineBackup([switch]$Force) {
    $path = Get-BaselineBackupPath
    $version = Get-BaselineVersion
    $exists = "$(Invoke-Sql "DECLARE @e int; EXEC master.dbo.xp_fileexist N'$path', @e OUTPUT; SELECT @e")".Trim() -eq '1'
    if ($exists -and -not $Force) { Write-Host "  exists   $path"; return $path }
    $db = $Names.Db.baseline
    Invoke-Sql "IF DB_ID(N'$db') IS NULL CREATE DATABASE [$db]; ALTER DATABASE [$db] SET AUTO_CLOSE OFF" | Out-Null
    Invoke-Flyway $db @('migrate', "-target=$version") | Out-Null
    Invoke-Sql "BACKUP DATABASE [$db] TO DISK = N'$path' WITH INIT, FORMAT, COPY_ONLY" | Out-Null
    Write-Host "  created  $path ($db at version $version)"
    $path
}

# --- Azure DevOps REST -------------------------------------------------------------------------
$C = $S.CollectionUrl.TrimEnd('/')
$IsServices = $C -match '^https://(dev\.azure\.com|[^/]+\.visualstudio\.com)'
if ($S.Pat) { $script:AdoHeaders = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($S.Pat)")) } }
# The scripts ask for REST API 7.1. An older server (Azure DevOps Server 2022 supports 7.0) rejects
# that and names the latest version it supports: from then on, use that one instead. If that version
# only has the call in preview, add -preview. Tested on Azure DevOps Server 25H2 (REST API 7.2), and
# with every call forced to 7.0 there.
$script:AdoApi = $null
function Invoke-Ado([string]$Method, [string]$Url, $Body) {
    $req = @{ Method = $Method; ContentType = 'application/json; charset=utf-8'; ErrorAction = 'Stop' }
    if ($S.Pat) { $req.Headers = $script:AdoHeaders } else { $req.UseDefaultCredentials = $true }
    # -InputObject, not the pipeline: piping a one-item array unrolls it into an object. UTF-8 bytes,
    # because Windows PowerShell 5.1 would otherwise send non-ASCII text in the wrong encoding.
    if ($null -ne $Body) { $req.Body = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 30)) }
    for ($attempt = 1; ; $attempt++) {
        $api = $script:AdoApi
        if ($api) { $Url = [regex]::Replace($Url, 'api-version=(\d+\.\d+)', { param($m) if ([version]$m.Groups[1].Value -gt [version]$api) { "api-version=$api" } else { $m.Value } }) }
        try { return Invoke-RestMethod @req -Uri $Url }
        catch {
            $msg = "$($_.ErrorDetails.Message)"
            if ($attempt -lt 3 -and $msg -match 'latest REST API version this server supports is (\d+\.\d+)') { $script:AdoApi = $Matches[1]; continue }
            if ($attempt -lt 3 -and $msg -match '-preview flag must be supplied' -and $Url -notmatch 'api-version=[\d.]+-preview') { $Url = $Url -replace '(api-version=\d+\.\d+)', '$1-preview'; continue }
            throw
        }
    }
}
# Identities live on a different host in Azure DevOps Services.
function Get-IdentityBase {
    if ($C -match '^https://dev\.azure\.com/([^/]+)') { return "https://vssps.dev.azure.com/$($Matches[1])" }
    if ($C -match '^https://([^.]+)\.visualstudio\.com') { return "https://$($Matches[1]).vssps.visualstudio.com" }
    return $C
}
function Get-Hex16([string]$s) { -join ([Text.Encoding]::Unicode.GetBytes($s) | ForEach-Object { $_.ToString('x2') }) }

# --- git -------------------------------------------------------------------------------------
# Commits the contents of $dir as one commit and pushes it to each branch in $branches.
function Push-Folder([string]$dir, [string]$remoteUrl, [string[]]$branches, [string]$message) {
    $ErrorActionPreference = 'Continue'   # git writes progress to stderr
    Push-Location $dir
    try {
        & git init -q -b $branches[0]
        & git -c user.name="$env:USERNAME" -c user.email="$env:USERNAME@localhost" -c core.autocrlf=false add -A
        & git -c user.name="$env:USERNAME" -c user.email="$env:USERNAME@localhost" commit -q -m $message
        if ($LASTEXITCODE -ne 0) { throw "git commit failed in $dir" }
        foreach ($b in $branches) {
            if ($S.Pat) {
                & git -c "http.extraheader=AUTHORIZATION: $($script:AdoHeaders.Authorization)" push -q $remoteUrl "HEAD:refs/heads/$b"
            } else {
                # Windows single sign-on: the server offers NTLM, so skip the credential manager and
                # let git send the current Windows identity (empty user name in the URL).
                $u = [uri]$remoteUrl
                & git -c credential.helper= -c "http.$($u.Scheme)://$($u.Host).allowNTLMAuth=true" push -q ($remoteUrl -replace '^(https?)://', '$1://:@') "HEAD:refs/heads/$b"
            }
            if ($LASTEXITCODE -ne 0) { throw "git push of $b to $remoteUrl failed" }
        }
    } finally { Pop-Location }
}
