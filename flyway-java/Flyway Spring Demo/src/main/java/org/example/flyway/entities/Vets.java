package org.example.flyway.entities;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
public class Vets {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "_id", nullable = false, updatable = false)
    private Long id;
    @Column(nullable = false)
    private String lastname;
    @Column(nullable = false)
    private String firstname;
    @Column(nullable = false)
    private String role;
}
