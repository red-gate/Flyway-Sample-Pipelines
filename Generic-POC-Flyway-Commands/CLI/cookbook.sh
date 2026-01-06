# These commands are constructed so they can be copy/pasted one at a time and edited as needed with the appropriate values. 
# For a properly parameterized script, see https://github.com/red-gate/Flyway-Sample-Pipelines/blob/main/Generic-POC-Flyway-Commands/Unix/cookbook.sh

# Each command below can be copied and pasted independently
# Update the inline values as needed for your environment

# ================================================================================

# run code analysis only
flyway check -code -environment=test -check.code.failOnError=false

# ================================================================================

# generic deployment
flyway migrate -environment=test


# create snapshot after changes
flyway snapshot -environment=test -filename=snapshothistory:current

# ================================================================================

# undo back to a specific target number
flyway undo  -environment=test -target=043.20250716213211

# ================================================================================

# generic deployment
flyway migrate  -environment=test

# ================================================================================

# cherryPick forward
flyway migrate  -environment=test -cherryPick=045.20251106201536

# ================================================================================

# drift and code analysis report with snapshots

# run drift and code analysis (TO SEE DRIFT ALTER TARGET DB OUTSIDE OF FLYWAY)
# check can be configured to fail on drift or code analysis triggering
flyway check -drift -code -dryrun -environment=test -check.code.failOnError=false -check.failOnDrift=false -check.deployedSnapshot=snapshothistory:current 


# ================================================================================

# cherryPick forward
flyway migrate  -environment=test -cherryPick=045.20251106201536

# ================================================================================

# create snapshot after changes
flyway snapshot -environment=test -filename=snapshothistory:current 
