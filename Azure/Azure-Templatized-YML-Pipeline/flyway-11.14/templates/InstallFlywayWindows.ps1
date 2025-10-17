$ErrorActionPreference = "Stop"

#Flyway Version to Use - Check here for latest version information - https://documentation.red-gate.com/fd/command-line-184127404.html
 
$flywayVersion = '10.17.3'
 
#Flyway URL to download CLI
 
$Url = "https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline/$flywayVersion/flyway-commandline-$flywayVersion-windows-x64.zip"
 
#Insert path for downloaded files
 
$DownloadZipFile = "C:\FlywayCLI\" + $(Split-Path -Path $Url -Leaf)
 
#Assign location for Flyway to extracted to
 
$ExtractPath = "C:\FlywayCLI\"

if (Test-Path $ExtractPath) {
   
    Write-Host "Folder Exists"
    Exit
}
else
{
    #PowerShell Create directory if not exists
    New-Item $ExtractPath -ItemType Directory
    Write-Host "Folder Created successfully"
}

#SilentlyContinue informs PowerShell to download the CLI without a progress bar. This often drastically improves the download time.
 
$ProgressPreference = 'SilentlyContinue'

#TODO - pass in param to update CLI to specific version

if (Get-Command flyway) {
    
    Write-Host "Flyway Installed"

    # Execute Flyway to get the version information
    try {
        $versionOutput = & flyway -v 2>&1
    } catch {
        Write-Output "Failed to execute Flyway. Error: $_"
        exit 1
    }

    $a = & "flyway" --version  2>&1 | select-string 'Edition'
    $b = $a -split(' ')
    if ($b[3] -eq $flywayVersion){ 
        Write-Output("$($b) installed")
        Exit
    }
    else {
        # Download the CLI to the desired location

        Invoke-WebRequest -Uri $Url -OutFile $DownloadZipFile
        
        # Extract the CLI to the desired location
        
        # $ExtractShell = New-Object -ComObject Shell.Application
        
        # $ExtractFiles = $ExtractShell.Namespace($DownloadZipFile).Items()
        
        # $ExtractShell.NameSpace($ExtractPath).CopyHere($ExtractFiles) 
        # Start-Process $ExtractPath

        Expand-Archive -Path $DownloadZipFile -DestinationPath $ExtractPath
        
        # Update PATH Variable with Flyway CLI - Azure DevOps #
        
        $Env:Path += ";C:\FlywayCLI\flyway-$flywayVersion"
        $Env:Path

        "flyway -v" | cmd.exe
        Exit
    }

}
