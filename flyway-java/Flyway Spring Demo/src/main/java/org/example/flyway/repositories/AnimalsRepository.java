package org.example.flyway.repositories;

import org.example.flyway.entities.Animal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AnimalsRepository extends JpaRepository<Animal, Long> {
}
