package com.redgate.flyway;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ExtendWith(SpringExtension.class)
@SpringBootTest
@Disabled
public class FlywayWrapperTest {

    @Autowired
    FlywayWrapper subject;

    Flyway flyway;

    @BeforeEach
    public void setup() {
        flyway = Flyway.configure()
                .locations("db/migration")
                .licenseKey(System.getenv("FLYWAY_LICENSE_KEY"))
                .load();
    }

    @Test
    public void testRunOnProd() {
        Flyway testFlyway = Flyway.configure()
                .configuration(flyway.getConfiguration())
                .dataSource("jdbc:h2:file:./test;Mode=Oracle;DB_CLOSE_DELAY=-1", null, null)
                .load();
        Assertions.assertTrue(subject.runOnProd(testFlyway));
    }

    @Test
    public void testRunOnClone() {
        Assertions.assertTrue(subject.runOnClone(flyway));
    }
}
