# Define the script block to run in each runspace
$scriptBlock = {
    param ($currentJDBC, $baselineVersion, $flywayLicenseKey, $workingDirectory)
    
    $deployment = "flyway migrate -outOfOrder='true' -baselineOnMigrate='true' -errorOverrides='S0001:0:I' -configFiles=$workingDirectory\flyway.toml -locations=filesystem:$workingDirectory\migrations -url='$currentJDBC'"
    Write-Host "flywayCommand: $deployment"
    Write-Host "deploying to: $currentJDBC"
    Invoke-Expression $deployment
}

# Create a runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$runspacePool.Open()

# Create an array to hold the runspaces
$runspaces = @()

# Import the CSV file
$deploymentTargets = Import-Csv -Path $deploymentTargetsList

# Create and start runspaces
foreach ($target in $deploymentTargets) {
    $runspace = [powershell]::Create().AddScript($scriptBlock).AddArgument($target.JDBCString).AddArgument($baselineVersion).AddArgument($flywayLicenseKey).AddArgument($workingDirectory)
    $runspace.RunspacePool = $runspacePool
    $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
}

# Wait for all runspaces to complete
$runspaces | ForEach-Object {
    $_.Pipe.EndInvoke($_.Status)
    $_.Pipe.Dispose()
}

# Close the runspace pool
$runspacePool.Close()
$runspacePool.Dispose()