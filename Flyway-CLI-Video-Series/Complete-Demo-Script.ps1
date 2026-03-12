<#
.SYNOPSIS
    Complete Flyway CLI Video Series Demo Script
    
.DESCRIPTION
    This script demonstrates all Flyway CLI commands covered in the video series.
    Run each section interactively to follow along with the videos.
    
.NOTES
    Prerequisites:
    - Flyway Enterprise Edition installed and licensed
    - SQL Server instance available
    - PowerShell 5.1+
    
    Update the $ServerInstance variable to match your SQL Server.
#>

# =============================================================================
# CONFIGURATION - Update these for your environment
# =============================================================================
$ServerInstance = "localhost"  # Your SQL Server instance (e.g., "localhost\SQLEXPRESS")
$ProjectPath = "$env:TEMP\FlywayVideoDemo"
$DevDatabase = "VideoDemoDev"
$ShadowDatabase = "VideoDemoShadow"
$TestDatabase = "VideoDemoTest"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Demo {
    Write-Host "Press Enter to continue..." -ForegroundColor Yellow
    Read-Host
}

# =============================================================================
# SETUP - Create test databases
# =============================================================================
Write-Section "SETUP: Creating Test Databases"

Write-Host "Creating databases: $DevDatabase, $ShadowDatabase, $TestDatabase" -ForegroundColor Gray
$setupQuery = @"
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = '$DevDatabase') CREATE DATABASE [$DevDatabase];
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = '$ShadowDatabase') CREATE DATABASE [$ShadowDatabase];
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = '$TestDatabase') CREATE DATABASE [$TestDatabase];
"@

try {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $setupQuery
    Write-Host "Databases created successfully" -ForegroundColor Green
} catch {
    Write-Host "Error creating databases: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure SQL Server is running and you have permissions." -ForegroundColor Yellow
    exit 1
}

Pause-Demo

# =============================================================================
# VIDEO 1: flyway init
# =============================================================================
Write-Section "VIDEO 1: Project Initialization with flyway init"

# Create project directory
Write-Host "Creating project directory: $ProjectPath" -ForegroundColor Gray
if (Test-Path $ProjectPath) {
    Remove-Item $ProjectPath -Recurse -Force
}
New-Item -ItemType Directory -Path $ProjectPath | Out-Null
Set-Location $ProjectPath

# Show help
Write-Host "`nCommand: flyway help init" -ForegroundColor Yellow
flyway help init

Pause-Demo

# Initialize project
Write-Host "`nCommand: flyway init `"-init.projectName=VideoDemo`" `"-init.databaseType=sqlserver`"" -ForegroundColor Yellow
flyway init "-init.projectName=VideoDemo" "-init.databaseType=sqlserver"

Write-Host "`nProject structure created:" -ForegroundColor Gray
Get-ChildItem -Recurse | Select-Object FullName

# Add environment configuration
Write-Host "`nAdding environment configuration to flyway.toml..." -ForegroundColor Gray
@"

[environments.development]
url = "jdbc:sqlserver://$ServerInstance;databaseName=$DevDatabase;encrypt=true;integratedSecurity=true;trustServerCertificate=true"

[environments.shadow]
url = "jdbc:sqlserver://$ServerInstance;databaseName=$ShadowDatabase;encrypt=true;integratedSecurity=true;trustServerCertificate=true"
provisioner = "clean"

[environments.test]
url = "jdbc:sqlserver://$ServerInstance;databaseName=$TestDatabase;encrypt=true;integratedSecurity=true;trustServerCertificate=true"
"@ | Add-Content "flyway.toml"

Write-Host "Environments configured!" -ForegroundColor Green

Pause-Demo

# =============================================================================
# VIDEO 15: flyway testConnection (doing early to verify setup)
# =============================================================================
Write-Section "VIDEO 15: Testing Connection with flyway testConnection"

Write-Host "Command: flyway testConnection -environment=development" -ForegroundColor Yellow
flyway testConnection -environment=development

Pause-Demo

# =============================================================================
# CREATE SAMPLE OBJECTS IN DEV
# =============================================================================
Write-Section "SETUP: Creating Sample Objects in Development Database"

