# Flyway AI Context Guide

This document provides context for AI assistants to understand and work with Flyway in this project.

## Project Overview

- **Project Name**: Autopilot - FastTrack
- **Database Type**: SQL Server
- **Config File**: `flyway.toml`
- **Schema Model Location**: `./schema-model`
- **Migrations Location**: `./migrations`

## Environments

| Environment | Database Name | Purpose | Provisioner |
|-------------|---------------|---------|-------------|
| `development` | AutopilotDev | Development database - source of truth for changes | - |
| `shadow` | AutopilotShadow | Shadow database for building/validating migrations | clean |
| `schemaModel` | (folder) | File-based representation of database schema | - |
| `migrations` | (folder) | Contains versioned migration SQL scripts | - |
| `Prod` | AutopilotProd | Production database | - |
| `Test` | AutopilotTest | Test database | - |
| `Check` | AutopilotCheck | Reporting/check database | clean |
| `Build` | AutopilotBuild | Build database | clean |

**Server**: `US-LT-ANDREWP\MSSQLSERVER01` (all databases)

**Provisioner types**:
- `clean` - Database is automatically cleaned before operations like `check`. Use `-cleanDisabled=false` for manual clean.
- `create-database` - Database is created if it doesn't exist
- `backup` - Restores database from a backup file (.bak for SQL Server, .dmp for Oracle). Enterprise feature.
- `snapshot` - Provisions from a Flyway snapshot file
- `docker` - Provisions using Docker containers
- `redgate-clone` - Uses Redgate Clone for provisioning
- (none) - No automatic provisioning; manual management required

### Backup Provisioner (Enterprise)

Restores a database from a backup file. Benefits:
- Can include static data and `flyway_schema_history` table
- Not impacted by invalid object references (better than baseline scripts)
- Faster than running many migrations (restore to version 1000 vs running 1000 scripts)

**SQL Server Configuration**:
```toml
[environments.shadow]
url = "jdbc:sqlserver://localhost:1433;databaseName=MyDatabase;trustServerCertificate=true"
user = "MyUser"
password = "${localSecret.MyPasswordKey}"
provisioner = "backup"

[environments.shadow.resolvers.backup]
backupFilePath = '\\DBOps1\Backups\backup.bak'  # Path accessible to DB server
backupVersion = "995"                            # Version the backup represents
```

**Key Parameters**:
- `backupFilePath` (Required) - Path to backup file (must be accessible to DB server)
- `backupVersion` (Optional) - The last Flyway versioned script applied to the provided backup file. Required if backup has no `flyway_schema_history` table. When restoring, Flyway will baseline at this version, then apply any subsequent migrations.
- `sqlserver.generateWithMove` - Auto-generate data/log file paths (default: true)
- `sqlserver.files` - Specify exact file paths for data/log files

**Prerequisites** (SQL Server):
- User needs `dbcreator`, `##MS_DatabaseManager##`, or `sysadmin` role
- Backup file must be accessible to the database server

## Key Flyway Commands

### CLI Reference (`flyway --help`)

