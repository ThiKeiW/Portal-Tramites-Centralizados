package com.portaltramites.service;

import com.portaltramites.error.RecursoNoEncontradoException;
import com.portaltramites.error.SolicitudInvalidaException;
import com.portaltramites.model.Modalidad;
import com.portaltramites.model.Requisito;
import com.portaltramites.model.Tramite;
import com.portaltramites.repository.RequisitoRepository;
import com.portaltramites.repository.TramiteRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TramiteService {

    private static final int LIMITE_RELACIONADOS_POR_DEFECTO = 3;

    private final TramiteRepository tramiteRepository;
    private final RequisitoRepository requisitoRepository;

    /**
     * Búsqueda con filtros opcionales: texto (nombre/descripción), entidad (siglas),
     * tipo (TRAMITE/SERVICIO/REPORTE/GUIA) y modalidad.
     */
    @Transactional(readOnly = true)
    public List<Tramite> buscar(String q, String entidad, String tipo, String modalidad) {
        Specification<Tramite> spec = (root, query, cb) -> {
            List<Predicate> predicados = new ArrayList<>();

            predicados.add(cb.isTrue(root.get("activo")));

            if (q != null && !q.isBlank()) {
                String patron = "%" + q.trim().toLowerCase() + "%";
                Predicate porNombre = cb.like(cb.lower(root.get("nombre")), patron);
                Predicate porDescripcion = cb.like(cb.lower(root.get("descripcion")), patron);
                predicados.add(cb.or(porNombre, porDescripcion));
            }
            if (entidad != null && !entidad.isBlank()) {
                predicados.add(cb.equal(
                        cb.lower(root.get("entidad").get("siglas")),
                        entidad.trim().toLowerCase()));
            }
            if (tipo != null && !tipo.isBlank()) {
                predicados.add(cb.equal(root.get("tipo").get("nombre"), tipo.trim().toUpperCase()));
            }
            if (modalidad != null && !modalidad.isBlank()) {
                predicados.add(cb.equal(root.get("modalidad"), parsearModalidad(modalidad)));
            }

            return cb.and(predicados.toArray(new Predicate[0]));
        };

        return tramiteRepository.findAll(spec, Sort.by(Sort.Direction.ASC, "nombre"));
    }

    @Transactional(readOnly = true)
    public Tramite obtenerPorId(Integer id) {
        return tramiteRepository.findById(id)
                .filter(Tramite::getActivo)
                .orElseThrow(() -> new RecursoNoEncontradoException(
                        "Trámite no encontrado con id: " + id));
    }

    @Transactional(readOnly = true)
    public List<Requisito> requisitos(Integer tramiteId) {
        obtenerPorId(tramiteId);
        return requisitoRepository.findByTramiteIdOrderByOrdenAsc(tramiteId);
    }

    /**
     * Documentos/trámites relacionados por etiquetas compartidas,
     * ordenados por la cantidad de etiquetas en común.
     */
    @Transactional(readOnly = true)
    public List<Tramite> relacionados(Integer tramiteId, Integer limite) {
        obtenerPorId(tramiteId);
        int efectivo = (limite == null) ? LIMITE_RELACIONADOS_POR_DEFECTO : limite;
        return tramiteRepository.findRelacionadosPorEtiquetas(tramiteId, efectivo);
    }

    private Modalidad parsearModalidad(String valor) {
        for (Modalidad m : Modalidad.values()) {
            if (m.name().equalsIgnoreCase(valor.trim())) {
                return m;
            }
        }
        throw new SolicitudInvalidaException(
                "Modalidad inválida: '" + valor + "'. Valores permitidos: VIRTUAL, PRESENCIAL, SEMIPRESENCIAL");
    }
}
