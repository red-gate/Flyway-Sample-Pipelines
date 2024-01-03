package org.example.flyway.services;

import lombok.RequiredArgsConstructor;
import org.example.flyway.entities.Customers;
import org.example.flyway.repositories.CustomersRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@RequiredArgsConstructor(onConstructor = @__(@Autowired))
@Service
public class CustomersService {

    private final CustomersRepository repository;

    public Customers get(Long id) {
        return repository.findById(id).orElse(null);
    }

    public List<Customers> findAll() {
        return repository.findAll();
    }
}
