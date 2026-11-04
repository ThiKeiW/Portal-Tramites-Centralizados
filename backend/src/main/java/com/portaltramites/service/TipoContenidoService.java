package com.portaltramites.service;

import com.portaltramites.model.TipoContenido;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class TipoContenidoService {

    private final CatalogoService catalogoService;

    /** Listado desde el catálogo en memoria (cero consultas al BD). */
    public List<TipoContenido> listar() {
        return catalogoService.snapshot().tipos();
    }
}
