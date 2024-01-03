package org.example.flyway.entities;

import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Entity
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "_id", nullable = false, updatable = false)
    private Long id;
    @Column(nullable = false)
    private LocalDateTime dateTime;
    @ManyToOne
    @JoinColumn(name = "customer_id", nullable = false)
    private Customers customer;
    @ManyToOne
    @JoinColumn(name = "vet_id", nullable = false)
    private Vets vet;
    @Column(nullable = false)
    String reason;
}