```
Usage
    flyway [options] [command]
    flyway help [command]

By default, the configuration will be read from conf/flyway.toml file.
Options passed from the command-line override the configuration.

Commands
    help                     Print this usage info and exit
    auth                     Authenticates Flyway with Redgate licensing
    migrate                  Migrates the database
    clean                    Drops all objects in the configured schemas
    info                     Prints the information about applied, current and pending migrations
    validate                 Validates the applied migrations against the ones on the classpath
    baseline                 Baselines an existing database at the baselineVersion
    repair                   Repairs the schema history table
    check                    Produces reports to increase confidence in your deployments
    testConnection           Attempts to establish a connection to the database using the configured connection settings
    version, -v, --version   Print the Flyway version and edition
    list-engines             Lists the database engines that Flyway has loaded support for.
    diff                     Compares two comparison sources and returns a summary of the differences
    diffText                 Shows the object differences for changes computed by flyway diff
    snapshot                 [enterprise] Produces a snapshot of the database specified in flyway.url
                             A snapshot can be generated from a database environment, build environment,
                             schema model folder or empty source using the snapshot.source argument
    model                    Applies the changes from flyway diff to the schema model
    generate                 Generates a migration script based on the changes from flyway diff
    add                      Creates a new empty migration script
    undo                     [teams] Undoes the most recently applied versioned migration
    deploy                   Deploys an individual script to an environment
    prepare                  Writes a deployment script from a schemaModel, an environment, a diff artifact, or migrations to disk
    init                     Initialize a new Flyway project. Also allows for the upgrading of Flyway .conf files,
                             and the porting of SQL Source Control and Source Control for Oracle projects to Flyway.

Configuration parameters (Format: -key=value)
    driver                         Fully qualified classname of the JDBC driver
    url                            Jdbc url to use to connect to the database
    user                           User to use to connect to the database
    password                       Password to use to connect to the database
    connectRetries                 Maximum number of retries when attempting to connect to the database
    initSql                        SQL statements to run to initialize a new database connection
    schemas                        Comma-separated list of the schemas managed by Flyway
    table                          Name of Flyway's schema history table
    locations                      Classpath locations to scan recursively for migrations
    failOnMissingLocations         Whether to fail if a location specified in the flyway.locations option doesn't exist
    resolvers                      Comma-separated list of custom MigrationResolvers
    skipDefaultResolvers           Skips default resolvers (jdbc, sql and Spring-jdbc)
    sqlMigrationPrefix             File name prefix for versioned SQL migrations
    undoSqlMigrationPrefix         [teams] File name prefix for undo SQL migrations
    repeatableSqlMigrationPrefix   File name prefix for repeatable SQL migrations
    sqlMigrationSeparator          File name separator for SQL migrations
    sqlMigrationSuffixes           Comma-separated list of file name suffixes for SQL migrations
    stream                         [teams] Stream SQL migrations when executing them
    batch                          [teams] Batch SQL statements when executing them
    mixed                          Allow mixing transactional and non-transactional statements
    encoding                       Encoding of SQL migrations
    detectEncoding                 [teams] Whether Flyway should try to automatically detect SQL migration file encoding
    executeInTransaction           Whether SQL should execute within a transaction
    placeholderReplacement         Whether placeholders should be replaced
    placeholders                   Placeholders to replace in sql migrations
    placeholderPrefix              Prefix of every placeholder
    placeholderSuffix              Suffix of every placeholder
    scriptPlaceholderPrefix        Prefix of every script placeholder
    scriptPlaceholderSuffix        Suffix of every script placeholder
    lockRetryCount                 The maximum number of retries when trying to obtain a lock
    jdbcProperties                 Properties to pass to the JDBC driver object
    installedBy                    Username that will be recorded in the schema history table
    target                         Target version up to which Flyway should use migrations
    cherryPick                     [teams] Comma separated list of migrations that Flyway should consider when migrating
    skipExecutingMigrations        Whether Flyway should skip actually executing the contents of the migrations
    outOfOrder                     Allows migrations to be run "out of order"
    callbacks                      Comma-separated list of FlywayCallback classes, or locations to scan for FlywayCallback classes
    skipDefaultCallbacks           Skips default callbacks (sql)
    validateOnMigrate              Validate when running migrate
    validateMigrationNaming        Validate file names of SQL migrations (including callbacks)
    ignoreMigrationPatterns        Patterns of migrations and states to ignore during validate
    cleanDisabled                  Whether to disable clean
    baselineVersion                Version to tag schema with when executing baseline
    baselineDescription            Description to tag schema with when executing baseline
    baselineOnMigrate              Baseline on migrate against uninitialized non-empty schema
    configFiles                    Comma-separated list of config files to use
    configFileEncoding             Encoding to use when loading the config files
    jarDirs                        Comma-separated list of dirs for Jdbc drivers & Java migrations
    createSchemas                  Whether Flyway should attempt to create the schemas specified in the schemas property
    dryRunOutput                   [teams] File where to output the SQL statements of a migration dry run
    errorOverrides                 [teams] Rules to override specific SQL states and errors codes
    color                          Whether to colorize output. Values: always, never, or auto (default)
    outputFile                     Send output to the specified file alongside the console
    outputType                     Serialise the output in the given format, Values: json

Flags
    -X                Print debug output
    -q                Suppress all output, except for errors and warnings
    --help, -h, -?    Print this usage info and exit

Flyway Usage Example
    flyway -user=myuser -password=s3cr3t -url=jdbc:h2:mem -placeholders.abc=def migrate
    flyway help check

More info at https://rd.gt/3Cc1xKC
```

### flyway diff
Compares two sources and identifies differences.

```powershell
# Compare development database to schema-model folder
flyway diff "-diff.source=development" "-diff.target=schemaModel"

# Compare development to migrations (for generating scripts)
flyway diff "-diff.source=development" "-diff.target=migrations" "-diff.buildEnvironment=shadow"

# Compare schema-model to migrations
flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
```

