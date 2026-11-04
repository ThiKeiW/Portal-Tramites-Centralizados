package com.portaltramites.service;

import com.portaltramites.model.Entidad;
import com.portaltramites.model.RequisitoDe;
import com.portaltramites.model.TramiteEtiqueta;
import com.portaltramites.model.TramiteLista;
import com.portaltramites.model.TipoContenido;
import com.portaltramites.repository.EntidadRepository;
import com.portaltramites.repository.TramiteRepository;
import com.portaltramites.repository.TipoContenidoRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Catálogo completo en memoria. Con la BD en la nube (Aiven) cada consulta al
 * BD cuesta ~0.4-2 s de latencia de red, asi el backend carga TODO el
 * catalogo (275 trámites + etiquetas + requisitos + catálogos) en UNA ronda
 * de consultas al arrancar, y sirve listados, búsqueda, detalle y relacionados
 * desde memoria con CERO consultas por petición. Los datos son estáticos
 * (se cargan desde bd/bd_tramites.sql), por lo que basta un refresco
 * periódico simple.
 */
@Service
@RequiredArgsConstructor
public class CatalogoService {

    private static final Logger log = LoggerFactory.getLogger(CatalogoService.class);

    /** Tiempo de vida del snapshot (los datos del curso son estáticos). */
    private static final long TTL_MS = 10 * 60 * 1000;

    private final TramiteRepository tramiteRepository;
    private final EntidadRepository entidadRepository;
    private final TipoContenidoRepository tipoContenidoRepository;

    /**
     * Instantánea completa del catálogo. Etiquetas/requisitos indexados por
     * id de trámite para resolución O(1) en búsqueda y detalle.
     */
    public record Snapshot(
            List<TramiteLista> activos,
            Map<Integer, List<String>> etiquetasPor,
            Map<Integer, List<RequisitoDe>> requisitosPor,
            List<Entidad> entidades,
            List<TipoContenido> tipos) {
    }

    private volatile Snapshot snap;
    private volatile long cargadoEnMs = 0L;

    /** Devuelve el snapshot vigente, recargándolo si venció el TTL. */
    public synchronized Snapshot snapshot() {
        if (snap == null || System.currentTimeMillis() - cargadoEnMs > TTL_MS) {
            cargar();
        }
        return snap;
    }

    /**
     * Precarga en un hilo aparte al terminar el arranque: así la primera
     * carga de la BD en la nube no golpea al primer usuario.
     */
    @EventListener(ApplicationReadyEvent.class)
    public void precargar() {
        Thread hilo = new Thread(() -> {
            try {
                snapshot();
                log.info("Catálogo precargado: {} trámites activos",
                        snap != null ? snap.activos().size() : 0);
            } catch (Exception e) {
                log.warn("Precarga del catálogo difirió (se reintentará al primer pedido): {}",
                        e.getMessage());
            }
        }, "catalogo-precarga");
        hilo.setDaemon(true);
        hilo.start();
    }

    private void cargar() {
        List<TramiteLista> activos = tramiteRepository.listarActivos();

        Map<Integer, List<String>> etiquetas = new HashMap<>();
        for (TramiteEtiqueta par : tramiteRepository.listarParesEtiqueta()) {
            etiquetas.computeIfAbsent(par.idTramite(), k -> new ArrayList<>()).add(par.etiqueta());
        }

        Map<Integer, List<RequisitoDe>> requisitos = new HashMap<>();
        for (RequisitoDe par : tramiteRepository.listarParesRequisito()) {
            requisitos.computeIfAbsent(par.idTramite(), k -> new ArrayList<>()).add(par);
        }
        requisitos.values().forEach(l -> l.sort(Comparator.comparingInt(RequisitoDe::orden)));

        snap = new Snapshot(
                activos, etiquetas, requisitos,
                entidadRepository.findByActivoTrueOrderByNombreAsc(),
                tipoContenidoRepository.findByActivoTrueOrderByNombreAsc());
        cargadoEnMs = System.currentTimeMillis();
        log.info("Catálogo cargado en memoria: {} trámites, {} entidades, {} tipos",
                activos.size(), snap.entidades().size(), snap.tipos().size());
    }
}
