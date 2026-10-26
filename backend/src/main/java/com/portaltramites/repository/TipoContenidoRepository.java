package com.portaltramites.repository;

import com.portaltramites.model.TipoContenido;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TipoContenidoRepository extends JpaRepository<TipoContenido, Integer> {

    List<TipoContenido> findByActivoTrueOrderByNombreAsc();

    Optional<TipoContenido> findByNombreIgnoreCase(String nombre);
}
