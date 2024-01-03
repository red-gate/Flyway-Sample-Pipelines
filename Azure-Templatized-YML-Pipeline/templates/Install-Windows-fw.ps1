#Flyway Version to Use - Check here for latest version information - https://documentation.red-gate.com/fd/command-line-184127404.html
 
$flywayVersion = '9.21.2'
 
#Flyway URL to download CLI
 
$Url = "https://download.red-gate.com/maven/release/org/flywaydb/enterprise/flyway-commandline/$flywayVersion/flyway-commandline-$flywayVersion-windows-x64.zip"
 
#Insert path for downloaded files
 
$DownloadZipFile = "C:\FlywayCLI\" + $(Split-Path -Path $Url -Leaf)
 
#Assign location for Flyway to extracted to
 
$ExtractPath = "C:\FlywayCLI\"
 
#SilentlyContinue informs PowerShell to download the CLI without a progress bar. This often drastically improves the download time.
 
$ProgressPreference = 'SilentlyContinue'
 
if (Test-Path $ExtractPath) {
   
    Write-Host "Folder Exists"
 
}
else
{
  
    #PowerShell Create directory if not exists
    New-Item $ExtractPath -ItemType Directory
    Write-Host "Folder Created successfully"
}
 
# Download the CLI to the desired location
 
Invoke-WebRequest -Uri $Url -OutFile $DownloadZipFile
 
# Extract the CLI to the desired location
 
$ExtractShell = New-Object -ComObject Shell.Application
 
$ExtractFiles = $ExtractShell.Namespace($DownloadZipFile).Items()
 
$ExtractShell.NameSpace($ExtractPath).CopyHere($ExtractFiles) 
Start-Process $ExtractPath
 
# Update PATH Variable with Flyway CLI - Azure DevOps #
 
# echo "##vso[task.setvariable variable=path]$(PATH);C:\FlywayCLI\flyway-$flywayVersion"
 
# Update PATH variable with Flyway CLI - Generic - Comment above and uncomment below to take affect #
 
[Environment]::SetEnvironmentVariable("PATH", $Env:PATH + ";${ExtractPath}flyway-$flywayVersion", [EnvironmentVariableTarget]::Machine)