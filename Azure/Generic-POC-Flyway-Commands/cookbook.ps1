#TODO Hoist vars here


# generic deployment
flyway migrate -configFiles="C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml" -workingDirectory="C:\WorkingFolders\FWD\NewWorldDB" -schemaModelLocation="./schema-model" -schemaModelSchemas= -environment=test

# create snapshot after changes
flyway snapshot -environment=test -filename=snapshothistory:current -configFiles="C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml" -workingDirectory="C:\WorkingFolders\FWD\NewWorldDB" -schemaModelLocation="./schema-model"

# undo back to a specific target number
flyway undo -configFiles="C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml" -workingDirectory="C:\WorkingFolders\FWD\NewWorldDB" -schemaModelLocation="./schema-model" -schemaModelSchemas= -environment=test -target=043.20250716213211

# cherryPick forward
flyway migrate -configFiles="C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml" -workingDirectory="C:\WorkingFolders\FWD\NewWorldDB" -schemaModelLocation="./schema-model" -schemaModelSchemas= -environment=test -cherryPick=045.20251106201536

# drift and code analysis report with snapshots


    # run drift and code analysis (TO SEE DRIFT ALTER TARGET DB OUTSIDE OF FLYWAY)
    # check can be configured to fail on drift or code analysis triggering
    # it's possible to capture changes as well, but it is a duplication of what's stored in schema model and requires an extra database to deploy to in a CI fashion
    flyway check -drift -code -dryrun -environment=test -check.code.failOnError=false -check.failOnDrift=false -check.deployedSnapshot=snapshothistory:current -configFiles="C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml" -workingDirectory="C:\WorkingFolders\FWD\NewWorldDB" -schemaModelLocation="./schema-model"

    # generic deployment
    flyway migrate -configFiles="C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml" -workingDirectory="C:\WorkingFolders\FWD\NewWorldDB" -schemaModelLocation="./schema-model" -schemaModelSchemas= -environment=test
    
    # create snapshot after changes
    flyway snapshot -environment=test -filename=snapshothistory:current -configFiles="C:\WorkingFolders\FWD\NewWorldDB\flyway.toml,C:\WorkingFolders\FWD\NewWorldDB\flyway.user.toml" -workingDirectory="C:\WorkingFolders\FWD\NewWorldDB" -schemaModelLocation="./schema-model"