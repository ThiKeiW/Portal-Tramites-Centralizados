package com.portaltramites.repository;

import com.portaltramites.model.Entidad;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface EntidadRepository extends JpaRepository<Entidad, Integer> {

    List<Entidad> findByActivoTrueOrderByNombreAsc();

    Optional<Entidad> findBySiglasIgnoreCaseAndActivoTrue(String siglas);
}
