$projectPath = "C:\WorkingFolders\FWD\NewWorldDB" # Get-Location for current dir

#source of Changes eg. Shared Dev environment
$sourceUrl = "jdbc:sqlserver://localhost;databaseName=NewWorldDB_Dev;encrypt=false;integratedSecurity=true;trustServerCertificate=true"

#scratch DB to allow flyway to use to generate a new script - can provide a backup file that flyway will rehydrate on the specified URL or existing empty db to build entirly from code eg. 1__Baseline.sql to 1+n__current_version.sql
$buildUrl = "jdbc:sqlserver://localhost;databaseName=NewWorldDB_Shadow;encrypt=false;integratedSecurity=true;trustServerCertificate=true"

#the Description of the migration script generated - should probably include feature/ticket information
$scriptName = "YourNewMigrationDescription"

# Define object types to iterate through
$objectTypes = @(
    "Table",
    "View", 
    "Stored Procedure",
    "Function",
    "Index",
    "Trigger",
    "Sequence",
    "Synonym",
    "Type"
)

Write-Host "Starting per-object migration generation process..." -ForegroundColor Cyan

# First, sync the Schema Model folder with the provided Source URL
Write-Host "`nSyncing schema model with source database..." -ForegroundColor Yellow
flyway diff model "-workingDirectory=$projectPath" "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$sourceUrl"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error syncing schema model. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "`nGenerating migrations per object type..." -ForegroundColor Yellow

# Iterate through each object type and generate individual migration scripts
foreach ($objectType in $objectTypes) {
    Write-Host "`nProcessing object type: $objectType" -ForegroundColor Cyan
    
    $description = "$scriptName-$($objectType.Replace(' ', ''))"
    
    # Generate migration script for this specific object type
    flyway diff generate `
        "-workingDirectory=$projectPath" `
        "-diff.source=schemaModel" `
        "-diff.target=migrations" `
        "-generate.types=versioned,undo" `
        "-generate.description=$description" `
        "-diff.buildEnvironment=shadow" `
        "-environments.shadow.url=$buildUrl" `
        "-generate.objectTypes=$objectType"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Successfully generated migration for: $objectType" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to generate migration for: $objectType" -ForegroundColor Red
    }
}

Write-Host "`nPer-object migration generation complete!" -ForegroundColor Cyan
