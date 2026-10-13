package com.portaltramites.controller;

import com.portaltramites.model.Tramite;
import com.portaltramites.service.VozService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/voz")
@RequiredArgsConstructor
public class VozController {

    private final VozService vozService;

    /**
     * Transcribe un audio (p. ej. audio/webm del navegador) con DeepGram y
     * devuelve la transcripción junto a los trámites que mejor coinciden
     * (resolución de intención contra el catálogo).
     */
    @PostMapping(value = "/transcribir", consumes = {"audio/*", "application/octet-stream"})
    public ResponseEntity<VozRespuesta> transcribir(
            @RequestBody byte[] audio,
            @RequestHeader(value = "Content-Type", required = false) String contentType) {
        VozService.VozResultado resultado = vozService.transcribir(audio, contentType);
        return ResponseEntity.ok(new VozRespuesta(
                resultado.transcripcion(), resultado.confianza(), resultado.tramites()));
    }

    public record VozRespuesta(String transcripcion, Double confianza, List<Tramite> tramites) {
    }
}
