package com.portaltramites.model;

import java.math.BigDecimal;
import java.util.List;

/**
 * Vista completa de un trámite para la pantalla de detalle: mismos campos
 * ligeros del listado + sus requisitos. Se construye desde el catálogo en
 * memoria (CatalogoService), asi la respuesta no ejecuta consultas al BD.
 */
public record TramiteDetalle(
        Integer id,
        String nombre,
        String descripcion,
        String urlOficial,
        Modalidad modalidad,
        BigDecimal costo,
        String entidadSiglas,
        String entidadNombre,
        String tipoNombre,
        List<RequisitoVista> requisitos) {
}
