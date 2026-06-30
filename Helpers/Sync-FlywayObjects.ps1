<#
.SYNOPSIS
    Syncs database objects from development to schema-model and generates Flyway migrations.

.DESCRIPTION
    This script automates the Flyway workflow for syncing specific database objects or all changes
    from the development database to the schema-model folder, and optionally generates versioned
    migration scripts. It streamlines the process of capturing development changes and creating
    repeatable migration scripts for deployment.

.AUTHOR
    Andrew Pierce
    
.CREATED
    February 2026

.VERSION
    2.0

.PARAMETER Objects
    Array of database objects to sync in "Schema.ObjectName" format (e.g., "Operation.Products").
    Cannot be used with -All parameter.

.PARAMETER All
    Switch to process all detected changes between development and schema-model.
    When used, -model.changes and -generate.changes parameters are omitted from Flyway commands,
    allowing Flyway to sync all differences.

.PARAMETER Mine
    Switch to process only changes made by the current user. Uses SQL Server's default trace
    to identify which objects were modified by your login. Useful in shared development 
    environments where multiple developers are making changes to the same database.
    Note: Only works if the default trace contains recent DDL events for your changes.

.PARAMETER Description
    Custom description for the generated migration script. If not provided, a description is
    auto-generated using format: {branch}_{changeType}_{schema}_{object}_{user}

.PARAMETER SkipGenerate
    Skip the migration script generation step. Only updates the schema-model folder.

.PARAMETER DryRun
    Preview mode - shows what changes would be made without actually modifying files or databases.
    Displays schema-model changes and migration script preview.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Objects "Operation.Products"
    Syncs the Operation.Products table and generates a migration script.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Objects "Operation.Products","Sales.Customers" -Description "Add_New_Columns"
    Syncs multiple objects with a custom migration description.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -All
    Syncs all changes detected between development and schema-model.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -All -DryRun
    Preview all changes without making modifications.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Mine
    Syncs only the changes made by the current user (queries default trace).

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Mine -DryRun
    Preview changes made by the current user without making modifications.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Objects "Operation.Products" -SkipGenerate
    Only updates schema-model, does not generate a migration script.

.NOTES
    Workflow:
    1. Runs 'flyway diff' to compare development database to schema-model
    2. Parses diff output to extract change IDs
    3. Filters for requested objects (if -Objects specified)
    4. Runs 'flyway diff' from development to migrations (with shadow build environment)
    5. Runs 'flyway generate' to create versioned migration script
    6. Runs 'flyway migrate' to apply migrations to shadow
    7. Runs 'flyway diff' from shadow to schema-model
    8. Runs 'flyway model' to update schema-model folder from shadow
    
    This workflow ensures the schema-model reflects what the migrations actually produce,
    rather than just copying from development directly.
    
    Requirements:
    - Flyway Enterprise Edition
    - Access to development and shadow databases
    - Git (for auto-generating descriptions with branch and user info)
    - Environments 'development' and 'shadow' must be defined in flyway.toml
    
    Configuration:
    - Source database: development (fixed - must be defined in flyway.toml)
    - Build environment: shadow (fixed - must be defined in flyway.toml)
    - Schema-model location: ./schema-model (from flyway.toml)
    - Migrations location: ./migrations (from flyway.toml)
    
    The flyway.toml file must contain environment definitions like:
        [environments.development]
        url = "jdbc:sqlserver://..."
        
        [environments.shadow]
        url = "jdbc:sqlserver://..."
        provisioner = "clean"

#>

