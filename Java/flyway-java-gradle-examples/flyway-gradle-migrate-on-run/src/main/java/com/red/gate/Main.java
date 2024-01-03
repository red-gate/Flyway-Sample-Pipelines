package com.red.gate;

import java.util.List;

public class Main {

    public static void main(String[] args) throws ClassNotFoundException {
        Database database = new Database();
        List<Object[]> rows = database.readTable("user");
        rows.forEach(row -> System.out.printf("firstname: %s, lastname: %s, admin: %b%n", row[0], row[1], row[2]));
    }
}
