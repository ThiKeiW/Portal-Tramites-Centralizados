package com.portaltramites.model;

/**
 * Par trámite-etiqueta devuelto por una única consulta al BD, usado para
 * construir el indice de búsqueda (puntajes con IDF) sin recorrer entidades
 * completas.
 */
public record TramiteEtiqueta(Integer idTramite, String etiqueta) {
}
