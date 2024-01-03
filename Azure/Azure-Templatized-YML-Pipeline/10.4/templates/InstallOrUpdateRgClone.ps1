# [CmdletBinding()]
# param (
#     $RgCloneEndpoint
# )

$rgCloneEndpoint = $($env:RGCLONE_API_ENDPOINT)

# DON'T CHANGE ANYTHING ELSE
###############################################################

<# 
For more information, see: 
https://documentation.red-gate.com/redgate-clone/using-the-cli/cli-installation
#>

Write-Output "  "
Write-Output " INSTALLING/UPDATING  AND CONFIGURING rgclone.exe"
Write-Output "  "

$downloadUrl = $rgCloneEndpoint + "cloning-api/download/cli/windows-amd64"
$rgProgramFiles = Join-Path -Path $Env:Programfiles -ChildPath "Red Gate"
$rgCloneLocation = Join-Path -Path $rgProgramFiles -ChildPath "Redgate Clone"
$zipFile = Join-Path -Path $rgCloneLocation -ChildPath "rgclone.zip"
Write-Output "Install parameters:"
Write-Output "  Redgate Clone endpoint is:  $rgCloneEndpoint"
Write-Output "  Download URL is:            $downloadUrl"
Write-Output "  Redgate program files dir:  $rgProgramFiles"
Write-Output "  rgclone.exe install dir is: $rgCloneLocation"
Write-Output "  rgclone.exe zip file is:    $zipFile"
Write-Output "  "

Write-Output "  "
Write-Output "Performing installation:"

If (-not (Test-Path $rgProgramFiles)){
    Write-Output "  Creating a Red Gate directory in Program Files." 
    New-Item -ItemType Directory -Path $rgCloneLocation | Out-Null
}

If (Test-Path $rgCloneLocation){
    Write-Output "  Deleting existing RG Clone directory." 
    Remove-Item $rgCloneLocation -Force -Recurse | Out-Null
}
Write-Output "  Creating a clean RG Clone directory." 
New-Item -ItemType Directory -Path $rgCloneLocation | Out-Null

Write-Output "  Downloading rgclone.exe zip file..."
Write-Output "    from: $downloadUrl"
Write-Output "    to:   $zipFile"
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile

Write-Output "  Extracting zip to: $rgCloneLocation"
Add-Type -assembly "System.IO.Compression.Filesystem";
[IO.Compression.Zipfile]::ExtractToDirectory($zipFile, $rgCloneLocation);

Write-Output "  Configuring rgclone endpoint"
& setx RGCLONE_API_ENDPOINT $rgCloneEndpoint

Write-Output ""
Write-Output "Create demo .bat files"

$authFile = Join-Path -Path $rgCloneLocation -ChildPath "RgCloneAuth.bat"
$authCode = "rgclone auth"

$demoFile = Join-Path -Path $rgCloneLocation -ChildPath "BuildContainer.bat"
$demoCode = @"
rgclone create data-container -i pagila-pg --lifetime 30m
rgclone get all
pause
"@

if (test-path $authFile){
    Write-Output "  Deleting existing RgCloneAuth.bat file." 
    Remove-Item $authFile -Force | Out-Null
}
Write-Output "  Creating a clean RgCloneAuth.bat file." 
New-Item -ItemType File -Path $authFile -Value $authCode -Force | Out-Null

if (test-path $demoFile){
    Write-Output "  Deleting existing BuildContainer.bat file." 
    Remove-Item $demoFile -Force | Out-Null
}
Write-Output "  Creating a clean BuildContainer.bat file." 
New-Item -ItemType File -Path $demoFile -Value $demoCode -Force | Out-Null

Write-Output ""
Write-Output "Updating PATH system variable:"
if ($env:PATH -like "*$rgCloneLocation*"){
    Write-Output "  PATH system variable already includes rgclone location. No need to update it."
}
else {
    Write-Output "  PATH system variable DOES NOT already includes rgclone location."
    Write-Output "  Adding rgclone location to PATH system variable."
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$rgCloneLocation", "Machine")
}

Write-Output ""
Write-Output "INSTALL COMPLETE!"
Write-Output "Your files are saved at:"
Write-Output "  $rgCloneLocation"