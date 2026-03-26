## take pre-deployment snapshot of target for drift report
## NOTE: In a pipeline, this would be a post-release step, and then the artifiact should be saved off somewhere
flyway snapshot -url=$(target_JDBC_URL) -user=$(target_username) -password=$(target_password) -snapshot.filename="C:\snapshots\VCurrent_snapshot"

## Pre-Deploy Drift Check - Use snapshots for Drift and Change reports
flyway info check -drift -dryrun -code  -check.deployedSnapshot="C:\snapshots\VCurrent_snapshot" -check.failOnDrift="$(Boolean)"  -schemas="$(schemas)" -url="$(target_database_JDBC)" -user="$(userName)" -password="$(password)" -check.reportFilename="$(System.ArtifactsDirectory)\$(databaseName)-$(Build.BuildId)-DriftReport.html" -licenseKey=$(FLYWAY_LICENSE_KEY) -workingDirectory="$(WORKING_DIRECTORY)" 

## if there is drift - generate script to represent drift
## generate script to run against cleaned target

## take pre-deployment snapshot of target for drift report
flyway snapshot -url=jdbc:oracle:thin:@//localhost:1521/Acceptance -user="HR" -password="Redgate1" -snapshot.filename="C:\snapshots\VCurrent_snapshot"

## Pre-Deploy Drift Check - Use snapshots for Drift and Change reports
flyway info check -drift -dryrun -code  -check.deployedSnapshot="C:\snapshots\VCurrent_snapshot" -check.failOnDrift="false"  -schemas="HR" -url="jdbc:oracle:thin:@//localhost:1521/Production" -user="$HR" -password="Redgate1" -check.reportFilename=".\HR-DriftReport.html" -licenseKey=$(FLYWAY_LICENSE_KEY)  



## deploy to target
## flyway migrate -url=$(target_JDBC_URL) -user=$(target_username) -password=$(target_password)

## take snapshot for change report and post deploy check - how does deployment change objects in target to estimate changes in target db
flyway snapshot -url=$(target_JDBC_URL) -user=$(target_username) -password=$(target_password) -snapshot.filename="C:\snapshots\VNext_snapshot"

## deploy to Target Database
## flyway migrate -url=$(target_JDBC_URL) -user=$(username) -password=$(password)

## Post-Deploy Check - Use snapshot to ensure everything deployed as expected
flyway info check -drift  -check.deployedSnapshot="C:\snapshots\VNext_snapshot" -check.failOnDrift="$(Boolean)"  -schemas="$(schemas)" -url="$(target_database_JDBC)" -user="$(userName)" -password="$(password)" -check.reportFilename="$(System.ArtifactsDirectory)\$(databaseName)-$(Build.BuildId)-DriftReport.html" -licenseKey=$(FLYWAY_LICENSE_KEY) -workingDirectory="$(WORKING_DIRECTORY)"