$sampleObjects = @"
-- Create schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Sales')
    EXEC('CREATE SCHEMA Sales');

-- Create Products table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Products' AND schema_id = SCHEMA_ID('Sales'))
CREATE TABLE Sales.Products (
    ProductId INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Create Customers table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Customers' AND schema_id = SCHEMA_ID('Sales'))
CREATE TABLE Sales.Customers (
    CustomerId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255),
    JoinDate DATE DEFAULT GETDATE()
);

-- Create View
IF NOT EXISTS (SELECT 1 FROM sys.views WHERE name = 'ProductSummary' AND schema_id = SCHEMA_ID('Sales'))
    EXEC('CREATE VIEW Sales.ProductSummary AS SELECT ProductId, ProductName, Price FROM Sales.Products');
"@

Write-Host "Creating sample tables and views in development database..." -ForegroundColor Gray
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DevDatabase -Query $sampleObjects
Write-Host "Sample objects created!" -ForegroundColor Green

Pause-Demo

# =============================================================================
# VIDEO 2: flyway diff
# =============================================================================
Write-Section "VIDEO 2: Comparing Changes with flyway diff"

Write-Host "Command: flyway diff `"-diff.source=development`" `"-diff.target=schemaModel`"" -ForegroundColor Yellow
flyway diff "-diff.source=development" "-diff.target=schemaModel"

Pause-Demo

# =============================================================================
# VIDEO 3: flyway diffText
# =============================================================================
Write-Section "VIDEO 3: Visualizing Changes with flyway diffText"

Write-Host "Command: flyway diffText `"-diff.source=development`" `"-diff.target=schemaModel`"" -ForegroundColor Yellow
flyway diffText "-diff.source=development" "-diff.target=schemaModel"

Pause-Demo

# =============================================================================
# VIDEO 4: flyway model
# =============================================================================
Write-Section "VIDEO 4: Building Schema Model with flyway model"

Write-Host "Command: flyway model" -ForegroundColor Yellow
flyway model

Write-Host "`nSchema model files created:" -ForegroundColor Gray
Get-ChildItem -Path "schema-model" -Recurse | Select-Object FullName

Write-Host "`nContents of Sales.Products.sql:" -ForegroundColor Gray
Get-Content "schema-model\Tables\Sales.Products.sql"

Pause-Demo

# =============================================================================
# VIDEO 5: flyway generate
# =============================================================================
Write-Section "VIDEO 5: Generating Migrations with flyway generate"

Write-Host "Step 1: Run diff from schemaModel to migrations" -ForegroundColor Gray
Write-Host "Command: flyway diff `"-diff.source=schemaModel`" `"-diff.target=migrations`" `"-diff.buildEnvironment=shadow`"" -ForegroundColor Yellow
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

Pause-Demo

Write-Host "`nStep 2: Generate migration script" -ForegroundColor Gray
Write-Host "Command: flyway generate `"-generate.description=Initial_Schema`"" -ForegroundColor Yellow
flyway generate "-generate.description=Initial_Schema"

Write-Host "`nGenerated migration files:" -ForegroundColor Gray
Get-ChildItem "migrations" | Select-Object Name

Pause-Demo

# =============================================================================
# VIDEO 6: flyway migrate
# =============================================================================
Write-Section "VIDEO 6: Applying Migrations with flyway migrate"

Write-Host "Command: flyway migrate -environment=test" -ForegroundColor Yellow
flyway migrate -environment=test

Pause-Demo

# =============================================================================
# VIDEO 7: flyway info
# =============================================================================
Write-Section "VIDEO 7: Viewing Migration Status with flyway info"

Write-Host "Command: flyway info -environment=test" -ForegroundColor Yellow
flyway info -environment=test

Pause-Demo

# =============================================================================
# VIDEO 8: flyway validate
# =============================================================================
Write-Section "VIDEO 8: Validating Migrations with flyway validate"

Write-Host "Command: flyway validate -environment=test" -ForegroundColor Yellow
flyway validate -environment=test

Pause-Demo

# =============================================================================
# ADD MORE CHANGES FOR PREPARE/DEPLOY DEMO
# =============================================================================
Write-Section "SETUP: Adding More Changes for Prepare/Deploy Demo"