**Output Format**:
```
+-----------------------------+--------+-------------+-----------+----------+
| Id                          | Change | Object Type | Schema    | Name     |
+-----------------------------+--------+-------------+-----------+----------+
| 1nMIZkukADLTk5oFjPZPesZjqvQ | Edit   | Table       | Operation | Products |
+-----------------------------+--------+-------------+-----------+----------+
```

- **Id**: Hash identifier for the change (used with `-model.changes` and `-generate.changes`)
- **Change**: `Add`, `Edit`, `Delete`
- **Object Type**: `Table`, `View`, `Stored Procedure`, `Function`, etc.
- **Schema**: Database schema name
- **Name**: Object name

### flyway diffText
Shows detailed text diff of changes.

```powershell
flyway diffText "-diff.source=development" "-diff.target=schemaModel"
```

### flyway model
Updates the schema-model folder with changes from the diff.

```powershell
# Apply specific changes (comma-separated change IDs)
flyway model "-model.changes=id1,id2,id3" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false"

# Apply ALL changes (omit -model.changes parameter)
flyway model "-redgateCompare.sqlserver.options.behavior.includeDependencies=false"
```

### flyway generate
Creates a versioned migration SQL script from the diff.

```powershell
# Generate for specific changes
flyway generate "-generate.changes=id1,id2,id3" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false" "-generate.description=MyDescription"

# Generate for ALL changes (omit -generate.changes parameter)
flyway generate "-redgateCompare.sqlserver.options.behavior.includeDependencies=false" "-generate.description=MyDescription"

# Generate to custom location
flyway generate "-generate.changes=id1" "-generate.location=C:\temp\migrations" "-generate.description=MyDescription"
```

**Generated file naming**: `V{version}__{description}.sql` (e.g., `V008__Add_Column_to_Products.sql`)

### flyway migrate
Applies pending migrations to a target database.

```powershell
flyway migrate -environment=Test
flyway migrate -environment=Prod

# Migrate to a specific version
flyway migrate -environment=Test "-target=005"
```

**Output includes**:
- Schema creation (if needed)
- Schema history table creation (if needed)
- Each migration applied with object-level details (Creating tables, indexes, constraints, etc.)
- Final summary: "Successfully applied N migrations to schema [X], now at version vNNN"

### flyway info
Shows migration status and history.

```powershell
flyway info -environment=development
```

**Output Format**:
```
+-----------+---------+-------------+--------------+---------------------+----------+----------+
| Category  | Version | Description | Type         | Installed On        | State    | Undoable |
+-----------+---------+-------------+--------------+---------------------+----------+----------+
|           |         | << Flyway Schema Creation >>  | SCHEMA       | 2026-02-21 11:41:14 | Success  |          |
| Baseline  | 001     | baseline    | SQL_BASELINE | 2026-02-21 11:41:14 | Baseline | No       |
| Versioned | 002     | Welcome     | SQL          | 2026-02-21 11:41:14 | Success  | Yes      |
| Versioned | 003     |             | SQL          |                     | Pending  | No       |
+-----------+---------+-------------+--------------+---------------------+----------+----------+
```

**State values**:
- `Pending` - Migration not yet applied
- `Success` - Migration applied successfully
- `Baseline` - Baseline migration marker
- `Future` - Migration was applied but script file no longer exists
- `Failed` - Migration failed (requires repair)

### flyway clean
Drops all objects in the database (use with caution).

```powershell
# Basic clean (may fail if cleanDisabled is set in config)
flyway clean -environment=shadow

# Override cleanDisabled setting (required in this project)
flyway clean -environment=shadow "-cleanDisabled=false"
```

**Note**: The `flyway.toml` has `cleanDisabled` enabled by default for safety. Use `-cleanDisabled=false` to override when you need to run clean directly. Environments with `provisioner = "clean"` (shadow, Check, Build) are automatically cleaned during `check` operations.

### flyway validate
Validates applied migrations against the ones on the classpath.

```powershell
flyway validate -environment=development

# Ignore pending migrations
flyway validate -environment=development "-ignoreMigrationPatterns=*:pending"
```

### flyway testConnection
Tests database connectivity.

```powershell
flyway testConnection -environment=development
```

### flyway snapshot
Creates a snapshot of a database state (Enterprise feature).

