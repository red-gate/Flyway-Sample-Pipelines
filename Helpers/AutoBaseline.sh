#!/bin/bash
set -euo pipefail

# Point to where flyway dev is
# If you didn't create the entrypoint script you may need to invoke flyway dev through dotnet
# e.g. /opt/flyway-desktop/dotnet/dotnet /opt/flyway-desktop/flyway-dev/flyway-dev.dll
flyway-dev() {
    /opt/flyway-desktop/flyway-dev.sh --i-agree-to-the-eula "$@"
}

# Set the working folder path
WorkingFolderPath=~/.

# Set the database type and database connection properties
DatabaseType="Oracle" # alt values: SqlServer Oracle PostgreSql 
Url="jdbc:oracle:thin:@//localhost:1521/Dev1"
User="HR"
Password="Password"
Schemas='"HR"' # May be '' for SqlServer or '"Schema1", "Schema2"' for Oracle

# Set the paths
ArtifactPath="/tmp/artifact.zip"
ProjectPath="$WorkingFolderPath/flyway.toml"
MigrationPath="$WorkingFolderPath/migrations"

# Create a project
flyway-dev init -n Autobaseline -p "$WorkingFolderPath" --database-type "$DatabaseType"

echo -e "\n\n[environments.development]\nurl = \"some-url\"\nschemas = [$Schemas]" >> "$ProjectPath"

# schema model diffs
DiffOptions=$(cat <<-END
{ "url": "$Url", "user": "$User", "password": "$Password", "schemas": [$Schemas], "resolverProperties": [] } 
END
)

echo "$DiffOptions" \
  | flyway-dev diff -p "$ProjectPath" -a "$ArtifactPath" --from Target --to SchemaModel

#apply to schema model
flyway-dev take -p "$ProjectPath" -a "$ArtifactPath" \
  | flyway-dev apply -p "$ProjectPath" -a "$ArtifactPath"

echo "$DiffOptions" \
  | flyway-dev diff -p "$ProjectPath" -a "$ArtifactPath" --from Target --to Empty

# Generate the baseline from all differences
flyway-dev take -p "$ProjectPath" -a "$ArtifactPath" \
  | flyway-dev generate -p "$ProjectPath" -a "$ArtifactPath" -o "$MigrationPath" --name 'B1__baseline.sql' --versioned-only