package com.portaltramites.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "busqueda")
@Getter
@Setter
@NoArgsConstructor
public class Busqueda {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_busqueda")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private OrigenBusqueda origen;

    @Column(name = "texto_transcrito", length = 255)
    private String textoTranscrito;

    @Column(name = "intencion_detectada", length = 255)
    private String intencionDetectada;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_tramite_redirect")
    private Tramite tramiteRedirect;

    @Column(insertable = false, updatable = false)
    private LocalDateTime fecha;
}
