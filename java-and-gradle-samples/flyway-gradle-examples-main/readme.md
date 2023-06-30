For example:

gradlew flyway-gradle-only:flywayInfo "-Pflyway.licenseKey=%lk%" will run the equlivant of flyway info on the 'flyway-gradle-only' project.

However, if you are in the project folder you do not need to specify the project prefix, for example gradlew flywayInfo "-Pflyway.licenseKey=%lk%"