@REM Needs licence key
SET lk=
gradlew flyway-gradle-only:flywayInfo "-Pflyway.licenseKey=%lk%"
gradlew flyway-gradle-only:flywaymigrate "-Pflyway.licenseKey=%lk%"
gradlew flyway-gradle-only:flywayInfo "-Pflyway.licenseKey=%lk%"


gradlew flyway-gradle-only:flywaymigrate

gradlew flyway-gradle-only:flywayundo

gradlew flyway-gradle-only:flywaymigrate "-Pflyway.cherryPick=3"

