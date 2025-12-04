$projectPath = "$(System.DefaultWorkingDirectory)\$(Build.Repository.Name)" # Get-Location for current dir

#source of Changes eg. Shared Dev environment
$sourceUrl = "jdbc:sqlserver://localhost;databaseName=NewWorldDB_Dev;encrypt=false;integratedSecurity=true;trustServerCertificate=true"

#scratch DB to allow flyway to use to generate a new script - can provide a backup file that flyway will rehydrate on the specified URL or existing empty db to build entirly from code eg. 1__Baseline.sql to 1+n__current_version.sql
$buildUrl = "jdbc:sqlserver://localhost;databaseName=NewWorldDB_Shadow;encrypt=false;integratedSecurity=true;trustServerCertificate=true"

#the Description of the migration script generated - should probably include feature/ticket information
$scriptName = "YourNewMigrationDescription"

#Syncs the Schema Model folder with the provided Source URL
flyway diff model "-workingDirectory=$projectPath" "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$sourceUrl"
#Generated a new migration script by comparing the Schema Model folder to Build Url after it's been brought to current version.
flyway diff generate "-workingDirectory=$projectPath" "-diff.source=schemaModel" "-diff.target=migrations" "-generate.types=versioned,undo" "-generate.description=$scriptName" "-diff.buildEnvironment=shadow" "-environments.shadow.url=$buildUrl" 