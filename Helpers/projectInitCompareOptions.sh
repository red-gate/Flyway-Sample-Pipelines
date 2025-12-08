#!/bin/bash

# Set parameters
DATABASE_TYPE="SqlServer" # alt values: SqlServer Oracle PostgreSql MySql
# connection string to prodlike database
URL="jdbc:sqlserver://localhost;databaseName=NewWorldDB_Dev;encrypt=false;integratedSecurity=true;trustServerCertificate=true"
USER=""
PASSWORD=""
DATABASE_NAME=$(echo "$URL" | sed -n 's/.*databaseName=\([^;]*\).*/\1/p')
PROJECT_NAME="$DATABASE_NAME"
PROJECT_PATH="."
# Backup as Baseline path - must be accessible by DB server - leave empty if not needed
BACKUP_PATH="/var/opt/mssql/backup/Northwind.bak" # eg /var/opt/mssql/backup/Northwind.bak

# Set the schemas value
SCHEMAS="" # can be empty for SqlServer

# Start Flyway Enterprise Trial and test connection
flyway auth -IAgreeToTheEula -startEnterpriseTrial
flyway testConnection "-url=$URL" "-user=$USER" "-password=$PASSWORD" "-schemas=$SCHEMAS"
if [ $? -ne 0 ]; then
    exit 1
fi

# Initialize project - create folders and flyway.toml - delete existing project folder if exists
if [ -d "$PROJECT_PATH/$PROJECT_NAME" ]; then
    rm -rf "$PROJECT_PATH/$PROJECT_NAME"
fi
cd "$PROJECT_PATH"
mkdir "$PROJECT_NAME"
cd "./$PROJECT_NAME"
flyway init "-init.projectName=$PROJECT_NAME" "-init.databaseType=$DATABASE_TYPE"

if [ -n "$BACKUP_PATH" ]; then
    # Add shadow environment to flyway.toml
    SHADOW_DATABASE_NAME="${DATABASE_NAME}_${USER}_shadow"
    SHADOW_URL=$(echo "$URL" | sed "s/databaseName=[^;]*/databaseName=$SHADOW_DATABASE_NAME/")
    cat >> "flyway.toml" << EOF


[environments.shadow]
url = "$SHADOW_URL"
provisioner = "backup"

[environments.shadow.resolvers.backup]
backupFilePath = "$BACKUP_PATH"
backupVersion = "000"

  [environments.shadow.resolvers.backup.sqlserver]
  generateWithMove = true
EOF
fi

<< 'COMMENT'
# Modify flyway.toml to adjust comparison options
sed -i 's/ignorePermissions\s*=\s*false/ignorePermissions = true/' "flyway.toml"
sed -i 's/ignoreUsersPermissionsAndRoleMemberships\s*=\s*false/ignoreUsersPermissionsAndRoleMemberships = true/' "flyway.toml"
sed -i 's/includeDependencies\s*=\s*true/includeDependencies = false/' "flyway.toml"

# Define the file path
FILE_PATH="Filter.scpf"

# Check if the file exists
if [ -f "$FILE_PATH" ]; then
    # Update the XML file using sed or xmlstarlet (requires xmlstarlet installed)
    # Using sed for basic XML manipulation
    sed -i '/<None>/,/<\/None>/ {
        s|<Include>.*</Include>|<Include>False</Include>|
        s|<Expression>.*</Expression>|<Expression>((@SCHEMA LIKE '\''cdc%'\''))</Expression>|
    }' "$FILE_PATH"
    
    echo "Filter.scpf updated successfully."
else
    echo "Filter.scpf does not exist."
fi
COMMENT

# Populate SchemaModel from dev database or from backup
if [ -z "$BACKUP_PATH" ]; then
    flyway diff model "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$URL" "-environments.dev.user=$USER" "-environments.dev.password=$PASSWORD" "-environments.dev.schemas=$SCHEMAS"
    flyway diff generate "-diff.source=schemaModel" "-diff.target=empty" "-generate.types=baseline" "-generate.description=Baseline" "-generate.version=1.0"
else
    echo "Restoring provided backup file to server URL and Populating SchemaModel from it"
    flyway diff model "-diff.source=migrations" "-diff.target=schemaModel" "-diff.buildEnvironment=shadow"
fi
cd ..
