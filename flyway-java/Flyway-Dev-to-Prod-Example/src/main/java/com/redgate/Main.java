package com.redgate;

import com.redgate.flyway.FlywayWrapper;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfoService;
import org.flywaydb.core.api.output.MigrateErrorResult;
import org.flywaydb.core.api.output.MigrateResult;

import java.util.List;
import java.util.logging.Logger;

public class Main {
    private static final Logger LOG = Logger.getLogger(Main.class.getName());

    public static void main(String[] args) {
        FlywayWrapper flywayWrapper = new FlywayWrapper();

        if (runOnClone(flywayWrapper)) {
            runOnProd(flywayWrapper);
        }
    }


    public static boolean runOnClone(FlywayWrapper flywayWrapper) {
        String cloneUrl = System.getenv("CLONE_URL");
        String cloneUser = System.getenv("CLONE_USER");
        String clonePassword = System.getenv("CLONE_PASSWORD");
        Flyway flyway = flywayWrapper.configure(cloneUrl, cloneUser, clonePassword);
        MigrateResult migrateResult = flywayWrapper.migrate(flyway);
        if (!migrateResult.success) {
            if (migrateResult instanceof MigrateErrorResult migrateErrorResult) {
                LOG.severe(migrateErrorResult.error.message);
            }
        }
        LOG.info("Number of migrations executed: " + migrateResult.migrationsExecuted);
        return migrateResult.success;

    }

    public static void runOnProd(FlywayWrapper flywayWrapper) {
        Flyway flyway = flywayWrapper.configure(List.of("src/main/resources/flyway.conf"));
        flywayWrapper.migrate(flyway);
        MigrationInfoService migrationInfoService = flywayWrapper.info(flyway);
        if (migrationInfoService.current() != null && migrationInfoService.current().isVersioned()) {
            LOG.info(String.format("Current schema version: %s", migrationInfoService.current().getVersion().toString()));
        } else {
            LOG.info("No schema version found");
        }
        LOG.info(String.format("Number of currently applies migrations: %d", migrationInfoService.applied().length));
        LOG.info(String.format("Number of currently pending migrations: %d", migrationInfoService.pending().length));
    }

}
