-- =====================================================================
-- PORTAL ÚNICO DE TRÁMITES PERUANOS (Avance 1 - Proyecto IHM)
-- Modelo de base de datos en MySQL 8.x
-- Organiza y filtra trámites/servicios/documentos/guías por entidad
-- =====================================================================

DROP DATABASE IF EXISTS portal_tramites_db;
CREATE DATABASE portal_tramites_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE portal_tramites_db;

-- =====================================================================
-- 1. ENTIDAD: Entidades públicas del Perú que se van a definir
-- =====================================================================
CREATE TABLE IF NOT EXISTS entidad (
    id_entidad          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    nombre              VARCHAR(120)     NOT NULL COMMENT 'Nombre completo de la entidad',
    siglas              VARCHAR(20)      NOT NULL COMMENT 'SUNAT, MINEDU, RENIEC, ESSALUD...',
    sector              VARCHAR(80)      NULL COMMENT 'Sector al que pertenece (Economía, Educación, Salud...)',
    descripcion         VARCHAR(500)     NULL COMMENT 'Breve descripción de la entidad',
    sitio_web           VARCHAR(255)     NOT NULL COMMENT 'URL de la página oficial de la entidad',
    activo              TINYINT(1)       NOT NULL DEFAULT 1 COMMENT '1 = visible en el portal, 0 = oculta',
    fecha_registro      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_entidad),
    UNIQUE KEY uq_entidad_siglas (siglas),
    UNIQUE KEY uq_entidad_nombre (nombre)
) ENGINE = InnoDB COMMENT = 'Catálogo de entidades públicas';

-- =====================================================================
-- 2. TIPO_CONTENIDO: Clasificación (Alcance: trámites, servicios,
--    reportes, documentos y guías)
-- =====================================================================
CREATE TABLE IF NOT EXISTS tipo_contenido (
    id_tipo             INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    nombre              VARCHAR(50)      NOT NULL COMMENT 'TRAMITE | SERVICIO | REPORTE | DOCUMENTO | GUIA',
    descripcion         VARCHAR(255)     NULL,
    activo              TINYINT(1)       NOT NULL DEFAULT 1,
    PRIMARY KEY (id_tipo),
    UNIQUE KEY uq_tipo_nombre (nombre)
) ENGINE = InnoDB COMMENT = 'Tipos de contenido centralizado';

-- =====================================================================
-- 3. TRAMITE (tabla de detalle): Contenido centralizado. Incluye los
--    REQUISITOS según el documento y la URL de la página oficial.
-- =====================================================================
CREATE TABLE IF NOT EXISTS tramite (
    id_tramite          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    id_entidad          INT UNSIGNED     NOT NULL COMMENT 'Entidad responsable del trámite',
    id_tipo             INT UNSIGNED     NOT NULL COMMENT 'Tipo de contenido (trámite, guía, etc.)',
    nombre              VARCHAR(200)     NOT NULL COMMENT 'Nombre del trámite / contenido',
    descripcion         TEXT             NULL COMMENT 'Descripción general',
    requisitos          TEXT             NOT NULL COMMENT 'Requisitos necesarios para el trámite',
    url_oficial         VARCHAR(255)     NOT NULL COMMENT 'URL de la página oficial del trámite',
    modalidad           ENUM('VIRTUAL','PRESENCIAL','SEMIPRESENCIAL') NOT NULL DEFAULT 'VIRTUAL',
    costo               DECIMAL(10, 2)   NOT NULL DEFAULT 0.00 COMMENT 'Costo en soles (TUPA)',
    activo              TINYINT(1)       NOT NULL DEFAULT 1,
    fecha_registro      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_tramite),
    KEY fk_tramite_entidad (id_entidad),
    KEY fk_tramite_tipo (id_tipo),
    CONSTRAINT fk_tramite_entidad FOREIGN KEY (id_entidad) REFERENCES entidad (id_entidad),
    CONSTRAINT fk_tramite_tipo    FOREIGN KEY (id_tipo)    REFERENCES tipo_contenido (id_tipo),
    FULLTEXT KEY ft_tramite_busqueda (nombre, descripcion, requisitos) COMMENT 'Soporta búsqueda textual'
) ENGINE = InnoDB COMMENT = 'Tabla de detalle: trámites y contenidos centralizados';

