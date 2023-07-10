package org.example.flyway;

import lombok.SneakyThrows;
import lombok.extern.java.Log;
import org.flywaydb.core.Flyway;

import java.sql.Connection;
import java.sql.ResultSet;

import static org.example.flyway.utils.FlywayUtils.*;
import static org.example.flyway.utils.SqlUtils.connect;
import static org.example.flyway.utils.SqlUtils.executeStatement;

@Log
public class Main {

    @SneakyThrows
    public static void main(String[] args) {
        String url = "jdbc:sqlite:C:\\Users\\Barry.Attwater\\GitHub\\Flyway Java Demo\\vetsToGo.db";
        setup(url);
        try (Connection connection = connect(url)) {
            ResultSet resultSet = executeStatement(connection, "SELECT * FROM animal");
            while (resultSet.next()) {
                String type = resultSet.getString("type");
                String classification = resultSet.getString("classification");
                log.info(String.format("type: %s, classification: %s", type, classification));
            }
        }
    }

    private static void setup(String url) {
        Flyway flyway = createFlyway(url, null, null, new String[]{"filesystem:C:\\Users\\Barry.Attwater\\GitHub\\Flyway Java Demo\\migration"});
        info(flyway);
        migrate(flyway);
        info(flyway);
    }
}
