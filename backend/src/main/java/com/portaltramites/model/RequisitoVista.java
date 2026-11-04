package com.portaltramites.model;

/** Requisito ligero para respuestas JSON (sin la FK al trámite). */
public record RequisitoVista(Integer id, Integer orden, String descripcion) {
}
