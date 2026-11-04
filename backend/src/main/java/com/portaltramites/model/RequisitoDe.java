package com.portaltramites.model;

/** Par trámite-requisito devuelto por una única consulta al BD. */
public record RequisitoDe(Integer idTramite, Integer idRequisito, Integer orden, String descripcion) {
}
