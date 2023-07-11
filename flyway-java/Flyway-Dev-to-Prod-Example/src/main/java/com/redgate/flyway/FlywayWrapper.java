package com.redgate.flyway;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfoService;
import org.flywaydb.core.api.output.ErrorOutput;
import org.flywaydb.core.api.output.MigrateErrorResult;
import org.flywaydb.core.api.output.MigrateResult;
import org.flywaydb.core.internal.command.DbMigrate;
import org.flywaydb.core.internal.configuration.ConfigUtils;

import javax.sql.DataSource;
import java.io.File;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

public class FlywayWrapper {
    Logger LOG = Logger.getLogger(FlywayWrapper.class.getName());

    public Flyway configure(String url, String user, String password) {
        return Flyway.configure()
                .licenseKey(System.getenv("FLYWAY_LICENSE_KEY"))
                .dataSource(url, user, password)
                .locations("filesystem:src/main/resources/sql")
                .load();
    }

    public Flyway configure(List<String> configurationFiles) {
        Map<String, String> configuration = new HashMap<>();
        for (String configurationFile : configurationFiles) {
            configuration.putAll(ConfigUtils.loadConfigurationFile(new File(configurationFile), "UTF-8", true));
        }
        return Flyway.configure()
                .licenseKey(System.getenv("FLYWAY_LICENSE_KEY"))
                .configuration(configuration)
                .load();
    }

    public MigrationInfoService info (Flyway flyway){
        return flyway.info();
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
