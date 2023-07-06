package org.example.flyway.entities;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
public class Animal {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "_id", nullable = false, updatable = false)
    private Long id;
    @Column(nullable = false)
    private String type;
    @ManyToOne
    @JoinColumn(name = "classification_id")
    private Classification classification;
}
