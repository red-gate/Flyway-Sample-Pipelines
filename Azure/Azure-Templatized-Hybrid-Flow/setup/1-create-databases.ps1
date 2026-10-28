<#
Step 1: creates the databases, brings the right ones up to date, and makes the baseline backup.
Safe to re-run: it never drops or cleans anything, only applies pending migrations, and leaves an
existing backup alone.

  .\1-create-databases.ps1                  dev, integration, test, prod migrated to the latest version
  .\1-create-databases.ps1 -EmptyTargets    only dev is migrated; integration, test and prod stay
                                             empty, so the first pipeline runs deploy everything
  .\1-create-databases.ps1 -RefreshBaseline  also remake the baseline backup

  <prefix>-dev          migrated   the developers' database, used by Flyway Desktop
  <prefix>-shadow       empty      build database for `flyway diff generate`
  <prefix>-check        empty      build database for the release drift/changes reports
  <prefix>-integration  migrated   deployment targets: integration (dev branch), test and prod (main)
  <prefix>-test         migrated
  <prefix>-prod         migrated
  <prefix>-baseline     V001       the schema-only baseline, backed up to BaselineBackupPath

On every run Flyway restores the baseline backup into shadow and check and applies the later
migrations (the backup provisioner), so don't keep anything in them. The schema comes from the
migrations in setup\northwind\migrations.
#>
param([switch]$EmptyTargets, [switch]$RefreshBaseline)
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

Write-Step 'Baseline backup (shadow and check are restored from it)'
New-BaselineBackup -Force:$RefreshBaseline | Out-Null

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
