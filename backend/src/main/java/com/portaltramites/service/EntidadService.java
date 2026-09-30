package com.portaltramites.service;

import com.portaltramites.error.RecursoNoEncontradoException;
import com.portaltramites.model.Entidad;
import com.portaltramites.repository.EntidadRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EntidadService {

    private final EntidadRepository entidadRepository;

    @Transactional(readOnly = true)
    public List<Entidad> listar() {
        return entidadRepository.findByActivoTrueOrderByNombreAsc();
    }

    @Transactional(readOnly = true)
    public Entidad obtenerPorId(Integer id) {
        return entidadRepository.findById(id)
                .filter(Entidad::getActivo)
                .orElseThrow(() -> new RecursoNoEncontradoException(
                        "Entidad no encontrada con id: " + id));
    }
}
