package com.redgate.flyway;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class CloneMigrationStrategyConfig {

    private final FlywayWrapper flywayWrapper;

    @Autowired
    public CloneMigrationStrategyConfig(FlywayWrapper flywayWrapper) {
        this.flywayWrapper = flywayWrapper;
    }

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy() {
        return flywayWrapper::cloneAndProd;
    }


}
