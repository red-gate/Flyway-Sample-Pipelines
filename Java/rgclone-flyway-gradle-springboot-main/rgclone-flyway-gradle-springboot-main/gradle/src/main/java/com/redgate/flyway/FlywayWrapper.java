package com.redgate.flyway;

import com.redgate.rgclone.RGCloneWrapper;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfoService;
import org.flywaydb.core.api.output.ErrorOutput;
import org.flywaydb.core.api.output.MigrateErrorResult;
import org.flywaydb.core.api.output.MigrateResult;
import org.flywaydb.core.internal.command.DbMigrate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.logging.Logger;

@Component
public class FlywayWrapper {

    private final RGCloneWrapper rgCloneWrapper;

    @Autowired
    public FlywayWrapper(RGCloneWrapper rgCloneWrapper) {
        this.rgCloneWrapper = rgCloneWrapper;
    }

    private static final Logger LOG = Logger.getLogger(FlywayWrapper.class.getName());

    public void cloneAndProd(Flyway flyway) {
        if (runOnClone(flyway)) {
            /*
            // UNCOMMENT THIS TO DEPLOY TO PROD FOLLOWING SUCCESSFUL VALIDATION
            boolean success = runOnProd(flyway);
            if (!success) {
                throw new RuntimeException("Failed to run migrations on production");
            }
            */
        } else {
            throw new RuntimeException("Failed to run migrations on clone");
        }
    }

    public boolean runOnProd(Flyway flyway) {
        LOG.info("Deploying migrations to production");

        LOG.info("Pre-migration state of production");
        info(flyway);

        LOG.info("Migration state of production");
        MigrateResult migrateResult = logMigrationError(flyway);
        LOG.info("Number of migrations executed: " + migrateResult.migrationsExecuted);

        LOG.info("Post-migration state of production");
        info(flyway);
        return migrateResult.success;
    }

    public boolean runOnClone(Flyway flyway) {

        rgCloneWrapper.create();
        String cloneUrl = rgCloneWrapper.getJDBCUrl();
        Flyway cloneFlyway = Flyway.configure(flyway.getConfiguration().getClassLoader())
                .configuration(flyway.getConfiguration())
                .dataSource(cloneUrl, null, null)
                .load();

        LOG.info("Deploying migrations to Redgate Clone container: " + RGCloneWrapper.RGCLONE_CONTAINER_NAME);

        LOG.info("Pre-migration state of Redgate Clone container: " + RGCloneWrapper.RGCLONE_CONTAINER_NAME);
        info(cloneFlyway);

        LOG.info("Migration state of Redgate Clone container: " + RGCloneWrapper.RGCLONE_CONTAINER_NAME);
        MigrateResult migrateResult = logMigrationError(cloneFlyway);
        LOG.info("Number of migrations executed: " + migrateResult.migrationsExecuted);

        LOG.info("Post-migration state of Redgate Clone container: " + RGCloneWrapper.RGCLONE_CONTAINER_NAME);
        info(cloneFlyway);

        rgCloneWrapper.delete();

        return migrateResult.success;
    }

    private MigrateResult logMigrationError(Flyway cloneFlyway) {
        MigrateResult migrateResult = migrate(cloneFlyway);
        if (!migrateResult.success) {
            if (migrateResult instanceof MigrateErrorResult migrateErrorResult) {
                LOG.severe(migrateErrorResult.error.message);
            }
        }
        return migrateResult;
    }

    private void info(Flyway flyway) {
        MigrationInfoService migrationInfoService = flyway.info();
        if (migrationInfoService.current() != null && migrationInfoService.current().isVersioned()) {
            LOG.info(String.format("Current schema version: %s", migrationInfoService.current().getVersion().toString()));
        } else {
            LOG.info("No schema version found");
        }
        LOG.info(String.format("Number of currently applies migrations: %d", migrationInfoService.applied().length));
        Arrays.stream(migrationInfoService.applied())
                .sorted((o1, o2) -> o1.getInstalledOn() == null ? 1 : o1.getInstalledOn().compareTo(o2.getInstalledOn()))
                .forEach(appliedMigration -> LOG.info(String.format("Version: %s, Description: %s, Type: %s", appliedMigration.getVersion(), appliedMigration.getDescription(), appliedMigration.getType().toString())));
        LOG.info(String.format("Number of currently pending migrations: %d", migrationInfoService.pending().length));
        Arrays.stream(migrationInfoService.pending())
                .sorted((o1, o2) -> o1.getInstalledOn() == null ? 1 : o1.getInstalledOn().compareTo(o2.getInstalledOn()))
                .forEach(appliedMigration -> LOG.info(String.format("Version: %s, Description: %s, Type: %s", appliedMigration.getVersion(), appliedMigration.getDescription(), appliedMigration.getType().toString())));

    }

    private MigrateResult migrate(Flyway flyway) {
        MigrateResult result;
        try {
            result = flyway.migrate();
        } catch (DbMigrate.FlywayMigrateException e) {
            LOG.severe(e.getMessage());
            result = ErrorOutput.fromMigrateException(e);
        }
        return result;
    }
}
