package org.example.flyway.repositories;

import org.example.flyway.entities.Vets;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VetsRepository extends JpaRepository<Vets, Long> {
}
