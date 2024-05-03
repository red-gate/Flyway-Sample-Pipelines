###################################################################

#  ctrl + f5 to run

###################################################################

# Define base path
# $basePath = Get-Location
$basePath = "C:\WorkingFolders\FWD\NewWorldDB"

# Define variables for paths
$flywayTomlPath = Join-Path $basePath "flyway.toml"
$schemaDeltasPath = Join-Path $basePath "schemaDeltas.zip"
$deploymentDeltasPath = Join-Path $basePath "deploymentDeltas.zip"
$outputFolderPath = Join-Path $basePath "migrations"

# Diff between Dev and SchemaModel
$schemaDiffs = flyway-dev diff -p $flywayTomlPath --i-agree-to-the-eula --from=Dev --to=SchemaModel -a $schemaDeltasPath --output json | ConvertFrom-Json

foreach ($difference in $schemaDiffs.differences) {
    # Apply differences to SchemaModel
    echo $difference.id | flyway-dev apply -p $flywayTomlPath -a $schemaDeltasPath --verbose --i-agree-to-the-eula
    
    # Diff between SchemaModel and Migrations
    flyway-dev diff -p $flywayTomlPath --i-agree-to-the-eula --from=SchemaModel --to=Migrations -a $deploymentDeltasPath
    
    # Take and generate migrations
    flyway-dev take -p $flywayTomlPath -a $deploymentDeltasPath --i-agree-to-the-eula | flyway-dev generate -p $flywayTomlPath -a $deploymentDeltasPath --i-agree-to-the-eula --outputFolder=$outputFolderPath 
}
