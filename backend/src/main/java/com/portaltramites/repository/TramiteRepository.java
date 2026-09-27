package com.portaltramites.repository;

import com.portaltramites.model.Tramite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TramiteRepository extends JpaRepository<Tramite, Integer>, JpaSpecificationExecutor<Tramite> {

    /**
     * Documentos/trámites relacionados: comparten al menos una etiqueta con el
     * trámite de referencia, ordenados por cantidad de etiquetas compartidas
     * (de mayor a menor relevancia).
     */
    @Query(value = """
            SELECT t.* FROM tramite t
            JOIN tramite_etiqueta te1 ON te1.id_tramite = :idTramite
            JOIN tramite_etiqueta te2 ON te2.id_etiqueta = te1.id_etiqueta
                                     AND te2.id_tramite <> :idTramite
            WHERE t.id_tramite = te2.id_tramite
              AND t.activo = 1
            GROUP BY t.id_tramite, t.id_entidad, t.id_tipo, t.nombre, t.descripcion,
                     t.url_oficial, t.modalidad, t.costo, t.activo,
                     t.fecha_registro, t.fecha_actualizacion
            ORDER BY COUNT(*) DESC
            LIMIT :limite
            """, nativeQuery = true)
    List<Tramite> findRelacionadosPorEtiquetas(@Param("idTramite") Integer idTramite,
                                               @Param("limite") int limite);
}
