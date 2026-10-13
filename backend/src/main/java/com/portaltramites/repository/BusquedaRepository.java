package com.portaltramites.repository;

import com.portaltramites.model.Busqueda;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusquedaRepository extends JpaRepository<Busqueda, Long> {
}
