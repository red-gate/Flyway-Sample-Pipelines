#!/bin/bash
#
# Complete Flyway CLI Video Series Demo Script (Bash Version)
#
# DESCRIPTION:
#   This script demonstrates all Flyway CLI commands covered in the video series.
#   Run interactively to follow along with the videos.
#
# PREREQUISITES:
#   - Flyway Enterprise Edition installed and licensed
#   - SQL Server instance available (with sqlcmd or mssql-tools installed)
#   - Bash shell (Linux/macOS/WSL)
#
# USAGE:
#   chmod +x Complete-Demo-Script.sh
#   ./Complete-Demo-Script.sh

# =============================================================================
# CONFIGURATION - Update these for your environment
# =============================================================================
SERVER_INSTANCE="localhost"  # Your SQL Server instance
PROJECT_PATH="$HOME/FlywayVideoDemo"
DEV_DATABASE="VideoDemoDev"
SHADOW_DATABASE="VideoDemoShadow"
TEST_DATABASE="VideoDemoTest"

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
write_section() {
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo ""
}

pause_demo() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

run_sql() {
    # Uses sqlcmd to execute SQL against SQL Server
    # Adjust connection parameters as needed for your environment
    sqlcmd -S "$SERVER_INSTANCE" -Q "$1" -C 2>/dev/null
}

run_sql_db() {
    # Execute SQL against a specific database
    sqlcmd -S "$SERVER_INSTANCE" -d "$1" -Q "$2" -C 2>/dev/null
}

# =============================================================================
# PREFLIGHT CHECK
# =============================================================================
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for flyway
if ! command -v flyway &> /dev/null; then
    echo -e "${RED}Error: Flyway is not installed or not in PATH${NC}"
    echo -e "${GRAY}Install Flyway and ensure it's in your PATH${NC}"
    exit 1
fi

# Check for sqlcmd
if ! command -v sqlcmd &> /dev/null; then
    echo -e "${RED}Error: sqlcmd is not installed${NC}"
    echo -e "${GRAY}Install mssql-tools: sudo apt-get install mssql-tools${NC}"
    exit 1
fi

echo -e "${GREEN}Prerequisites check passed!${NC}"
echo ""

# =============================================================================
# SETUP - Create test databases
# =============================================================================
write_section "SETUP: Creating Test Databases"

echo -e "${GRAY}Creating databases: $DEV_DATABASE, $SHADOW_DATABASE, $TEST_DATABASE${NC}"

SETUP_QUERY="
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = '$DEV_DATABASE') CREATE DATABASE [$DEV_DATABASE];
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = '$SHADOW_DATABASE') CREATE DATABASE [$SHADOW_DATABASE];
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = '$TEST_DATABASE') CREATE DATABASE [$TEST_DATABASE];
"

if run_sql "$SETUP_QUERY"; then
    echo -e "${GREEN}Databases created successfully${NC}"
else
    echo -e "${RED}Error creating databases. Make sure SQL Server is running and you have permissions.${NC}"
    exit 1
fi

pause_demo

# =============================================================================
# VIDEO 1: flyway init
# =============================================================================
write_section "VIDEO 1: Project Initialization with flyway init"

# Create project directory
echo -e "${GRAY}Creating project directory: $PROJECT_PATH${NC}"
rm -rf "$PROJECT_PATH"
mkdir -p "$PROJECT_PATH"
cd "$PROJECT_PATH" || exit 1

# Show help
echo -e "${YELLOW}Command: flyway help init${NC}"
flyway help init

pause_demo

# Initialize project
echo -e "${YELLOW}Command: flyway init \"-init.projectName=VideoDemo\" \"-init.databaseType=sqlserver\"${NC}"
flyway init "-init.projectName=VideoDemo" "-init.databaseType=sqlserver"

echo -e "${GRAY}Project structure created:${NC}"
find . -type f

# Add environment configuration
echo -e "${GRAY}Adding environment configuration to flyway.toml...${NC}"
cat >> flyway.toml << EOF

[environments.development]
url = "jdbc:sqlserver://$SERVER_INSTANCE;databaseName=$DEV_DATABASE;encrypt=true;integratedSecurity=false;trustServerCertificate=true"
user = "\${localSecret.development_user}"
password = "\${localSecret.development_password}"

[environments.shadow]
url = "jdbc:sqlserver://$SERVER_INSTANCE;databaseName=$SHADOW_DATABASE;encrypt=true;integratedSecurity=false;trustServerCertificate=true"
user = "\${localSecret.shadow_user}"
password = "\${localSecret.shadow_password}"
provisioner = "clean"

