package com.red.gate;

import java.sql.*;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Database {

    private static final String URL = "jdbc:sqlite:" + System.getProperty("user.dir")+"/demo.db";

    public Database() throws ClassNotFoundException {
        Class.forName("org.sqlite.JDBC");
    }

    public List<Object[]> readTable(String tableName) {
        try (Connection connection = DriverManager.getConnection(URL)) {
            ResultSet resultSet = executeStatement(connection, "SELECT * FROM " + tableName);
            List<Object[]> rows = new ArrayList<>();
            while (resultSet.next()) {
                String firstname = resultSet.getString("firstname");
                String lastname = resultSet.getString("lastname");
                Boolean admin = resultSet.getBoolean("admin");
                rows.add(new Object[]{firstname, lastname, admin});
            }
            return rows;
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }

    private static ResultSet executeStatement(Connection connection, String sql) throws SQLException {
        Statement statement = connection.createStatement();
        statement.execute(sql);
        return statement.getResultSet();
    }
}
