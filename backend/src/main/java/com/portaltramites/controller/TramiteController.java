package com.portaltramites.controller;

import com.portaltramites.model.RequisitoVista;
import com.portaltramites.model.TramiteDetalle;
import com.portaltramites.model.TramiteLista;
import com.portaltramites.service.TramiteService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/tramites")
@RequiredArgsConstructor
@Validated
public class TramiteController {

    private final TramiteService tramiteService;

    /**
     * Listado con filtros opcionales.
     * Ej.: /api/tramites?q=dni&entidad=RENIEC&tipo=TRAMITE&modalidad=VIRTUAL
     */
    @GetMapping
    public ResponseEntity<List<TramiteLista>> buscar(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String entidad,
            @RequestParam(required = false) String tipo,
            @RequestParam(required = false) String modalidad) {
        return ResponseEntity.ok(tramiteService.buscar(q, entidad, tipo, modalidad));
    }

    @GetMapping("/{id}")
    public ResponseEntity<TramiteDetalle> obtenerPorId(@PathVariable Integer id) {
        return ResponseEntity.ok(tramiteService.detalle(id));
    }

    @GetMapping("/{id}/requisitos")
    public ResponseEntity<List<RequisitoVista>> requisitos(@PathVariable Integer id) {
        return ResponseEntity.ok(tramiteService.requisitos(id));
    }

    /**
     * Documentos relacionados: trámites que comparten etiquetas con el
     * trámite de referencia, ordenados por etiquetas en común.
     * Ej.: /api/tramites/8/relacionados?limite=3
     */
    @GetMapping("/{id}/relacionados")
    public ResponseEntity<List<TramiteLista>> relacionados(
            @PathVariable Integer id,
            @RequestParam(required = false) @Min(1) @Max(20) Integer limite) {
        return ResponseEntity.ok(tramiteService.relacionados(id, limite));
    }
}
