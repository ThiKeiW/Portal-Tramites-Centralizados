package com.portaltramites.controller;

import com.portaltramites.model.Entidad;
import com.portaltramites.service.EntidadService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/entidades")
@RequiredArgsConstructor
public class EntidadController {

    private final EntidadService entidadService;

    @GetMapping
    public ResponseEntity<List<Entidad>> listar() {
        return ResponseEntity.ok(entidadService.listar());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Entidad> obtenerPorId(@PathVariable Integer id) {
        return ResponseEntity.ok(entidadService.obtenerPorId(id));
    }
}
