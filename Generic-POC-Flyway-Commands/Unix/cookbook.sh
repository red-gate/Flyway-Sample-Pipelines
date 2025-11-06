#!/bin/bash

# Variables to be changed by user
CONFIG_FILES="/path/to/flyway.toml,/path/to/flyway.user.toml"
WORKING_DIRECTORY="/path/to/working/directory"
SCHEMA_MODEL_LOCATION="./schema-model"
ENVIRONMENT="test"
TARGET="043.20250716213211"
CHERRY_PICK="045.20251106201536"

# generic deployment
flyway migrate -configFiles="$CONFIG_FILES" -workingDirectory="$WORKING_DIRECTORY" -schemaModelLocation="$SCHEMA_MODEL_LOCATION" -schemaModelSchemas= -environment=$ENVIRONMENT

# create snapshot after changes
flyway snapshot -environment=$ENVIRONMENT -filename=snapshothistory:current -configFiles="$CONFIG_FILES" -workingDirectory="$WORKING_DIRECTORY" -schemaModelLocation="$SCHEMA_MODEL_LOCATION"

# undo back to a specific target number
flyway undo -configFiles="$CONFIG_FILES" -workingDirectory="$WORKING_DIRECTORY" -schemaModelLocation="$SCHEMA_MODEL_LOCATION" -schemaModelSchemas= -environment=$ENVIRONMENT -target=$TARGET

# cherryPick forward
flyway migrate -configFiles="$CONFIG_FILES" -workingDirectory="$WORKING_DIRECTORY" -schemaModelLocation="$SCHEMA_MODEL_LOCATION" -schemaModelSchemas= -environment=$ENVIRONMENT -cherryPick=$CHERRY_PICK

# drift and code analysis report with snapshots

    # run drift and code analysis (TO SEE DRIFT ALTER TARGET DB OUTSIDE OF FLYWAY)
    # check can be configured to fail on drift or code analysis triggering
    # it's possible to capture changes as well, but it is a duplication of what's stored in schema model and requires an extra database to deploy to in a CI fashion
    flyway check -drift -code -dryrun -environment=$ENVIRONMENT -check.code.failOnError=false -check.failOnDrift=false -check.deployedSnapshot=snapshothistory:current -configFiles="$CONFIG_FILES" -workingDirectory="$WORKING_DIRECTORY" -schemaModelLocation="$SCHEMA_MODEL_LOCATION"

    # generic deployment
    flyway migrate -configFiles="$CONFIG_FILES" -workingDirectory="$WORKING_DIRECTORY" -schemaModelLocation="$SCHEMA_MODEL_LOCATION" -schemaModelSchemas= -environment=$ENVIRONMENT
    
    # create snapshot after changes
    flyway snapshot -environment=$ENVIRONMENT -filename=snapshothistory:current -configFiles="$CONFIG_FILES" -workingDirectory="$WORKING_DIRECTORY" -schemaModelLocation="$SCHEMA_MODEL_LOCATION"