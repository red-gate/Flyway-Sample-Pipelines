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
    $shadowUrl = $Url -replace "databaseName=[^;]*", "databaseName=$ShadowDatabaseName"
    (Add-Content -Path "flyway.toml" `
    -Value "`n`n[environments.shadow]`nurl = `"$shadowUrl`"`nprovisioner = `"backup`"`n`n[environments.shadow.resolvers.backup]`nbackupFilePath = `"$backupPath`"`nbackupVersion = `"000`"`n`n  [environments.shadow.resolvers.backup.sqlserver]`n  generateWithMove = true"
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

$pocSetupMessage = "`nDo you want to set up a full POC environment with dev and test databases?"
if ($backupPath -ne "") {
    $pocSetupMessage += " $backupPath WILL BE RESTORED multiple times to provided instance for dev and test databases. (Y/N)?"
} else {
    $pocSetupMessage += "Provided database is assumed as test and new dev database WILL BE CREATED (Y/N)?"
}

# Interactive prompt for full POC environment setup
$response = Read-Host $pocSetupMessage
if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "Setting up full POC environment..."
    if ($backupPath -eq "") {
            $devDatabaseName = $databaseName + '_dev'
            $devUrl = $Url -replace "databaseName=[^;]*", "databaseName=$devDatabaseName"
            (Add-Content -Path "flyway.toml" `
            -Value "`n`n[environments.development]`nurl = `"$devUrl`"`nprovisioner = `"create-database`""
            )
            Write-Host "Creating dev database $devDatabaseName and running Baseline script to populate it..."
            flyway migrate -environment=development

    } else {
        $devDatabaseName = $databaseName + '_dev'
        $devUrl = $Url -replace "databaseName=[^;]*", "databaseName=$devDatabaseName"
        (Add-Content -Path "flyway.toml" `
        -Value "`n`n[environments.development]`nurl = `"$devUrl`"`nprovisioner = `"backup`"`n`n[environments.development.resolvers.backup]`nbackupFilePath = `"$backupPath`"`nbackupVersion = `"000`"`n`n  [environments.development.resolvers.backup.sqlserver]`n  generateWithMove = true"
        )
        $testDatabaseName = $databaseName + '_test'
        $testUrl = $Url -replace "databaseName=[^;]*", "databaseName=$testDatabaseName"
        (Add-Content -Path "flyway.toml" `
        -Value "`n`n[environments.test]`nurl = `"$testUrl`"`nprovisioner = `"backup`"`n`n[environments.test.resolvers.backup]`nbackupFilePath = `"$backupPath`"`nbackupVersion = `"000`"`n`n  [environments.test.resolvers.backup.sqlserver]`n  generateWithMove = true"
        )
        Write-Host "Restoring backup file to create dev database $devDatabaseName"  
        flyway migrate -environment=development
        Write-Host "Restoring backup file to create test database $testDatabaseName"  
        flyway migrate -environment=test
    }
    Write-Host "POC environment setup completed."
    $skipped = $false
  
} else {
    Write-Host "Just showing flyway commands with documentation links to run manually"
    $skipped = $true
}

$sqlTablescript = "
 CREATE TABLE AA_Test_Parent (
    ParentID INT PRIMARY KEY,
    ParentName NVARCHAR(100) NOT NULL
);

CREATE TABLE AA_Test_Child (
    ChildID INT PRIMARY KEY,
    ChildName NVARCHAR(100) NOT NULL,
    ParentID INT,
    FOREIGN KEY (ParentID) REFERENCES AA_Test_Parent(ParentID) ON DELETE CASCADE
);"
# Interactive prompt for full POC environment setup
$runForMe = Read-Host "Use this script to create a sample migration - $sqlTablescript `n should I run this for you (Y)?`n Or do you want to run them yourself (N)?"
if ($runForMe -eq "Y" -or $runForMe -eq "y" -and -not $skipped) {
    Write-Host "Creating sample tables in dev database..."
    flyway migrate "-initSql=$sqlTablescript" "-url=$devUrl" "-user=$User" "-password=$Password"
    Write-Host "Sample tables created in dev database."
    $runScriptsForMe = $true
} else {
    $response = Read-Host "Skipping sample table creation. Have you run them yourself against $devDatabaseName? (Y/N)?"
}
if ( $runForMe -eq "Y" -or  $runForMe -eq "y" -or $response -eq "y" -or $response -eq "Y" -and -not $skipped) {
    Write-Host "Creating migration scripts based on changes from dev to test database..."
    flyway diff model "-diff.source=development" "-diff.target=schemaModel" 
    flyway diff generate "-diff.source=schemaModel" "-diff.target=migrations" "-generate.types=versioned,undo" "-diff.buildEnvironment=shadow"
    Write-Host "Migration scripts created."
} else {
    Write-Host "Skipping migration script creation."
    
}
cd .. 