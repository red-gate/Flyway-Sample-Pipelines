# Set parameters
$databaseType = "SqlServer" # alt values: SqlServer Oracle PostgreSql MySql 
# connection string to prodlike database
$Url = "jdbc:sqlserver://localhost;databaseName=NewWorldDB_Dev;encrypt=false;integratedSecurity=true;trustServerCertificate=true"
$User = ""
$Password = ""
$databaseName = ($Url -split "databaseName=")[1] -split ";|$" | Select-Object -First 1
$projectName = "$databaseName"
$projectPath = "."
# Backup as Baseline path - must be accessible by DB server - leave empty if not needed 
$backupPath = "C:\\Program Files\\Microsoft SQL Server\\MSSQL13.MSSQLSERVER\\MSSQL\\Backup\\Northwind.bak" # eg C:\\Program Files\\Microsoft SQL Server\\MSSQL13.MSSQLSERVER\\MSSQL\\Backup\\Northwind.bak

# Set the schemas value
$Schemas = @("") # can be empty for SqlServer

# Start Flyway Enterprise Trial and test connection
flyway auth -IAgreeToTheEula -startEnterpriseTrial
flyway testConnection "-url=$Url" "-user=$User" "-password=$Password" "-schemas=$Schemas" 
if ($LASTEXITCODE -ne 0) {
    exit 1
}

# Initialize project - create folders and flyway.toml - delete existing project folder if exists
if (Test-Path -Path "$projectPath\$projectName") {
    Remove-Item -Path $projectName -Recurse -Force
}
cd $projectPath
mkdir $projectName
cd ./$projectName
flyway init "-init.projectName=$projectName" "-init.databaseType=$databaseType"

if ($backupPath -ne "") {
    # Add shadow environment to flyway.toml
    $ShadowDatabaseName = $databaseName + '_${env.UserName}_shadow'
    $Url = $Url -replace "databaseName=[^;]*", "databaseName=$ShadowDatabaseName"
    (Add-Content -Path "flyway.toml" `
    -Value "`n`n[environments.shadow]`nurl = `"$Url`"`nprovisioner = `"backup`"`n`n[environments.shadow.resolvers.backup]`nbackupFilePath = `"$backupPath`"`nbackupVersion = `"000`"`n`n  [environments.shadow.resolvers.backup.sqlserver]`n  generateWithMove = true"
    )
}

<# # Modify flyway.toml to adjust comparison options
(Get-Content -Path "flyway.toml") `
-replace 'ignorePermissions\s*=\s*false', 'ignorePermissions = true' `
-replace 'ignoreUsersPermissionsAndRoleMemberships\s*=\s*false', 'ignoreUsersPermissionsAndRoleMemberships = true' `
-replace 'includeDependencies\s*=\s*true', 'includeDependencies = false' |
Set-Content -Path "flyway.toml"

# Define the file path
$filePath = "Filter.scpf"

# Check if the file exists
if (Test-Path -Path $filePath) {
    # Load the XML file
    $xml = [xml](Get-Content -Path $filePath)

    # Find the <None> element and update its child nodes
    $noneElement = $xml.NamedFilter.Filter.Filters.None
    $noneElement.Include = "False"
    $noneElement.Expression = "((@SCHEMA LIKE 'cdc%'))"

    
    $currentPath = Get-Location
    $filePath = Join-Path -Path $currentPath -ChildPath $filePath
    # Save the updated XML back to the file
    $xml.Save($filePath)
    Write-Host "Filter.scpf updated successfully."
} else {
    Write-Host "Filter.scpf does not exist."
}
#>

# Populate SchemaModel from dev database or from backup
if ($backupPath -eq "") {
    flyway diff model "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$Url" "-environments.dev.user=$User" "-environments.dev.password=$Password" "-environments.dev.schemas=$Schemas"
    flyway diff generate "-diff.source=schemaModel" "-diff.target=empty" "-generate.types=baseline" "-generate.description=Baseline" "-generate.version=1.0"
} else {
    Write-Output "Restoring provided backup file to server URL and Populating SchemaModel from it"
    flyway diff model "-diff.source=migrations" "-diff.target=schemaModel" "-diff.buildEnvironment=shadow"
}
cd .. 