[environments.test]
url = "jdbc:sqlserver://$SERVER_INSTANCE;databaseName=$TEST_DATABASE;encrypt=true;integratedSecurity=false;trustServerCertificate=true"
user = "\${localSecret.test_user}"
password = "\${localSecret.test_password}"
EOF

echo -e "${GREEN}Environments configured!${NC}"
echo ""
echo -e "${YELLOW}NOTE: On Linux/WSL, you'll need to configure SQL authentication.${NC}"
echo -e "${GRAY}Create .flyway/local-secrets.toml with your credentials:${NC}"
echo ""
echo "  mkdir -p .flyway"
echo "  cat > .flyway/local-secrets.toml << 'SECRETS'"
echo "  development_user = \"sa\""
echo "  development_password = \"YourPassword\""
echo "  shadow_user = \"sa\""
echo "  shadow_password = \"YourPassword\""
echo "  test_user = \"sa\""
echo "  test_password = \"YourPassword\""
echo "  SECRETS"
echo ""
echo -e "${YELLOW}Press Enter after setting up secrets to continue...${NC}"
read -r

pause_demo

# =============================================================================
# VIDEO 15: flyway testConnection (doing early to verify setup)
# =============================================================================
write_section "VIDEO 15: Testing Connection with flyway testConnection"

echo -e "${YELLOW}Command: flyway testConnection -environment=development${NC}"
flyway testConnection -environment=development

pause_demo

# =============================================================================
# CREATE SAMPLE OBJECTS IN DEV
# =============================================================================
write_section "SETUP: Creating Sample Objects in Development Database"

SAMPLE_OBJECTS="
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
"

echo -e "${GRAY}Creating sample tables and views in development database...${NC}"
run_sql_db "$DEV_DATABASE" "$SAMPLE_OBJECTS"
echo -e "${GREEN}Sample objects created!${NC}"

pause_demo

# =============================================================================
# VIDEO 2: flyway diff
# =============================================================================
write_section "VIDEO 2: Comparing Changes with flyway diff"

echo -e "${YELLOW}Command: flyway diff \"-diff.source=development\" \"-diff.target=schemaModel\"${NC}"
flyway diff "-diff.source=development" "-diff.target=schemaModel"

pause_demo

# =============================================================================
# VIDEO 3: flyway diffText
# =============================================================================
write_section "VIDEO 3: Visualizing Changes with flyway diffText"

echo -e "${YELLOW}Command: flyway diffText \"-diff.source=development\" \"-diff.target=schemaModel\"${NC}"
flyway diffText "-diff.source=development" "-diff.target=schemaModel"

pause_demo

# =============================================================================
# VIDEO 4: flyway model
# =============================================================================
write_section "VIDEO 4: Building Schema Model with flyway model"

echo -e "${YELLOW}Command: flyway model${NC}"
flyway model

echo -e "${GRAY}Schema model files created:${NC}"
find schema-model -type f

echo -e "${GRAY}Contents of Sales.Products.sql:${NC}"
cat schema-model/Tables/Sales.Products.sql 2>/dev/null || echo "File not found in expected location"

pause_demo

# =============================================================================
# VIDEO 5: flyway generate
# =============================================================================
write_section "VIDEO 5: Generating Migrations with flyway generate"

echo -e "${GRAY}Step 1: Run diff from schemaModel to migrations${NC}"
echo -e "${YELLOW}Command: flyway diff \"-diff.source=schemaModel\" \"-diff.target=migrations\" \"-diff.buildEnvironment=shadow\"${NC}"
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

pause_demo

echo -e "${GRAY}Step 2: Generate migration script${NC}"
echo -e "${YELLOW}Command: flyway generate \"-generate.description=Initial_Schema\"${NC}"
flyway generate "-generate.description=Initial_Schema"

echo -e "${GRAY}Generated migration files:${NC}"
ls -la migrations/

pause_demo

# =============================================================================
# VIDEO 6: flyway migrate
# =============================================================================
write_section "VIDEO 6: Applying Migrations with flyway migrate"

echo -e "${YELLOW}Command: flyway migrate -environment=test${NC}"
flyway migrate -environment=test

pause_demo

# =============================================================================
# VIDEO 7: flyway info
# =============================================================================
write_section "VIDEO 7: Viewing Migration Status with flyway info"

echo -e "${YELLOW}Command: flyway info -environment=test${NC}"
flyway info -environment=test

pause_demo

# =============================================================================
# VIDEO 8: flyway validate
# =============================================================================
write_section "VIDEO 8: Validating Migrations with flyway validate"

echo -e "${YELLOW}Command: flyway validate -environment=test${NC}"
flyway validate -environment=test

pause_demo

# =============================================================================
# ADD MORE CHANGES FOR PREPARE/DEPLOY DEMO
# =============================================================================
write_section "SETUP: Adding More Changes for Prepare/Deploy Demo"

