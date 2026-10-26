package com.portaltramites.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.portaltramites.error.DeepgramException;
import com.portaltramites.error.SolicitudInvalidaException;
import com.portaltramites.model.Busqueda;
import com.portaltramites.model.OrigenBusqueda;
import com.portaltramites.model.Tramite;
import com.portaltramites.repository.BusquedaRepository;
import com.portaltramites.repository.EntidadRepository;
import com.portaltramites.repository.EtiquetaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Búsqueda por voz: envía el audio a DeepGram (modelo Nova, español
 * latinoamericano es-419, con keyterms del dominio) y resuelve la intención
 * buscando la transcripción en el catálogo de trámites. Cada consulta de voz
 * queda registrada en la tabla {@code busqueda}.
 */
@Service
@RequiredArgsConstructor
public class VozService {

    private static final int MAX_AUDIO_BYTES = 10 * 1024 * 1024;
    private static final int MAX_TRAMITES_SUGERIDOS = 5;

    private final TramiteService tramiteService;
    private final EtiquetaRepository etiquetaRepository;
    private final EntidadRepository entidadRepository;
    private final BusquedaRepository busquedaRepository;

    private final RestClient deepgramClient = RestClient.create("https://api.deepgram.com");

    @Value("${deepgram.api-key:}")
    private String apiKey;

    @Value("${deepgram.model:nova-3}")
    private String model;

    @Value("${deepgram.language:es-419}")
    private String language;

    public record VozResultado(String transcripcion, Double confianza, List<Tramite> tramites) {
    }

    @Transactional
    public VozResultado transcribir(byte[] audio, String contentType) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new DeepgramException(
                    "DeepGram no configurado: define DEEPGRAM_API_KEY en backend/.env.local");
        }
        if (audio == null || audio.length == 0) {
            throw new SolicitudInvalidaException("El audio está vacío");
        }
        if (audio.length > MAX_AUDIO_BYTES) {
            throw new SolicitudInvalidaException("El audio supera el máximo de 10 MB");
        }

        JsonNode alternativa = transcribirConDeepgram(audio, contentType);
        String transcript = alternativa.path("transcript").asText("");
        double confianza = alternativa.path("confidence").asDouble(0);
        if (transcript.isBlank()) {
            throw new DeepgramException("No se detectó voz en el audio");
        }

        List<Tramite> candidatos = tramiteService.buscar(transcript, null, null, null);
        List<Tramite> sugeridos = candidatos.stream().limit(MAX_TRAMITES_SUGERIDOS).toList();
        Tramite primero = sugeridos.isEmpty() ? null : sugeridos.get(0);

        Busqueda registro = new Busqueda();
        registro.setOrigen(OrigenBusqueda.VOZ);
        registro.setTextoTranscrito(transcript);
        registro.setIntencionDetectada(primero != null ? primero.getNombre() : null);
        registro.setTramiteRedirect(primero);
        busquedaRepository.save(registro);

        return new VozResultado(transcript, confianza, sugeridos);
    }

    /**
     * Llama a DeepGram (/v1/listen, prerecorded) con keyterms del dominio
     * (etiquetas + siglas de entidades) para mejorar el reconocimiento.
     * Devuelve la mejor alternativa (transcript + confidence).
     */
    private JsonNode transcribirConDeepgram(byte[] audio, String contentType) {
        List<String> keyterms = new ArrayList<>();
        etiquetaRepository.findAll().forEach(e -> keyterms.add(e.getNombre()));
        entidadRepository.findAll().forEach(e -> keyterms.add(e.getSiglas()));

        String url = UriComponentsBuilder.fromPath("/v1/listen")
                .queryParam("model", model)
                .queryParam("language", language)
                .queryParam("smart_format", true)
                .queryParam("punctuate", true)
                .queryParam("keyterm", keyterms.toArray())
                .encode()
                .toUriString();

        JsonNode respuesta;
        try {
            respuesta = deepgramClient.post()
                    .uri(url)
                    .header("Authorization", "Token " + apiKey)
                    .contentType(MediaType.parseMediaType(
                            contentType != null && !contentType.isBlank() ? contentType : "audio/webm"))
                    .body(audio)
                    .retrieve()
                    .onStatus(s -> s.isError(), (req, res) -> {
                        String cuerpo;
                        try {
                            cuerpo = new String(res.getBody().readAllBytes(), StandardCharsets.UTF_8);
                        } catch (IOException e) {
                            cuerpo = "sin detalle";
                        }
                        throw new DeepgramException(
                                "DeepGram respondió " + res.getStatusCode().value() + ": " + cuerpo);
                    })
                    .body(JsonNode.class);
        } catch (DeepgramException e) {
            throw e;
        } catch (Exception e) {
            throw new DeepgramException("No se pudo contactar a DeepGram: " + e.getMessage(), e);
        }

        if (respuesta == null) {
            throw new DeepgramException("DeepGram devolvió una respuesta vacía");
        }
        return respuesta.path("results")
                .path("channels").path(0)
                .path("alternatives").path(0);
    }
}
