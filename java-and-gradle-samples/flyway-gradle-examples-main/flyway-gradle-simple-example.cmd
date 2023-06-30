@REM Needs licence key
SET lk=PUT LICENSE KEY HERE
gradlew flyway-gradle-simple-example:flywayInfo "-Pflyway.licenseKey=%lk%"
gradlew flyway-gradle-simple-example:flywaymigrate "-Pflyway.licenseKey=%lk%"
gradlew flyway-gradle-simple-example:flywayInfo "-Pflyway.licenseKey=%lk%"
gradlew flyway-gradle-simple-example:run