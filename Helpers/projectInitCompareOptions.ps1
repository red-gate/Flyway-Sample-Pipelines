$databaseType = "SqlServer" # alt values: SqlServer Oracle PostgreSql MySql 
$Url = "jdbc:sqlserver://localhost;databaseName=NewWorldDB_Dev;encrypt=false;integratedSecurity=true;trustServerCertificate=true"
$User = ""
$Password = ""
$projectName = "Autobaseline"
$projectPath = "."

# Set the schemas value
$Schemas = @("") # can be empty for SqlServer


flyway auth -IAgreeToTheEula -startEnterpriseTrial
$ErrorActionPreference = 'Break'
flyway testConnection "-url=$Url" "-user=$User" "-password=$Password" "-schemas=$Schemas" 
if ($LASTEXITCODE -ne 0) {
    exit 1
}

if (Test-Path -Path "$projectPath\$projectName") {
    Remove-Item -Path $projectName -Recurse -Force
}
cd $projectPath
mkdir $projectName
cd ./$projectName
flyway init "-init.projectName=$projectName" "-init.databaseType=$databaseType"

<# ## Modify flyway.toml to adjust comparison options
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

flyway diff model "-diff.source=dev" "-diff.target=schemaModel" "-environments.dev.url=$Url" "-environments.dev.user=$User" "-environments.dev.password=$Password" "-environments.dev.schemas=$Schemas"
flyway diff generate "-diff.source=schemaModel" "-diff.target=empty" "-generate.types=baseline" "-generate.description=Baseline" "-generate.version=1.0" 
cd .. 