```powershell
# Snapshot from database
flyway snapshot "-snapshot.source=development" "-snapshot.filename=my_snapshot.snp"

# Snapshot from schema model
flyway snapshot "-snapshot.source=schemaModel" "-snapshot.filename=model_snapshot.snp"
```

### flyway prepare
Generates a deployment script without applying it.

```powershell
# From schema model to a database
flyway prepare "-prepare.source=schemaModel" "-prepare.target=development" "-prepare.scriptFilename=deploy.sql"

# From migrations to a database
flyway prepare "-prepare.source=migrations" "-prepare.target=Test" "-prepare.scriptFilename=deploy.sql"
```

### flyway deploy
Executes a deployment script against an environment.

```powershell
# Deploy a prepared script
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=production

# Deploy with snapshot saving (for drift detection)
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=production "-deploy.saveSnapshot=true"
```

### flyway add
Creates a new empty migration script.

```powershell
# Create versioned migration
flyway add "-add.description=AddNewTable" "-add.type=versioned"

# Create undo migration
flyway add "-add.description=AddNewTable" "-add.type=undo"

# Create repeatable migration
flyway add "-add.description=RefreshView" "-add.type=repeatable"
```

### flyway check
Produces reports to validate deployments (Enterprise feature).

```powershell
# Check for changes between migrations and target
flyway check "-changes" "-environment=development" "-check.buildEnvironment=shadow"

# Run drift check
flyway check "-drift" "-environment=production" "-check.deployedSnapshot=prod_snapshot.snp"

# Check with code analysis
flyway check "-code" "-environment=development"
```

### flyway undo
Undoes the most recently applied versioned migration (Teams/Enterprise).

```powershell
flyway undo -environment=Test
```

### flyway baseline
Baselines an existing database at a specific version.

```powershell
flyway baseline -environment=production "-baselineVersion=5" "-baselineDescription=Initial baseline"
```

### flyway repair
Repairs the schema history table (removes failed migrations, realigns checksums).

```powershell
flyway repair -environment=development
```

## Typical Workflow

### 1. Developer Makes Changes in Development Database
Changes are made directly in `AutopilotDev` database.

### 2. Compare Development to Schema Model
```powershell
flyway diff "-diff.source=development" "-diff.target=schemaModel"
```
This shows what's different between the database and the versioned schema files.

### 3. Update Schema Model
```powershell
# Specific objects
flyway model "-model.changes=changeId1,changeId2"

# Or all changes
flyway model
```
This updates the files in `./schema-model` to match development.

### 4. Generate Migration Script
```powershell
flyway diff "-diff.source=development" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
flyway generate "-generate.description=Add_Column_to_Products"
```
This creates a new `V###__description.sql` file in `./migrations`.

### 5. Apply to Other Environments
```powershell
flyway migrate -environment=Test
flyway migrate -environment=Prod
```

## Sync-FlywayObjects.ps1 Script

A helper script that automates steps 2-4 above.

### Usage

```powershell
# Sync specific objects
.\Scripts\Sync-FlywayObjects.ps1 -Objects "Operation.Products","Sales.Customers"

# Sync ALL changes
.\Scripts\Sync-FlywayObjects.ps1 -All

# Dry run (preview without making changes)
.\Scripts\Sync-FlywayObjects.ps1 -Objects "Operation.Products" -DryRun
.\Scripts\Sync-FlywayObjects.ps1 -All -DryRun

# Custom description
.\Scripts\Sync-FlywayObjects.ps1 -Objects "Operation.Products" -Description "Add_Colour_Column"

# Skip migration generation (only update schema model)
.\Scripts\Sync-FlywayObjects.ps1 -Objects "Operation.Products" -SkipGenerate
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Objects` | string[] | Array of object names in `Schema.ObjectName` format |
| `-All` | switch | Process all detected changes |
| `-Description` | string | Custom migration description (auto-generated if not provided) |
| `-SkipGenerate` | switch | Only update schema model, don't generate migration |
| `-DryRun` | switch | Preview changes without applying them |

### Auto-Generated Description Format
`{branchName}_{ChangeType}_{Schema}_{ObjectName}_{userName}`

Example: `main_Edit_Operation_Products_turimbar1`

## Schema Model Structure

