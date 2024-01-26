package com.redgate.util;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Scanner;
import java.util.logging.Logger;

public class ProcessUtils {

    public static String getProcessOutput(Process process) throws IOException {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            StringBuilder output = new StringBuilder();
            while ((line = reader.readLine()) != null) {
                output.append(line);
            }
            return output.toString();
        }
    }

    public static void inheritIO(final InputStream src, final Logger log, boolean error) {
        new Thread(() -> {
            Scanner sc = new Scanner(src);
            while (sc.hasNextLine()) {
                if (error) {
                    log.severe(sc.nextLine());
                } else {
                    log.info(sc.nextLine());
                }
            }
        }).start();
    }
}
