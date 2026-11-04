package com.portaltramites.model;

import java.math.BigDecimal;

/**
 * Vista ligera de trámite para listados (/api/tramites, /relacionados y la
 * búsqueda por texto/voz): solo lo que la interfaz consume en tarjetas y
 * filtros (id, nombre, descripción, url, modalidad, costo, entidad y tipo).
 * Excluye requisitos y etiquetas para que el listado sea una única consulta
 * al BD sin N+1, crítica con la BD en la nube (Aiven) por la latencia de red.
 */
public record TramiteLista(
        Integer id,
        String nombre,
        String descripcion,
        String urlOficial,
        Modalidad modalidad,
        BigDecimal costo,
        String entidadSiglas,
        String entidadNombre,
        String tipoNombre) {
}
