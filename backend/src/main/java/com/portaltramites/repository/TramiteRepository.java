package com.portaltramites.repository;

import com.portaltramites.model.Tramite;
import com.portaltramites.model.TramiteEtiqueta;
import com.portaltramites.model.TramiteLista;
import com.portaltramites.model.RequisitoDe;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface TramiteRepository extends JpaRepository<Tramite, Integer> {

    /**
     * Listado ligero de todos los trámites activos en UNA sola consulta
     * (en vez de {@code findAll()}, que materializa las colecciones EAGER
     * requisitos/etiquetas de cada trámite en consultas separadas: 550+
     * round-trips con BD remota). Ordenado A–Z.
     */
    @Query("""
            select new com.portaltramites.model.TramiteLista(
                t.id, t.nombre, t.descripcion, t.urlOficial, t.modalidad, t.costo,
                e.siglas, e.nombre, tc.nombre)
            from Tramite t
            join t.entidad e
            join t.tipo tc
            where t.activo = true
            order by t.nombre asc
            """)
    List<TramiteLista> listarActivos();

    /**
     * Pares trámite-etiqueta de los activos en UNA sola consulta (antes cada
     * {@code trámite.getEtiquetas()} era una consulta por trámite).
     */
    @Query("""
            select new com.portaltramites.model.TramiteEtiqueta(t.id, e.nombre)
            from Tramite t
            join t.etiquetas e
            where t.activo = true
            """)
    List<TramiteEtiqueta> listarParesEtiqueta();

    /**
     * Pares trámite-requisito de los activos en UNA sola consulta (permite
     * armar el detalle sin recorrer la entidad completa y sus colecciones).
     */
    @Query("""
            select new com.portaltramites.model.RequisitoDe(t.id, r.id, r.orden, r.descripcion)
            from Tramite t
            join t.requisitos r
            where t.activo = true
            """)
    List<RequisitoDe> listarParesRequisito();
}
