<#
Step 1: creates the six databases and brings the right ones up to date. Safe to re-run: it never
drops or cleans anything, and only applies pending migrations.

  .\1-create-databases.ps1                 dev, integration, test, prod migrated to the latest version
  .\1-create-databases.ps1 -EmptyTargets   only dev is migrated; integration, test and prod stay
                                            empty, so the first pipeline runs deploy everything

  <prefix>-dev          migrated   the developers' database, used by Flyway Desktop
  <prefix>-shadow       EMPTY      build database for `flyway diff generate`; Flyway cleans it
  <prefix>-check        EMPTY      build database for the release drift/changes reports; Flyway cleans it
  <prefix>-integration  migrated   deployment targets: integration (dev branch), test and prod (main)
  <prefix>-test         migrated
  <prefix>-prod         migrated

The schema comes from the migrations in setup\northwind-hybrid\migrations.
#>
param([switch]$EmptyTargets)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

Write-Step "Databases on $($S.SqlCmdServer)"
foreach ($db in $Names.Db.Values) {
    $exists = "$(Invoke-Sql "SELECT COUNT(*) FROM sys.databases WHERE name = N'$db'")".Trim() -eq '1'
    if (-not $exists) { Invoke-Sql "CREATE DATABASE [$db]" | Out-Null; Write-Host "  created  $db" }
    else { Write-Host "  exists   $db" }
    # SQL Server Express turns AUTO_CLOSE on by default. Idle databases then close, and reopening
    # them makes connections slow or time out. Off for every database the pipeline uses.
    Invoke-Sql "IF DATABASEPROPERTYEX(N'$db', 'IsAutoClose') = 1 ALTER DATABASE [$db] SET AUTO_CLOSE OFF" | Out-Null
}

Write-Step 'Build databases must stay empty'
foreach ($k in 'shadow', 'check') {
    $db = $Names.Db[$k]
    $objects = [int]"$(Invoke-Sql "SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0" $db)".Trim()
    if ($objects -eq 0) { Write-Host "  empty    $db" }
    else { Write-Warning "$db has $objects objects. Flyway cleans it on every run, so don't keep anything in it." }
}

Write-Step 'Migrating'
if (-not (Import-FlywayLicence)) { Write-Host '  (no Flyway licence file found; migrate works without one)' }
$toMigrate = @('dev')
if (-not $EmptyTargets) { $toMigrate += @('integration', 'test', 'prod') }
foreach ($k in $toMigrate) {
    $db = $Names.Db[$k]
    $out = Invoke-Flyway $db @('migrate')
    $line = ($out | Select-String 'Successfully applied|is up to date|No migration necessary' | Select-Object -First 1)
    Write-Host "  $db : $("$line".Trim())"
}

Write-Step 'Result'
$rows = foreach ($k in $Names.Db.Keys) {
    $db = $Names.Db[$k]
    $objects = [int]"$(Invoke-Sql "SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0" $db)".Trim()
    $version = "$(Invoke-Sql "IF OBJECT_ID(N'dbo.flyway_schema_history') IS NOT NULL SELECT TOP 1 version FROM dbo.flyway_schema_history WHERE version IS NOT NULL AND success = 1 ORDER BY installed_rank DESC" $db)".Trim()
    [pscustomobject]@{ Database = $db; Role = $k; Objects = $objects; Version = $(if ($version) { $version } else { '-' }) }
}
$rows | Format-Table -AutoSize
Write-Host 'Next: .\2-setup-azure-devops.ps1' -ForegroundColor Green
exit 0