```
schema-model/
├── RedGateDatabaseInfo.xml
├── Data/                          # Static data scripts
│   ├── Logistics.Region_Data.sql
│   └── Logistics.Region_Meta.sdcs
├── Security/
│   └── Schemas/
├── Stored Procedures/
│   ├── Customers.RecordFeedback.sql
│   └── Sales.SalesByCategory.sql
├── Tables/
│   ├── Operation.Products.sql
│   ├── Sales.Customers.sql
│   └── ...
└── Views/
    ├── Sales.CustomerOrdersView.sql
    └── ...
```

## Migrations Folder Structure

```
migrations/
├── B001__baseline.sql             # Baseline script
├── V002__Welcome.sql              # Versioned migrations
├── V003.sql
├── V004.sql
├── V006__main_Edit_Operation_Products_turimbar1.sql
├── V007__Add_Colour5_to_Products.sql
├── U002__UNDO-Welcome.sql         # Undo scripts (optional)
└── U007__UNDO-Add_Colour5.sql
```

**Naming conventions**:
- `B###__description.sql` - Baseline
- `V###__description.sql` - Versioned migration
- `U###__UNDO-description.sql` - Undo script

## Key Configuration Options

### From flyway.toml

```toml
[flyway]
locations = ["filesystem:migrations"]
mixed = true                    # Allow mixing versioned and repeatable migrations
outOfOrder = true               # Allow migrations to be applied out of order
validateMigrationNaming = true
defaultSchema = "Customers"
baselineOnMigrate = true
baselineVersion = "001"

[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"
schemaModel = "./schema-model"

[flywayDesktop.generate]
undoScripts = true              # Auto-generate undo scripts
```

### Important Redgate Compare Options

```toml
[redgateCompare.sqlserver.options.behavior]
includeDependencies = true      # Include dependent objects (override with CLI flag)

[redgateCompare.sqlserver]
filterFile = "Filter.scpf"      # Object filter file
```

### Static Data Tables
These tables have their data tracked in version control:
- `Logistics.EmployeeTerritories`
- `Operation.Categories`
- `Logistics.Region`

## Common Patterns for AI Assistants

### Finding Changes
```powershell
flyway diff "-diff.source=development" "-diff.target=schemaModel"
```

### Parsing Diff Output
The diff output is a pipe-delimited table. Parse lines matching:
```regex
^\|\s*(\S+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*([^|]+)\s*\|
```
Groups: ChangeId, ChangeType, ObjectType, Schema, ObjectName

### Excluding Dependencies
Always use this flag when syncing specific objects to avoid pulling in unrelated changes:
```
"-redgateCompare.sqlserver.options.behavior.includeDependencies=false"
```

### Building Change ID Lists
```powershell
$changeIds = ($changes | ForEach-Object { $_.ChangeId }) -join ','
# Result: "id1,id2,id3"
```

### Quoting Arguments
Flyway arguments with `=` must be quoted in PowerShell:
```powershell
# Correct
flyway diff "-diff.source=development" "-diff.target=schemaModel"

# Incorrect (will fail)
flyway diff -diff.source=development -diff.target=schemaModel
```

## Error Handling

- Exit code `0` = success
- Exit code `1` = error (check output for details)
- Always capture stderr: `2>&1 | Out-String`
- Check `$LASTEXITCODE` after each Flyway command

## Common Workflow Patterns

### Reset and Rebuild Shadow Database
```powershell
flyway clean -environment=shadow "-cleanDisabled=false"
flyway migrate -environment=shadow
flyway info -environment=shadow
```

### Validate Before Deploying
```powershell
flyway info -environment=Test           # Check current state
flyway validate -environment=Test       # Validate pending migrations
flyway migrate -environment=Test        # Apply migrations
```

### Generate Deployment Script for Review
```powershell
flyway prepare "-prepare.source=migrations" "-prepare.target=Prod" "-prepare.scriptFilename=deploy_prod.sql"
# Review deploy_prod.sql manually
flyway deploy "-deploy.scriptFilename=deploy_prod.sql" -environment=Prod
```

### Check for Drift
```powershell
flyway diff "-diff.source=Prod" "-diff.target=schemaModel"
# If differences found, investigate schema drift
```

### Speed Up Shadow Provisioning with Backup
For projects with many migrations, use backup provisioner instead of clean+migrate:

```toml
# In flyway.toml - configure shadow to use backup
[environments.shadow]
url = "jdbc:sqlserver://server;databaseName=AutopilotShadow;..."
provisioner = "backup"

[environments.shadow.resolvers.backup]
backupFilePath = '\\server\backups\prod_v995.bak'
backupVersion = "995"
```

This restores to v995 instantly, then only applies migrations 996+.
