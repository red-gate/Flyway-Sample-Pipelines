package org.example.flyway.services;

import lombok.RequiredArgsConstructor;
import org.example.flyway.entities.Animal;
import org.example.flyway.repositories.AnimalsRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@RequiredArgsConstructor(onConstructor = @__(@Autowired))
@Service
public class AnimalsService {

    private final AnimalsRepository repository;

    public Animal get(Long id) {
        return repository.findById(id).orElse(null);
    }

    public List<Animal> findAll() {
        return repository.findAll();
    }
}
