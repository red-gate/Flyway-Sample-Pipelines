package org.example.flyway.utils;

import lombok.extern.java.Log;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfoService;
import org.flywaydb.core.api.output.MigrateResult;

@Log
public class FlywayUtils {
    public static Flyway createFlyway(String url, String user, String password, String[] scriptLocations) {
        return Flyway.configure()
                .dataSource(url, user, password)
                .cherryPick("1","2")
                .locations(scriptLocations)
                .cleanDisabled(false)
                .load();
    }

    public static void info(Flyway flyway) {
        MigrationInfoService info = flyway.info();
        if (info.current() != null && info.current().isVersioned()) {
            log.info(String.format("Current schema version: %s", info.current().getVersion().toString()));
        } else {
            log.info("No schema version found");
        }
        log.info(String.format("Number of currently applies migrations: %d", info.applied().length));
        log.info(String.format("Number of currently pending migrations: %d", info.pending().length));
    }

    public static void migrate(Flyway flyway) {
        MigrateResult migrate = flyway.migrate();
        log.info(String.format("Number of successfully applied migrations: %d", migrate.migrationsExecuted));
    }
}
