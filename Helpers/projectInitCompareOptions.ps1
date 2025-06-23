# For this to work you will need to run "flyway auth -IAgreeToTheEula", and update project name and Database URL

$databaseType = "SqlServer" # alt values: SqlServer Oracle PostgreSql MySql 
$Url = "jdbc:sqlserver://localhost;databaseName=NewWorldDB_Dev;encrypt=false;integratedSecurity=true;trustServerCertificate=true"
$User = ""
$Password = ""
$projectName = "Autobaseline"

# Set the schemas value
$Schemas = @("") # can be empty for SqlServer

mkdir $projectName
cd ./$projectName
flyway init "-init.projectName=$projectName" "-init.databaseType=$databaseType"

(Get-Content -Path "flyway.toml") `
-replace 'ignorePermissions\s*=\s*false', 'ignorePermissions = true' `
-replace 'ignoreUsersPermissionsAndRoleMemberships\s*=\s*false', 'ignoreUsersPermissionsAndRoleMemberships = true' `
-replace 'includeDependencies\s*=\s*true', 'includeDependencies = false' |
Set-Content -Path "flyway.toml"

flyway diff model "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$Url" "-environments.dev.user=$User" "-environments.dev.password=$Password" "-environments.dev.schemas=$Schemas"
flyway diff generate "-diff.source=schemaModel" "-diff.target=empty" "-generate.types=baseline" "-generate.version=1.0.0" 