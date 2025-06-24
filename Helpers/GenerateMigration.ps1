# Define base path
# $basePath = "C:\WorkingFolders\FWD\<projectRoot>"
$basePath = Get-Location

# Define variables for paths
$flywayTomlPath = Join-Path $basePath "flyway.toml"
$deploymentDeltasPath = Join-Path $basePath "deploymentDeltas.zip"
$outputFolderPath = Join-Path $basePath "migrations"

# Diff between SchemaModel and Migrations using Shadow defined in the flyway.toml
flyway-dev diff -p $flywayTomlPath --i-agree-to-the-eula --from=SchemaModel --to=Migrations -a $deploymentDeltasPath

# Take and generate migrations
flyway-dev take -p $flywayTomlPath -a $deploymentDeltasPath --i-agree-to-the-eula | flyway-dev generate -p $flywayTomlPath -a $deploymentDeltasPath --i-agree-to-the-eula --outputFolder=$outputFolderPath 