$addColumn = "ALTER TABLE Sales.Products ADD Category NVARCHAR(50);"
Write-Host "Adding Category column to Sales.Products..." -ForegroundColor Gray
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DevDatabase -Query $addColumn

# Update schema model and generate new migration
Write-Host "Updating schema model and generating migration..." -ForegroundColor Gray
flyway diff "-diff.source=development" "-diff.target=schemaModel" | Out-Null
flyway model | Out-Null
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow" | Out-Null
flyway generate "-generate.description=Add_Category_Column" | Out-Null

Write-Host "New migration created!" -ForegroundColor Green
Get-ChildItem "migrations" | Select-Object Name

Pause-Demo

# =============================================================================
# VIDEO 9: flyway prepare
# =============================================================================
Write-Section "VIDEO 9: Preparing Deployment Scripts with flyway prepare"

Write-Host "Command: flyway prepare `"-prepare.source=migrations`" `"-prepare.target=test`" `"-prepare.scriptFilename=deploy_test.sql`"" -ForegroundColor Yellow
flyway prepare "-prepare.source=migrations" "-prepare.target=test" "-prepare.scriptFilename=deploy_test.sql"

Write-Host "`nGenerated deployment script (first 50 lines):" -ForegroundColor Gray
Get-Content "deploy_test.sql" | Select-Object -First 50

Pause-Demo

# =============================================================================
# VIDEO 10: flyway deploy
# =============================================================================
Write-Section "VIDEO 10: Deploying with flyway deploy"

Write-Host "Command: flyway deploy `"-deploy.scriptFilename=deploy_test.sql`" -environment=test" -ForegroundColor Yellow
flyway deploy "-deploy.scriptFilename=deploy_test.sql" -environment=test

Write-Host "`nVerifying deployment:" -ForegroundColor Gray
flyway info -environment=test

Pause-Demo

# =============================================================================
# VIDEO 12: flyway snapshot
# =============================================================================
Write-Section "VIDEO 12: Creating Snapshots with flyway snapshot"

Write-Host "Command: flyway snapshot `"-snapshot.source=test`" `"-snapshot.filename=test_snapshot.snp`"" -ForegroundColor Yellow
flyway snapshot "-snapshot.source=test" "-snapshot.filename=test_snapshot.snp"

Write-Host "`nSnapshot file created:" -ForegroundColor Gray
Get-ChildItem "*.snp" | Select-Object Name, Length

Pause-Demo

# =============================================================================
# VIDEO 11: flyway clean
# =============================================================================
Write-Section "VIDEO 11: Managing Database Cleanup with flyway clean"

Write-Host "Command: flyway clean -environment=shadow `"-cleanDisabled=false`"" -ForegroundColor Yellow
flyway clean -environment=shadow "-cleanDisabled=false"

Pause-Demo

# =============================================================================
# CLEANUP
# =============================================================================
Write-Section "CLEANUP: Removing Test Resources"

Write-Host "Do you want to clean up the test databases and project folder? (Y/N)" -ForegroundColor Yellow
$cleanup = Read-Host

if ($cleanup -eq "Y" -or $cleanup -eq "y") {
    Write-Host "Removing test databases..." -ForegroundColor Gray
    $cleanupQuery = @"
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$DevDatabase') DROP DATABASE [$DevDatabase];
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$ShadowDatabase') DROP DATABASE [$ShadowDatabase];
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$TestDatabase') DROP DATABASE [$TestDatabase];
"@
    
    try {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $cleanupQuery
        Write-Host "Databases removed!" -ForegroundColor Green
    } catch {
        Write-Host "Error removing databases: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Removing project folder..." -ForegroundColor Gray
    Set-Location $env:TEMP
    Remove-Item $ProjectPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Project folder removed!" -ForegroundColor Green
} else {
    Write-Host "Cleanup skipped. Resources remain at:" -ForegroundColor Yellow
    Write-Host "  Project: $ProjectPath" -ForegroundColor Gray
    Write-Host "  Databases: $DevDatabase, $ShadowDatabase, $TestDatabase" -ForegroundColor Gray
}

Write-Section "DEMO COMPLETE!"
Write-Host "Thank you for following the Flyway CLI Video Series demo!" -ForegroundColor Green