ADD_COLUMN="ALTER TABLE Sales.Products ADD Category NVARCHAR(50);"
echo -e "${GRAY}Adding Category column to Sales.Products...${NC}"
run_sql_db "$DEV_DATABASE" "$ADD_COLUMN"

# Update schema model and generate new migration
echo -e "${GRAY}Updating schema model and generating migration...${NC}"
flyway diff "-diff.source=development" "-diff.target=schemaModel" > /dev/null 2>&1
flyway model > /dev/null 2>&1
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow" > /dev/null 2>&1
flyway generate "-generate.description=Add_Category_Column" > /dev/null 2>&1

echo -e "${GREEN}New migration created!${NC}"
ls -la migrations/

pause_demo

# =============================================================================
# VIDEO 9: flyway prepare
# =============================================================================
write_section "VIDEO 9: Preparing Deployment Scripts with flyway prepare"

echo -e "${YELLOW}Command: flyway prepare \"-prepare.source=migrations\" \"-prepare.target=test\" \"-prepare.scriptFilename=deploy_test.sql\"${NC}"
flyway prepare "-prepare.source=migrations" "-prepare.target=test" "-prepare.scriptFilename=deploy_test.sql"

echo -e "${GRAY}Generated deployment script (first 50 lines):${NC}"
head -50 deploy_test.sql

pause_demo

# =============================================================================
# VIDEO 10: flyway deploy
# =============================================================================
write_section "VIDEO 10: Deploying with flyway deploy"

echo -e "${YELLOW}Command: flyway deploy \"-deploy.scriptFilename=deploy_test.sql\" -environment=test${NC}"
flyway deploy "-deploy.scriptFilename=deploy_test.sql" -environment=test

echo -e "${GRAY}Verifying deployment:${NC}"
flyway info -environment=test

pause_demo

# =============================================================================
# VIDEO 12: flyway snapshot
# =============================================================================
write_section "VIDEO 12: Creating Snapshots with flyway snapshot"

echo -e "${YELLOW}Command: flyway snapshot \"-snapshot.source=test\" \"-snapshot.filename=test_snapshot.snp\"${NC}"
flyway snapshot "-snapshot.source=test" "-snapshot.filename=test_snapshot.snp"

echo -e "${GRAY}Snapshot file created:${NC}"
ls -la *.snp 2>/dev/null || echo "No snapshot files found"

pause_demo

# =============================================================================
# VIDEO 11: flyway clean
# =============================================================================
write_section "VIDEO 11: Managing Database Cleanup with flyway clean"

echo -e "${YELLOW}Command: flyway clean -environment=shadow \"-cleanDisabled=false\"${NC}"
flyway clean -environment=shadow "-cleanDisabled=false"

pause_demo

# =============================================================================
# CLEANUP
# =============================================================================
write_section "CLEANUP: Removing Test Resources"

echo -e "${YELLOW}Do you want to clean up the test databases and project folder? (Y/N)${NC}"
read -r cleanup

if [[ "$cleanup" == "Y" || "$cleanup" == "y" ]]; then
    echo -e "${GRAY}Removing test databases...${NC}"
    
    CLEANUP_QUERY="
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$DEV_DATABASE') 
        ALTER DATABASE [$DEV_DATABASE] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$DEV_DATABASE') 
        DROP DATABASE [$DEV_DATABASE];
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$SHADOW_DATABASE') 
        ALTER DATABASE [$SHADOW_DATABASE] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$SHADOW_DATABASE') 
        DROP DATABASE [$SHADOW_DATABASE];
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$TEST_DATABASE') 
        ALTER DATABASE [$TEST_DATABASE] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '$TEST_DATABASE') 
        DROP DATABASE [$TEST_DATABASE];
    "
    
    if run_sql "$CLEANUP_QUERY"; then
        echo -e "${GREEN}Databases removed!${NC}"
    else
        echo -e "${RED}Error removing databases${NC}"
    fi
    
    echo -e "${GRAY}Removing project folder...${NC}"
    cd "$HOME" || exit
    rm -rf "$PROJECT_PATH"
    echo -e "${GREEN}Project folder removed!${NC}"
else
    echo -e "${YELLOW}Cleanup skipped. Resources remain at:${NC}"
    echo -e "${GRAY}  Project: $PROJECT_PATH${NC}"
    echo -e "${GRAY}  Databases: $DEV_DATABASE, $SHADOW_DATABASE, $TEST_DATABASE${NC}"
fi

write_section "DEMO COMPLETE!"
echo -e "${GREEN}Thank you for following the Flyway CLI Video Series demo!${NC}"
