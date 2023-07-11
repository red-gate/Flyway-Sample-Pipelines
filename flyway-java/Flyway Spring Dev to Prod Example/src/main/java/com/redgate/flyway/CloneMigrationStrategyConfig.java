package com.redgate.flyway;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfoService;
import org.flywaydb.core.api.configuration.FluentConfiguration;
import org.flywaydb.core.api.output.ErrorOutput;
import org.flywaydb.core.api.output.MigrateErrorResult;
import org.flywaydb.core.api.output.MigrateResult;
import org.flywaydb.core.internal.command.DbMigrate;
import org.flywaydb.core.internal.configuration.ConfigUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.File;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

@Configuration
public class CloneMigrationStrategyConfig {

    private static final Logger LOG = Logger.getLogger(CloneMigrationStrategyConfig.class.getName());

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy() {
        return flyway -> {
            if(runOnClone(flyway)){
                flyway.migrate();
                flyway.info();
            } else {
                throw new RuntimeException("Failed to run migrations on clone");
            }
        };
    }

    public boolean runOnClone(Flyway flyway) {
        String cloneUrl = System.getenv("CLONE_URL");
        String cloneUser = System.getenv("CLONE_USER");
        String clonePassword = System.getenv("CLONE_PASSWORD");
        Flyway cloneFlyway = new FluentConfiguration().configuration(flyway.getConfiguration())
                .dataSource(cloneUrl, cloneUser, clonePassword)
                .load();
        MigrateResult migrateResult = migrate(cloneFlyway);
        if (!migrateResult.success) {
            if (migrateResult instanceof MigrateErrorResult migrateErrorResult) {
                LOG.severe(migrateErrorResult.error.message);
            }
        }
        LOG.info("Number of migrations executed: " + migrateResult.migrationsExecuted);
        return migrateResult.success;
    }

    public void info (Flyway flyway){
        MigrationInfoService migrationInfoService = flyway.info();
        if (migrationInfoService.current() != null && migrationInfoService.current().isVersioned()) {
            LOG.info(String.format("Current schema version: %s", migrationInfoService.current().getVersion().toString()));
        } else {
            LOG.info("No schema version found");
        }
        LOG.info(String.format("Number of currently applies migrations: %d", migrationInfoService.applied().length));
        LOG.info(String.format("Number of currently pending migrations: %d", migrationInfoService.pending().length));
    }

    public MigrateResult migrate (Flyway flyway){
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
