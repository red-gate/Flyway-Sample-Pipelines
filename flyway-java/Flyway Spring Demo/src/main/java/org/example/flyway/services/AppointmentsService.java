package org.example.flyway.services;


import lombok.RequiredArgsConstructor;
import org.example.flyway.entities.Appointment;
import org.example.flyway.entities.Customers;
import org.example.flyway.entities.Vets;
import org.example.flyway.repositories.AppointmentsRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@RequiredArgsConstructor(onConstructor = @__(@Autowired))
@Service
public class AppointmentsService {

    private final AppointmentsRepository repository;

    public Appointment createAppointment(LocalDateTime dateTime, Customers customer, Vets vet, String reason) {
        Appointment appointment = new Appointment();
        appointment.setDateTime(dateTime);
        appointment.setCustomer(customer);
        appointment.setVet(vet);
        appointment.setReason(reason);
        return repository.save(appointment);
    }

    public Appointment get(Long id) {
        return repository.findById(id).orElse(null);
    }

    public List<Appointment> findAll() {
        return repository.findAll();
    }
}