-- =====================================================================
-- 4. ETIQUETA / TRAMITE_ETIQUETA: Etiquetado para filtrado y búsqueda
--    por voz (Marco teórico: arquitectura de información)
-- =====================================================================
CREATE TABLE IF NOT EXISTS etiqueta (
    id_etiqueta         INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    nombre              VARCHAR(60)      NOT NULL COMMENT 'Ej.: dni, declaracion, cita, certificado',
    PRIMARY KEY (id_etiqueta),
    UNIQUE KEY uq_etiqueta_nombre (nombre)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS tramite_etiqueta (
    id_tramite          INT UNSIGNED     NOT NULL,
    id_etiqueta         INT UNSIGNED     NOT NULL,
    PRIMARY KEY (id_tramite, id_etiqueta),
    CONSTRAINT fk_te_tramite FOREIGN KEY (id_tramite)  REFERENCES tramite (id_tramite)   ON DELETE CASCADE,
    CONSTRAINT fk_te_etiqueta FOREIGN KEY (id_etiqueta) REFERENCES etiqueta (id_etiqueta) ON DELETE CASCADE
) ENGINE = InnoDB COMMENT = 'Relación N:M trámite - etiqueta';

-- =====================================================================
-- 5. BUSQUEDA: Registro de búsquedas (texto y voz con Deepgram),
--    guarda la transcripción, la intención detectada y la redirección
-- =====================================================================
CREATE TABLE IF NOT EXISTS busqueda (
    id_busqueda          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    origen               ENUM('TEXTO','VOZ') NOT NULL DEFAULT 'TEXTO',
    texto_transcrito     VARCHAR(255)    NULL COMMENT 'Consulta transcrita por Deepgram',
    intencion_detectada  VARCHAR(255)    NULL COMMENT 'Intención reconocida por la API',
    id_tramite_redirect  INT UNSIGNED    NULL COMMENT 'Trámite/página al que se redirigió',
    fecha                TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_busqueda),
    KEY fk_busqueda_tramite (id_tramite_redirect),
    CONSTRAINT fk_busqueda_tramite FOREIGN KEY (id_tramite_redirect) REFERENCES tramite (id_tramite) ON DELETE SET NULL
) ENGINE = InnoDB COMMENT = 'Bitácora de búsquedas textuales y por voz';

-- =====================================================================
-- DATOS INICIALES
-- =====================================================================
INSERT INTO entidad (nombre, siglas, sector, descripcion, sitio_web) VALUES
('Superintendencia Nacional de Aduanas y de Administración Tributaria', 'SUNAT',   'Economía y Finanzas', 'Entidad encargada de la recaudación tributaria y el control aduanero del Perú.', 'https://www.sunat.gob.pe'),
('Ministerio de Educación',                                             'MINEDU',  'Educación',           'Entidad rectora de la política educativa peruana.',                               'https://www.gob.pe/minedu'),
('Registro Nacional de Identificación y Estado Civil',                  'RENIEC',  'Interior',            'Entidad encargada de la identificación de las personas (DNI) y registros civiles.', 'https://www.gob.pe/reniec'),
('Seguridad Social',                                                    'ESSALUD', 'Salud',               'Entidad de seguridad social que brinda prestaciones de salud y económicas.',      'https://www.essalud.gob.pe'),
('Superintendencia Nacional de los Registros Públicos',                 'SUNARP',  'Justicia',            'Entidad encargada de los registros públicos del Perú.',                           'https://www.gob.pe/sunarp'),
('Superintendencia Nacional de Migraciones',                            'MIGRACIONES', 'Interior',        'Entidad encargada de la migración y el control de extranjeros.',                  'https://www.gob.pe/migraciones');

