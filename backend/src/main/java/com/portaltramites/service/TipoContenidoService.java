package com.portaltramites.service;

import com.portaltramites.model.TipoContenido;
import com.portaltramites.repository.TipoContenidoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class TipoContenidoService {

    private final TipoContenidoRepository tipoContenidoRepository;

    @Transactional(readOnly = true)
    public List<TipoContenido> listar() {
        return tipoContenidoRepository.findByActivoTrueOrderByNombreAsc();
    }
}
