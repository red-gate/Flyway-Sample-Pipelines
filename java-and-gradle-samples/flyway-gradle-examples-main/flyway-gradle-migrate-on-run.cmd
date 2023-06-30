@REM Needs licence key
SET lk=PUT LICENSE KEY HERE
@REM gradlew flyway-gradle-migrate-on-run:run "-Pflyway.licenseKey=%lk%"

gradlew flyway-gradle-migrate-on-run:run