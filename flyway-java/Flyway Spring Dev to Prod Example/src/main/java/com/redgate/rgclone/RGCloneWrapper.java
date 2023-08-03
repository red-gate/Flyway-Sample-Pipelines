package com.redgate.rgclone;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.redgate.util.ProcessUtils;
import org.springframework.stereotype.Component;

import java.util.logging.Logger;

@Component
public class RGCloneWrapper {

    private static final Logger LOG = Logger.getLogger(RGCloneWrapper.class.getName());
    private static final String RGCLONE_EXECUTABLE = "./rgclone";
    private static final String RGCLONE_API_ENDPOINT = System.getenv("RGCLONE_API_ENDPOINT");
    public static final String RGCLONE_CONTAINER_NAME = System.getenv("RGCLONE_CONTAINER_NAME");

    public void create() {
        String[] command = {RGCLONE_EXECUTABLE, "create", "data-container", "--name", RGCLONE_CONTAINER_NAME, "--lifetime", "5m", "-i", "111"};
        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.environment().put("RGCLONE_API_ENDPOINT", RGCLONE_API_ENDPOINT);
        try {
            Process process = processBuilder.start();
            ProcessUtils.inheritIO(process.getInputStream(), LOG, false);
            ProcessUtils.inheritIO(process.getErrorStream(), LOG, true);
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new Exception("Failed to create data container. Exit code: " + exitCode);
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public String getJDBCUrl() {
        String jdbcUrl;
        String[] command = {RGCLONE_EXECUTABLE, "get", "data-container", RGCLONE_CONTAINER_NAME, "-o", "json"};
        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.environment().put("RGCLONE_API_ENDPOINT", RGCLONE_API_ENDPOINT);
        try {
            Process process = processBuilder.start();
            ProcessUtils.inheritIO(process.getErrorStream(), LOG, true);
            String output = ProcessUtils.getProcessOutput(process);
            jdbcUrl = getJDBCUrlFromJson(output);
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new Exception("Failed to create data container. Exit code: " + exitCode);
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        return jdbcUrl;
    }

    private static String getJDBCUrlFromJson(String json) {
        Gson gson = new Gson();
        JsonObject jsonObject = gson.fromJson(json, JsonObject.class);
        return jsonObject.get("jdbcConnectionString").getAsString();
    }
}
