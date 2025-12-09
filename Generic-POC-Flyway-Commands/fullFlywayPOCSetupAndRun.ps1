# Set parameters
$overWriteProject = $true # Set to true to delete and recreate the project folder. Can be useful when configuring from scratch.
$databaseType = "SqlServer" # alt values: SqlServer Oracle PostgreSql MySql 
# connection string to prodlike database
# This POC will create a dev, test, shadow DB - this name will be in the root of all subsequent names
$baseDBName = "flywayPOC"
$devDBName = $baseDBName + "_dev"
$baselineSourceIfNoBackup = "jdbc:sqlserver://localhost;databaseName=" + $baseDBName + ";encrypt=false;integratedSecurity=true;trustServerCertificate=true"
$devDBConnectionString = "jdbc:sqlserver://localhost;databaseName=" + $devDBName + ";encrypt=false;integratedSecurity=true;trustServerCertificate=true"
$User = ""
$Password = ""
# Can be changed to a different name than DB name
$projectName = "$baseDBName"
# This can be explicit
$projectPath = "."
# Backup as Baseline path - must be accessible by DB server - leave empty if not needed 
$backupPath = "C:\\Program Files\\Microsoft SQL Server\\MSSQL13.MSSQLSERVER\\MSSQL\\Backup\\NewWorldDB_Dev.bak" # eg C:\\Program Files\\Microsoft SQL Server\\MSSQL13.MSSQLSERVER\\MSSQL\\Backup\\Northwind.bak
$workingDir = "$projectPath\$projectName"

# Set the schemas value
$Schemas = @("") # can be empty for SqlServer

# Initialize variables at script level - these will be provided later do not fill
$devDatabaseName = ""
$devUrl = ""
$testDatabaseName = ""
$testUrl = ""
$shadowUrl = ""

# Initialize project - create folders and flyway.toml - delete existing project folder if exists
# For project setup, it can be helpful to overwrite as configuration may change. Set $overWriteProject = $true to force recreation
if ($overWriteProject -or -not (Test-Path -Path "$workingDir")) {
    if (Test-Path -Path "$workingDir") {
        Remove-Item -Path $projectName -Recurse -Force
    }
    Set-Location $projectPath
    mkdir $projectName
    Set-Location ./$projectName
    flyway init "-init.projectName=$projectName" "-init.databaseType=$databaseType"

    if ($backupPath -ne "") {
        # Add shadow environment to flyway.toml
        $ShadowDatabaseName = $baseDBName + '_${env.UserName}_shadow'
        $shadowUrl = $baselineSourceIfNoBackup -replace "databaseName=[^;]*", "databaseName=$ShadowDatabaseName"
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
        flyway diff model "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$baselineSourceIfNoBackup" "-environments.dev.user=$User" "-environments.dev.password=$Password" "-environments.dev.schemas=$Schemas" 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }
        flyway diff generate "-diff.source=schemaModel" "-diff.target=empty" "-generate.types=baseline" "-generate.description=Baseline" "-generate.version=1.0" 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }
    } else {
        Write-Output "Restoring provided backup file to server URL and Populating SchemaModel from it"
        flyway diff model "-diff.source=migrations" "-diff.target=schemaModel" "-diff.buildEnvironment=shadow" 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }
    }
} else {
    Write-Host "Skipping project initialization. Set \$overWriteProject = \$true to recreate the project." -ForegroundColor Yellow
    Set-Location "$projectPath\$projectName"
}

$pocSetupMessage = "`nYDo you want to set up a full POC environment with dev and test databases?"
if ($backupPath -ne "") {
    $pocSetupMessage += " $backupPath WILL BE RESTORED multiple times to provided instance for dev and test databases. (Y/N)?"
} else {
    $pocSetupMessage += "Provided database is assumed as test and new dev database WILL BE CREATED (Y/N)?"
}