INSERT INTO tipo_contenido (nombre, descripcion) VALUES
('TRAMITE',   'Procedimientos administrativos ante entidades públicas'),
('SERVICIO',  'Servicios en línea ofrecidos por las entidades'),
('REPORTE',   'Reportes y estadísticas oficiales'),
('DOCUMENTO', 'Documentos y normativas oficiales'),
('GUIA',      'Guías paso a paso para el ciudadano');

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, requisitos, url_oficial, modalidad, costo) VALUES
(3, 1, 'DNI por primera vez', 'Trámite para obtener el Documento Nacional de Identidad por primera vez para mayores de edad.', '1) Solicitud de DNI (F-200) debidamente llenado. 2) Certificado de nacimiento original. 3) Recibo de pago por derecho de trámite. 4) Fotografía fondo blanco.', 'https://www.gob.pe/institucion/reniec/servicios', 'PRESENCIAL', 52.00),
(1, 1, 'Declaración y pago mensual - PDT 621', 'Declaración mensual de impuestos (IGV e Impuesto a la Renta) para regímenes general y MYPE.', '1) Clave SOL habilitada. 2) Código de libro donde registra las operaciones. 3) Registro de ventas y compras del mes. 4) Constancia de cuenta bancaria (para pagos).', 'https://www.sunat.gob.pe/declaracion-y-pago', 'VIRTUAL', 0.00),
(2, 5, 'Trámite de reconocimiento de estudios', 'Guía para el reconocimiento de grados y títulos extranjeros de educación superior.', '1) Título o grado apostillado o legalizado. 2) Certificados de estudios legalizados. 3) Documento de identidad vigente. 4) Traducción oficial (si aplica).', 'https://www.gob.pe/minedu', 'VIRTUAL', 214.00),
(4, 2, 'Cita médica en línea', 'Servicio para reservar citas médicas en centros asistenciales de EsSalud.', '1) Número de asegurado (Documento de identidad). 2) Ingresar al portal de citas en línea. 3) Seleccionar especialidad y médico.', 'https://www.essalud.gob.pe', 'VIRTUAL', 0.00),
(5, 1, 'Inscripción de partida registral (predios)', 'Trámite de inscripción inicial de predios en el Registro de Propiedad Inmueble.', '1) Formato de solicitud registral. 2) Título de propiedad. 3) Recibo de pago por derecho de trámite. 4) Planos y memoria descriptiva (si aplica).', 'https://www.gob.pe/sunarp', 'PRESENCIAL', 122.00),
(6, 1, 'Pasaporte electrónico', 'Trámite para la obtención del pasaporte electrónico peruano.', '1) DNI vigente (azul o electrónico). 2) Recibo de pago por derecho de trámite. 3) Solicitud en línea previa a la cita.', 'https://www.gob.pe/migraciones', 'SEMIPRESENCIAL', 98.50);

INSERT INTO etiqueta (nombre) VALUES
('dni'), ('declaracion'), ('impuestos'), ('cita'), ('educacion'), ('pasaporte'), ('registros'), ('salud');

INSERT INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES
(1, 1), (1, 7), (2, 2), (2, 3), (3, 5), (4, 4), (4, 8), (5, 7), (6, 6);

-- =====================================================================
-- CONSULTAS DE VERIFICACIÓN
-- =====================================================================
-- Trámites por entidad con tipo y URL oficial
SELECT e.siglas, t.nombre AS tramite, tc.nombre AS tipo, t.requisitos, t.url_oficial
FROM tramite t
JOIN entidad e        ON e.id_entidad = t.id_entidad
JOIN tipo_contenido tc ON tc.id_tipo   = t.id_tipo
WHERE t.activo = 1
ORDER BY e.siglas, t.nombre;

-- Búsqueda textual sobre la tabla de detalle
SELECT id_tramite, nombre, MATCH(nombre, descripcion, requisitos) AGAINST('dni' IN NATURAL LANGUAGE MODE) AS relevancia
FROM tramite
WHERE MATCH(nombre, descripcion, requisitos) AGAINST('dni' IN NATURAL LANGUAGE MODE);