param(
    [Parameter(Mandatory=$false)]
    [string[]]$Objects,
    [Parameter(Mandatory=$false)]
    [switch]$All,
    [Parameter(Mandatory=$false)]
    [switch]$Mine,
    
    [Parameter(Mandatory=$false)]
    [string]$Description,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipGenerate,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Fixed values for source and target
$Source = "development"
$Target = "shadow"

# Function to parse JDBC URL and get connection info
function Get-ConnectionInfoFromToml {
    param([string]$Environment)
    
    $tomlPath = Join-Path (Get-Location) "flyway.toml"
    if (-not (Test-Path $tomlPath)) {
        return $null
    }
    
    $tomlContent = Get-Content $tomlPath -Raw
    
    # Find the environment section and extract URL
    if ($tomlContent -match "\[environments\.$Environment\][\s\S]*?url\s*=\s*`"([^`"]+)`"") {
        $jdbcUrl = $matches[1]
        
        # Parse JDBC URL: jdbc:sqlserver://SERVER\INSTANCE;databaseName=DB;...
        $result = @{}
        
        if ($jdbcUrl -match "jdbc:sqlserver://([^;]+)") {
            $serverPart = $matches[1]
            # Handle escaped backslash for instance name
            $result.Server = $serverPart -replace '\\\\', '\'
        }
        
        if ($jdbcUrl -match "databaseName=([^;]+)") {
            $result.Database = $matches[1]
        }
        
        if ($result.Server -and $result.Database) {
            return $result
        }
    }
    return $null
}

# Function to query default trace for DDL changes
function Get-DDLChangesFromTrace {
    param(
        [string]$Server,
        [string]$Database
    )
    
    $query = @"
DECLARE @tracepath nvarchar(260)
SELECT @tracepath = path FROM sys.traces WHERE is_default = 1

IF @tracepath IS NOT NULL
BEGIN
    SELECT 
        COALESCE(s.name, 'unknown') AS SchemaName,
        t.ObjectName,
        t.LoginName,
        t.StartTime,
        CASE t.EventClass 
            WHEN 46 THEN 'CREATE'
            WHEN 47 THEN 'DROP'
            WHEN 164 THEN 'ALTER'
            ELSE 'OTHER'
        END AS EventType
    FROM fn_trace_gettable(@tracepath, DEFAULT) t
    LEFT JOIN sys.objects o ON o.object_id = t.ObjectID
    LEFT JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE t.EventClass IN (46, 47, 164)
        AND t.DatabaseName = DB_NAME()
        AND t.ObjectName IS NOT NULL
    ORDER BY t.StartTime DESC
END
"@
    
    try {
        # Use SqlClient directly for maximum compatibility
        $connectionString = "Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Encrypt=True"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $command.CommandTimeout = 30
        
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        
        $connection.Close()
        
        return $dataset.Tables[0]
    }
    catch {
        Write-Host "  Note: Could not query default trace for change authors: $($_.Exception.Message)" -ForegroundColor Gray
        return $null
    }
}

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Flyway Object Sync Tool" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Validate parameter combinations
if (-not $All -and -not $Mine) {
    if (-not $Objects -or $Objects.Count -eq 0) {
        Write-Error "Specify -Objects, -All, or -Mine to process changes"
        exit 1
    }

    foreach ($obj in $Objects) {
        if ($obj -notmatch '^\w+\.[\w\s]+$') {
            Write-Error "Invalid object format: $obj. Expected format: Schema.ObjectName"
            exit 1
        }
    }
}

# If -Mine is specified, we'll determine objects after querying the trace
$currentUserLogin = $null
if ($Mine) {
    # Get current Windows user in domain\user format
    $currentUserLogin = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Filtering for changes by: $currentUserLogin" -ForegroundColor Cyan
}

Write-Host "Objects to sync:" -ForegroundColor Yellow
if ($All) {
    Write-Host "  - ALL changes (processing every change found in diff)" -ForegroundColor Gray
} elseif ($Mine) {
    Write-Host "  - Changes made by current user (will be determined from default trace)" -ForegroundColor Gray
} else {
    $Objects | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}
Write-Host ""

# Step 1: Run flyway diff (development to schemaModel to find what needs to be synced)
Write-Host "Step 1: Running flyway diff..." -ForegroundColor Green
$diffCommand = "flyway diff -source=development -target=schemaModel"
$diffOutput = Invoke-Expression $diffCommand 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flyway diff failed. Output:`n$diffOutput"
    exit 1
}

Write-Host $diffOutput
Write-Host ""

# Step 2: Parse diff output to extract change IDs
Write-Host "Step 2: Parsing diff output..." -ForegroundColor Green

# Extract the table from diff output
$lines = $diffOutput -split "`n"
$tableStarted = $false
$changes = @()

foreach ($line in $lines) {
    # Detect table start
    if ($line -match '^\+[-+]+\+' -or $line -match '^\| Id\s+\|') {
        $tableStarted = $true
        continue
    }
    
    # Skip separator lines and empty lines
    if ($line -match '^\+[-+]+\+' -or $line -match '^\s*$') {
        continue
    }
    
    # Parse data lines
    if ($tableStarted -and $line -match '^\|\s*(\S+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*([^|]+)\s*\|') {
        $changeId = $matches[1].Trim()
        $changeType = $matches[2].Trim()
        $objectType = $matches[3].Trim()
        $schema = $matches[4].Trim()
        $objectName = $matches[5].Trim()
        
        # Skip header and "No differences found" messages
        if ($changeId -eq "Id" -or $changeId -match "^No") {
            continue
        }
        
        $changes += [PSCustomObject]@{
            ChangeId = $changeId
            ChangeType = $changeType
            ObjectType = $objectType
            Schema = $schema
            ObjectName = $objectName
            FullName = "$schema.$objectName"
        }
    }
}

if ($changes.Count -eq 0) {
    Write-Host "No differences found between $Source and $Target" -ForegroundColor Yellow
    exit 0
}

# Query default trace for change authors (required for -Mine, optional for -DryRun)
$traceData = $null
if ($Mine -or $DryRun) {
    $connInfo = Get-ConnectionInfoFromToml -Environment $Source
    if ($connInfo) {
        Write-Host "  Querying default trace for change authors..." -ForegroundColor Gray
        $traceData = Get-DDLChangesFromTrace -Server $connInfo.Server -Database $connInfo.Database
        if (-not $traceData -or $traceData.Rows.Count -eq 0) {
            Write-Host "  (No recent DDL events found in default trace)" -ForegroundColor Gray
            if ($Mine) {
                Write-Error "Cannot use -Mine: No DDL events found in default trace. The trace may have rolled over."
                exit 1
            }
        }
    } elseif ($Mine) {
        Write-Error "Cannot use -Mine: Could not parse connection info from flyway.toml"
        exit 1
    }
}

# Add ModifiedBy property to changes if trace data available
if ($traceData) {
    foreach ($change in $changes) {
        # Find the most recent trace entry for this object
        $traceEntry = $traceData | Where-Object { 
            $_.ObjectName -eq $change.ObjectName -or 
            $_.ObjectName -eq "$($change.Schema).$($change.ObjectName)"
        } | Select-Object -First 1
        
        if ($traceEntry) {
            $change | Add-Member -NotePropertyName "ModifiedBy" -NotePropertyValue $traceEntry.LoginName -Force
            $change | Add-Member -NotePropertyName "ModifiedAt" -NotePropertyValue $traceEntry.StartTime -Force
        } else {
            $change | Add-Member -NotePropertyName "ModifiedBy" -NotePropertyValue $null -Force
            $change | Add-Member -NotePropertyName "ModifiedAt" -NotePropertyValue $null -Force
        }
    }
}

Write-Host "Found $($changes.Count) changes:" -ForegroundColor Yellow
$changes | ForEach-Object {
    $authorInfo = ""
    if ($_.ModifiedBy) {
        $timeStr = if ($_.ModifiedAt) { " at $($_.ModifiedAt.ToString('yyyy-MM-dd HH:mm'))" } else { "" }
        $authorInfo = " (by $($_.ModifiedBy)$timeStr)"
    }
    Write-Host "  - $($_.FullName) [$($_.ObjectType)] - $($_.ChangeType)$authorInfo" -ForegroundColor Gray
}
Write-Host ""

# Step 3: Filter changes based on requested objects
Write-Host "Step 3: Filtering for requested objects..." -ForegroundColor Green

$matchedChanges = @()
if ($All) {
    $matchedChanges = $changes
    if ($matchedChanges.Count -eq 0) {
        Write-Host "No differences found between $Source and $Target" -ForegroundColor Yellow
        exit 0
    }
    Write-Host "  ✓ Processing all $($matchedChanges.Count) change(s)" -ForegroundColor Green
} elseif ($Mine) {
    # Filter to only changes made by the current user
    foreach ($change in $changes) {
        if ($change.ModifiedBy -and $change.ModifiedBy -eq $currentUserLogin) {
            $matchedChanges += $change
            Write-Host "  ✓ Your change: $($change.FullName)" -ForegroundColor Green
        } else {
            $otherUser = if ($change.ModifiedBy) { $change.ModifiedBy } else { "unknown" }
            Write-Host "  ✗ Skipping: $($change.FullName) (by $otherUser)" -ForegroundColor Gray
        }
    }

    if ($matchedChanges.Count -eq 0) {
        Write-Host "No changes found that were made by $currentUserLogin" -ForegroundColor Yellow
        Write-Host "Note: The default trace may have rolled over, or your changes predate the trace window." -ForegroundColor Gray
        exit 0
    }
} else {
    foreach ($obj in $Objects) {
        $matched = $changes | Where-Object { $_.FullName -eq $obj }
        
        if ($matched) {
            $matchedChanges += $matched
            Write-Host "  ✓ Matched: $obj" -ForegroundColor Green
        } else {
            Write-Warning "  ✗ No match found for: $obj"
        }
    }

    if ($matchedChanges.Count -eq 0) {
        Write-Error "No changes found for the specified objects"
        exit 1
    }
}

Write-Host ""
Write-Host "Objects to process:" -ForegroundColor Yellow
$matchedChanges | ForEach-Object {
    $authorInfo = ""
    if ($_.ModifiedBy) {
        $authorInfo = " (by $($_.ModifiedBy))"
    }
    Write-Host "  - $($_.FullName) [$($_.ChangeId)]$authorInfo" -ForegroundColor Gray
}
Write-Host ""

# Build comma-separated list of change IDs
$changeIds = ($matchedChanges | ForEach-Object { $_.ChangeId }) -join ','

# Generate description if not provided
if (-not $Description) {
    Write-Host "Generating migration description..." -ForegroundColor Gray
    
    # Get git branch name
    $branchName = git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        $branchName = "unknown-branch"
    }
    
    # Get git user name
    $userName = git config user.name 2>$null
    if ($LASTEXITCODE -ne 0) {
        $userName = $env:USERNAME
    }
    
    # Build object summary
    $objectSummary = ($matchedChanges | ForEach-Object {
        "$($_.ChangeType)_$($_.Schema)_$($_.ObjectName)"
    }) -join "_"
    
    # Format: BranchName_Operation_Object(s)_UserName
    $Description = "$branchName" + "_" + "$objectSummary" + "_" + "$userName"
    
    # Replace spaces and periods with underscores
    $Description = $Description -replace '[\s\.]', '_'
    
    Write-Host "  Description: $Description" -ForegroundColor Gray
    Write-Host ""
}

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
    
    # Show what would be updated in schema model
    Write-Host "Schema Model Changes Preview:" -ForegroundColor Cyan
    Write-Host "-----------------------------" -ForegroundColor Cyan
    
    # Use -diffText.changes to filter output to only the specified objects
    if ($All) {
        $diffTextCommand = "flyway diffText `"-diff.source=development`" `"-diff.target=schemaModel`""
    } else {
        $diffTextCommand = "flyway diffText `"-diff.source=development`" `"-diff.target=schemaModel`" `"-diffText.changes=$changeIds`""
    }
    $diffTextOutput = Invoke-Expression $diffTextCommand 2>&1 | Out-String
    
    if ($diffTextOutput -and $diffTextOutput.Trim()) {
        Write-Host $diffTextOutput
    } else {
        Write-Host "No schema model changes detected for selected objects" -ForegroundColor Gray
    }
    Write-Host ""
    
    if (-not $SkipGenerate) {
        # Run diff from development to target for generate preview
        Write-Host "Migration Script Preview:" -ForegroundColor Cyan
        Write-Host "-------------------------" -ForegroundColor Cyan
        
        # Run diff from development to target (shadow) to get correct change IDs for generate
        Write-Host "  Running diff from development to $Target..." -ForegroundColor Gray
        $genDiffCommand = "flyway diff `"-diff.source=development`" `"-diff.target=$Target`""
        $genDiffOutput = Invoke-Expression $genDiffCommand 2>&1 | Out-String

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "flyway diff (development -> $Target) failed with exit code $LASTEXITCODE"
            Write-Host $genDiffOutput
            Write-Host "Skipping generate preview due to diff error" -ForegroundColor Yellow
        } else {
            # Parse the diff output to get change IDs for matched objects
            $genDiffLines = $genDiffOutput -split "`n"
            $genChanges = @()
            $genTableStarted = $false

            foreach ($line in $genDiffLines) {
                if ($line -match '^\+[-+]+\+' -or $line -match '^\| Id\s+\|') {
                    $genTableStarted = $true
                    continue
                }
                if ($line -match '^\+[-+]+\+' -or $line -match '^\s*$') {
                    continue
                }
                if ($genTableStarted -and $line -match '^\|\s*(\S+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*([^|]+)\s*\|') {
                    $gChangeId = $matches[1].Trim()
                    $gSchema = $matches[4].Trim()
                    $gObjectName = $matches[5].Trim()
                    if ($gChangeId -ne "Id" -and $gChangeId -notmatch "^No") {
                        $genChanges += [PSCustomObject]@{
                            ChangeId = $gChangeId
                            FullName = "$gSchema.$gObjectName"
                        }
                    }
                }
            }

            # Match the objects from the original list to get correct change IDs
            $genChangeIds = @()
            foreach ($obj in $matchedChanges) {
                $matched = $genChanges | Where-Object { $_.FullName -eq $obj.FullName }
                if ($matched) {
                    $genChangeIds += $matched.ChangeId
                }
            }
            $genChangeIdList = $genChangeIds -join ','

            $tempMigrationDir = Join-Path $env:TEMP "flyway-dryrun-$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempMigrationDir -Force | Out-Null

            # Generate to temp location
            if ($All -or $genChangeIds.Count -eq 0) {
                $generateCommand = "flyway generate `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.location=$tempMigrationDir`" `"-generate.description=$Description`""
            } else {
                $generateCommand = "flyway generate `"-generate.changes=$genChangeIdList`" `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.location=$tempMigrationDir`" `"-generate.description=$Description`""
            }
            $genOutput = Invoke-Expression $generateCommand 2>&1 | Out-String

            # Find and display the generated file
            $generatedFiles = Get-ChildItem -Path $tempMigrationDir -Filter "*.sql"
            if ($generatedFiles) {
                foreach ($file in $generatedFiles) {
                    Write-Host "--- $($file.Name) ---" -ForegroundColor Green
                    Get-Content $file.FullName | ForEach-Object { Write-Host $_ }
                }
            } else {
                Write-Host "No migration script generated" -ForegroundColor Gray
            }
            
            # Clean up temp directory
            Remove-Item -Path $tempMigrationDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    exit 0
}

# Step 4: Generate migration script (if not skipped)
if (-not $SkipGenerate) {
    Write-Host "Step 4: Generating migration script..." -ForegroundColor Green
    
    # Run diff from development with build environment
    Write-Host "  Running diff from development with build environment..." -ForegroundColor Gray
    $genDiffCommand = "flyway diff `"-diff.source=development`" `"-diff.target=migrations`" `"-diff.buildEnvironment=$Target`""
    $genDiffOutput = Invoke-Expression $genDiffCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "flyway diff (development -> migrations) failed. Output:`n$genDiffOutput"
        exit 1
    }

    if ($All) {
        $generateCommand = "flyway generate `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.description=$Description`""
    } else {
        $generateCommand = "flyway generate `"-generate.changes=$changeIds`" `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.description=$Description`""
    }
    Write-Host "Executing: $generateCommand" -ForegroundColor Gray

    $generateOutput = Invoke-Expression $generateCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flyway generate failed. Output:`n$generateOutput"
        exit 1
    }

    Write-Host $generateOutput
    
    # Extract generated file path
    if ($generateOutput -match 'Generated:\s+(.+\.sql)') {
        $generatedFile = $matches[1].Trim()
        Write-Host "✓ Migration generated: $generatedFile" -ForegroundColor Green
    } else {
        Write-Host "✓ Migration generated successfully" -ForegroundColor Green
    }
    Write-Host ""

    # Step 5: Migrate to shadow
    Write-Host "Step 5: Migrating to $Target..." -ForegroundColor Green
    $migrateCommand = "flyway migrate `"-environment=$Target`""
    Write-Host "Executing: $migrateCommand" -ForegroundColor Gray

    $migrateOutput = Invoke-Expression $migrateCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flyway migrate failed. Output:`n$migrateOutput"
        exit 1
    }

    Write-Host $migrateOutput
    Write-Host "✓ Migration applied to $Target successfully" -ForegroundColor Green
    Write-Host ""

    # Step 6: Update schema model from shadow
    Write-Host "Step 6: Updating schema model from $Target..." -ForegroundColor Green
    
    # Run diff from shadow to schemaModel
    Write-Host "  Running diff from $Target to schemaModel..." -ForegroundColor Gray
    $modelDiffCommand = "flyway diff `"-diff.source=$Target`" `"-diff.target=schemaModel`""
    $modelDiffOutput = Invoke-Expression $modelDiffCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "flyway diff ($Target -> schemaModel) failed. Output:`n$modelDiffOutput"
        exit 1
    }

    if ($All) {
        $modelCommand = "flyway model `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`""
    } else {
        $modelCommand = "flyway model `"-model.changes=$changeIds`" `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`""
    }
    Write-Host "Executing: $modelCommand" -ForegroundColor Gray

    $modelOutput = Invoke-Expression $modelCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flyway model failed. Output:`n$modelOutput"
        exit 1
    }

    Write-Host $modelOutput
    Write-Host "✓ Schema model updated successfully" -ForegroundColor Green
    Write-Host ""
} else {
    # If skipping generate, just update schema model from development
    Write-Host "Step 4: Skipping migration generation" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Step 5: Updating schema model from development..." -ForegroundColor Green

    if ($All) {
        $modelCommand = "flyway model `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`""
    } else {
        $modelCommand = "flyway model `"-model.changes=$changeIds`" `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`""
    }
    Write-Host "Executing: $modelCommand" -ForegroundColor Gray

    $modelOutput = Invoke-Expression $modelCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flyway model failed. Output:`n$modelOutput"
        exit 1
    }

    Write-Host $modelOutput
    Write-Host "✓ Schema model updated successfully" -ForegroundColor Green
    Write-Host ""
}

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Sync Complete!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Objects processed: $($matchedChanges.Count)" -ForegroundColor Gray
$matchedChanges | ForEach-Object {
    Write-Host "    - $($_.FullName)" -ForegroundColor Gray
}
Write-Host ""