# Interactive prompt for full POC environment setup - DB and TOML setup
$response = Read-Host $pocSetupMessage
if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "Setting up full POC environment..."
    if ($backupPath -eq "") {
            $devUrl = $baselineSourceIfNoBackup -replace "databaseName=[^;]*", "databaseName=$devDBName"
            (Add-Content -Path "flyway.toml" `
            -Value "`n`n[environments.development]`nurl = `"$devUrl`"`nprovisioner = `"create-database`""
            )
            Write-Host "Creating dev database $devDBName and running Baseline script to populate it..."
            flyway migrate -environment=development 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }

    } else {
        $devUrl = $baselineSourceIfNoBackup -replace "databaseName=[^;]*", "databaseName=$devDBName"
        (Add-Content -Path "flyway.toml" `
        -Value "`n`n[environments.development]`nurl = `"$devUrl`"`nprovisioner = `"backup`"`n`n[environments.development.resolvers.backup]`nbackupFilePath = `"$backupPath`"`nbackupVersion = `"000`"`n`n  [environments.development.resolvers.backup.sqlserver]`n  generateWithMove = true"
        )
        $testDatabaseName = $baseDBName + '_test'
        $testUrl = $baselineSourceIfNoBackup -replace "databaseName=[^;]*", "databaseName=$testDatabaseName"
        (Add-Content -Path "flyway.toml" `
        -Value "`n`n[environments.test]`nurl = `"$testUrl`"`nprovisioner = `"backup`"`n`n[environments.test.resolvers.backup]`nbackupFilePath = `"$backupPath`"`nbackupVersion = `"000`"`n`n  [environments.test.resolvers.backup.sqlserver]`n  generateWithMove = true"
        )
        Write-Host "Restoring backup file to create dev database $devDBName"  
        flyway migrate repair -environment=development 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }
        Write-Host "Restoring backup file to create test database $testDatabaseName"  
        flyway migrate repair -environment=test 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }
    }
    Write-Host "POC environment setup completed."
    $skipped = $false
  
} else {
    Write-Host "Just showing flyway commands with documentation links to run manually"
    $skipped = $true
}

# Start Flyway Enterprise Trial and test connection
flyway auth -IAgreeToTheEula -startEnterpriseTrial 2>&1 | Out-Null
flyway testConnection "-url=$devDBConnectionString" "-user=$User" "-password=$Password" "-schemas=$Schemas" 2>&1 | ForEach-Object {
    # flyway auth will provide a 400 if already authenticated, squash that message
    if ($_ -notmatch "400") {
        $_
    }
}
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 400) {
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP: Make Database Changes" -ForegroundColor Yellow -BackgroundColor DarkBlue
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Make some changes to the dev DB ($devUrl) for Flyway to capture and generate a deployment script." -ForegroundColor White
Read-Host "Press Enter when ready to capture your changes in the schema model and in deployment and undo scripts"

#the Description of the migration script generated - should probably include feature/ticket information
$scriptName = "Jira123_YourDescription"

#Syncs the Schema Model folder with the provided Source URL
flyway diff model "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$devDBConnectionString" 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }
#Generated a new migration script by comparing the Schema Model folder to Build Url after it's been brought to current version.
flyway diff generate "-diff.source=schemaModel" "-diff.target=migrations" "-generate.types=versioned,undo" "-generate.description=$scriptName" "-diff.buildEnvironment=shadow" "-environments.shadow.url=$shadowUrl" 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' } 

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT: Deploy to Test Database ($testUrl)" -ForegroundColor Yellow -BackgroundColor DarkBlue
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "You are about to deploy changes to the test DB." -ForegroundColor White
Read-Host "Press Enter to run flyway migrate -environment=test -saveSnapshot=true"

