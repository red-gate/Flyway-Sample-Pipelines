package org.example.flyway;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.example.flyway.services.AnimalsService;
import org.example.flyway.services.AppointmentsService;
import org.example.flyway.services.CustomersService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@Slf4j
@RequiredArgsConstructor(onConstructor = @__(@Autowired))
@SpringBootApplication
public class FlywaySpringDemoApplication implements CommandLineRunner {

    private final AnimalsService animalsService;
    private final AppointmentsService appointmentsService;
    private final CustomersService customersService;

    public static void main(String[] args) {
        SpringApplication.run(FlywaySpringDemoApplication.class, args);
    }

    @Override
    public void run(String... args) {
        if (args.length == 0) {
            log.info("Please include operation as argument");
            return;
        }
        String operation = args[0];
        switch (operation) {
            case "animal" -> {
                if (args.length == 2) {
                    if ("list".equals(args[1])) {
                        animalsService.findAll().forEach(appointment -> log.info(appointment.toString()));
                    } else {
                        log.info(animalsService.get(Long.parseLong(args[1])).toString());
                    }
                }
            }
            case "customer" -> {
                if (args.length == 2) {
                    if ("list".equals(args[1])) {
                        customersService.findAll().forEach(appointment -> log.info(appointment.toString()));
                    } else {
                        log.info(customersService.get(Long.parseLong(args[1])).toString());
                    }
                }
            }

            case "appointment" -> {
                if (args.length == 2) {
                    if ("list".equals(args[1])) {
                        appointmentsService.findAll().forEach(appointment -> log.info(appointment.toString()));
                    } else {
                        log.info(appointmentsService.get(Long.parseLong(args[1])).toString());
                    }
                }
            }
            default -> log.info("Please include operation as argument");
        }
    }
}
