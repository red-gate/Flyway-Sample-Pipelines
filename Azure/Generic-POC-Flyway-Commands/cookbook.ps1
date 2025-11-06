# Variables to be changed by user
$configFiles = "C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml"
$workingDirectory = "C:\WorkingFolders\FWD\NewWorldDB"
$schemaModelLocation = "./schema-model"
$environment = "test"
$target = "043.20250716213211"
$cherryPick = "045.20251106201536"

# generic deployment
flyway migrate -configFiles="$configFiles" -workingDirectory="$workingDirectory" -schemaModelLocation="$schemaModelLocation" -schemaModelSchemas= -environment=$environment

# create snapshot after changes
flyway snapshot -environment=$environment -filename=snapshothistory:current -configFiles="$configFiles" -workingDirectory="$workingDirectory" -schemaModelLocation="$schemaModelLocation"

# undo back to a specific target number
flyway undo -configFiles="$configFiles" -workingDirectory="$workingDirectory" -schemaModelLocation="$schemaModelLocation" -schemaModelSchemas= -environment=$environment -target=$target

# cherryPick forward
flyway migrate -configFiles="$configFiles" -workingDirectory="$workingDirectory" -schemaModelLocation="$schemaModelLocation" -schemaModelSchemas= -environment=$environment -cherryPick=$cherryPick

# drift and code analysis report with snapshots

    # run drift and code analysis (TO SEE DRIFT ALTER TARGET DB OUTSIDE OF FLYWAY)
    # check can be configured to fail on drift or code analysis triggering
    # it's possible to capture changes as well, but it is a duplication of what's stored in schema model and requires an extra database to deploy to in a CI fashion
    flyway check -drift -code -dryrun -environment=$environment -check.code.failOnError=false -check.failOnDrift=false -check.deployedSnapshot=snapshothistory:current -configFiles="$configFiles" -workingDirectory="$workingDirectory" -schemaModelLocation="$schemaModelLocation"

    # generic deployment
    flyway migrate -configFiles="$configFiles" -workingDirectory="$workingDirectory" -schemaModelLocation="$schemaModelLocation" -schemaModelSchemas= -environment=$environment
    
    # create snapshot after changes
    flyway snapshot -environment=$environment -filename=snapshothistory:current -configFiles="$configFiles" -workingDirectory="$workingDirectory" -schemaModelLocation="$schemaModelLocation"