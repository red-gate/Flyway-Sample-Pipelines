# Set preference for download progress
$ProgressPreference = 'SilentlyContinue'

#Flyway Version to Use
$flywayVersion = $($env:FLYWAY_VERSION)

#Should add a variable to force a reinstall in case something goes wrong

#Assign location for Flyway to be extracted to
$ExtractPath = "C:\FlywayCLI\"
$InstallFolder = "flyway-$flywayVersion"
$flywayBinPath = "${ExtractPath}$InstallFolder"

Write-Host "##vso[task.prependpath]$flywayBinPath"

# Check if the folder exists
Write-Host "Looking for Flyway version $flywayVersion"
Write-Host "Checking if the Flyway folder exists at $flywayBinPath..."
if (Test-Path $flywayBinPath) {
    Write-Host "Flyway folder already exists."
    exit
}

Write-Host "Version $flywayVersion is not installed"
Write-Host "Deleting $ExtractPath"
Remove-Item $ExtractPath -Recurse

Write-Host "Creating Flyway folder..."
New-Item $ExtractPath -ItemType Directory
Write-Host "Flyway folder created successfully."

#Flyway URL to download CLI
$Url = "https://download.red-gate.com/maven/release/org/flywaydb/enterprise/flyway-commandline/$flywayVersion/flyway-commandline-$flywayVersion-windows-x64.zip"

#Insert path for downloaded files
$DownloadZipFile = "C:\FlywayCLI\" + $(Split-Path -Path $Url -Leaf)

# Download the CLI
Write-Host "Downloading Flyway CLI from $Url..."
Invoke-WebRequest -Uri $Url -OutFile $DownloadZipFile -UseBasicParsing
Write-Host "Flyway CLI downloaded successfully."

# Extract the CLI
Write-Host "Extracting Flyway CLI..."
Expand-Archive -LiteralPath $DownloadZipFile -DestinationPath $ExtractPath -Force
Write-Host "Flyway CLI extracted successfully."

# Cleanup the ZIP file
Write-Host "Cleaning up the downloaded ZIP file..."
Remove-Item -Path $DownloadZipFile -Force
Write-Host "ZIP file removed."

# Set the PATH environment variable
Write-Host "Updating the PATH environment variable..."
$env:Path += ";$flywayBinPath"
[Environment]::SetEnvironmentVariable("PATH", $env:Path, [EnvironmentVariableTarget]::Machine)

# Output the updated PATH contents
$PathContents = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
Write-Host "Updated PATH: $PathContents"

# List contents of the Flyway installation directory
Write-Host "Listing contents of the Flyway installation directory:"
Get-ChildItem -Path $flywayBinPath

# Attempt to run Flyway
Write-Host "Attempting to run Flyway..."
& "$flywayBinPath\flyway.cmd" --version