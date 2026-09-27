package com.portaltramites.controller;

import com.portaltramites.model.TipoContenido;
import com.portaltramites.service.TipoContenidoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/tipos")
@RequiredArgsConstructor
public class TipoContenidoController {

    private final TipoContenidoService tipoContenidoService;

    @GetMapping
    public ResponseEntity<List<TipoContenido>> listar() {
        return ResponseEntity.ok(tipoContenidoService.listar());
    }
}
