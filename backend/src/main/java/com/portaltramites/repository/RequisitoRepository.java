package com.portaltramites.repository;

import com.portaltramites.model.Requisito;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RequisitoRepository extends JpaRepository<Requisito, Integer> {

    List<Requisito> findByTramiteIdOrderByOrdenAsc(Integer tramiteId);
}