flyway migrate -environment=test -saveSnapshot=true 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' } 

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "REVIEW: Check Deployment Results" -ForegroundColor Yellow -BackgroundColor DarkBlue
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "You have just deployed changes to: " -ForegroundColor White -NoNewline
Write-Host "$testUrl" -ForegroundColor Green
Write-Host "Go look at that database and look for the changes." -ForegroundColor White
Write-Host "Note: The flyway_schema_history table will have a record of deployments and metadata." -ForegroundColor Gray
Read-Host "Press Enter to proceed"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "INFO: View Deployment History" -ForegroundColor Yellow -BackgroundColor DarkBlue
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "You can run 'flyway info' from the command line to see the deployment history." -ForegroundColor White
Read-Host "Press Enter to run flyway info -environment=test"

flyway info -environment=test 2>&1 | Where-Object { $_ -notmatch 'Database: jdbc:' -and $_ -notmatch 'ERROR: Skipping filesystem location:' }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DRIFT DETECTION: Learn More" -ForegroundColor Yellow -BackgroundColor DarkBlue
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flyway can detect drift in your databases." -ForegroundColor White
Write-Host "Learn more at: " -ForegroundColor White -NoNewline
Write-Host "Drift Detection Tutorial" -ForegroundColor Cyan
Write-Host "https://documentation.red-gate.com/fd/tutorial-drift-report-for-deployments-using-embedded-snapshot-317493682.html" -ForegroundColor Blue
Read-Host "For drift to show up, you need to manually make a change to a target database outside of using Flyway. Make a schema change manually to $testUrl."
Read-Host "Press Enter to execute flyway check -drift -code -dryrun -environment=$test -check.code.failOnError=false -check.failOnDrift=false -check.deployedSnapshot=snapshothistory:current"


flyway check -drift -code -dryrun -environment=$test "-check.code.failOnError=false" "-check.failOnDrift=false" "-check.deployedSnapshot=snapshothistory:current"


# # Variables to be changed by user
# $configFiles = "C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml"
# $workingDirectory = "C:\WorkingFolders\FWD\NewWorldDB"



# # generic deployment
# Read-Host "Press Enter to run migrate command"
# flyway migrate -configFiles="$configFiles" -workingDirectory="$workingDirectory" -environment=$environment

# # ================================================================================

# # create snapshot after changes
# Read-Host "Press Enter to run snapshot command"
# flyway snapshot -environment=$environment -filename=snapshothistory:current -configFiles="$configFiles" -workingDirectory="$workingDirectory"

# # ================================================================================

# # undo back to a specific target number
# Read-Host "Press Enter to run undo command"
# flyway undo -configFiles="$configFiles" -workingDirectory="$workingDirectory" -environment=$environment -target=$target

# # ================================================================================

# # cherryPick forward
# Read-Host "Press Enter to run cherry-pick migrate command"
# flyway migrate -configFiles="$configFiles" -workingDirectory="$workingDirectory" -environment=$environment -cherryPick=$cherryPick

# # ================================================================================

# # drift and code analysis report with snapshots

# # run drift and code analysis (TO SEE DRIFT ALTER TARGET DB OUTSIDE OF FLYWAY)
# # check can be configured to fail on drift or code analysis triggering
# # it's possible to capture changes as well, but it is a duplication of what's stored in schema model and requires an extra database to deploy to in a CI fashion
# Read-Host "Press Enter to run drift check command"
# flyway check -drift -code -dryrun -environment=$environment -check.code.failOnError=false -check.failOnDrift=false -check.deployedSnapshot=snapshothistory:current -configFiles="$configFiles" -workingDirectory="$workingDirectory"

# # ================================================================================

# # generic deployment
# Read-Host "Press Enter to run migrate command"
# flyway migrate -configFiles="$configFiles" -workingDirectory="$workingDirectory" -environment=$environment

# # ================================================================================

# # create snapshot after changes
# Read-Host "Press Enter to run snapshot command"
# flyway snapshot -environment=$environment -filename=snapshothistory:current -configFiles="$configFiles" -workingDirectory="$workingDirectory"

Set-Location ..