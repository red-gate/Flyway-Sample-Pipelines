package org.example.flyway.utils;

import lombok.SneakyThrows;
import lombok.extern.java.Log;

import java.sql.*;

@Log
public class SqlUtils {

    public static Connection connect(String url) {
        Connection connection = null;
        try {
            connection = DriverManager.getConnection(url);
        } catch (SQLException e) {
            log.severe(String.format("Error connecting to database: %s", e.getMessage()));
        }
        return connection;
    }

    @SneakyThrows
    public static ResultSet executeStatement(Connection connection, String sql) {
        Statement statement = connection.createStatement();
        statement.execute(sql);
        return statement.getResultSet();
    }
}
