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
    url_oficial         VARCHAR(512)     NOT NULL COMMENT 'URL de la página oficial del trámite',
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
    FULLTEXT KEY ft_tramite_busqueda (nombre, descripcion) COMMENT 'Soporta búsqueda textual'
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

CREATE TABLE IF NOT EXISTS requisito (
    id_requisito   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    id_tramite     INT UNSIGNED  NOT NULL COMMENT 'Trámite al que pertenece el requisito',
    orden          TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Orden de presentación (1, 2, 3...)',
    descripcion    VARCHAR(300)  NOT NULL COMMENT 'Texto del requisito individual',
    PRIMARY KEY (id_requisito),
    KEY fk_requisito_tramite (id_tramite),
    CONSTRAINT fk_requisito_tramite
        FOREIGN KEY (id_tramite) REFERENCES tramite (id_tramite)
        ON DELETE CASCADE
) ENGINE = InnoDB COMMENT = 'Requisitos individuales por trámite (normalizado, 1:N)';

ALTER TABLE requisito ADD FULLTEXT KEY ft_requisito_busqueda (descripcion);
-- =====================================================================
-- DATOS INICIALES
-- =====================================================================
INSERT INTO entidad (nombre, siglas, sector, descripcion, sitio_web) VALUES
('Registro Nacional de Identificación y Estado Civil', 'RENIEC', 'Interior', 'Entidad encargada de la identificación de las personas (DNI) y registros civiles.', 'https://www.gob.pe/reniec'),
('Superintendencia Nacional de Aduanas y de Administración Tributaria', 'SUNAT', 'Economía y Finanzas', 'Entidad encargada de la recaudación tributaria y el control aduanero del Perú.', 'https://www.sunat.gob.pe'),
('Superintendencia Nacional de Migraciones', 'MIGRACIONES', 'Interior', 'Entidad encargada de la migración y el control de extranjeros.', 'https://www.gob.pe/migraciones'),
('Seguridad Social', 'ESSALUD', 'Salud', 'Entidad de seguridad social que brinda prestaciones de salud y económicas.', 'https://www.essalud.gob.pe'),
('Superintendencia Nacional de los Registros Públicos', 'SUNARP', 'Justicia', 'Entidad encargada de los registros públicos del Perú.', 'https://www.gob.pe/sunarp'),
('Ministerio de Educación', 'MINEDU', 'Educación', 'Entidad rectora de la política educativa peruana.', 'https://www.gob.pe/minedu'),
('Ministerio de Transportes y Comunicaciones', 'MTC', 'Transportes y Comunicaciones', 'Entidad rectora de las políticas de transporte terrestre, aéreo, acuático y comunicaciones.', 'https://www.mtc.gob.pe'),
('Ministerio del Interior', 'MININTER', 'Interior', 'Entidad rectora del orden interno, el orden público y la seguridad ciudadana.', 'https://www.gob.pe/mininter'),
('Poder Judicial', 'PJ', 'Justicia', 'Órgano jurisdiccional encargado de administrar justicia en el Perú.', 'https://www.gob.pe/pj'),
('Ministerio de Justicia y Derechos Humanos', 'MINJUS', 'Justicia', 'Entidad rectora en materia de justicia y derechos humanos.', 'https://www.gob.pe/minjus'),
('Seguro Integral de Salud', 'SIS', 'Salud', 'Seguro público que financia prestaciones de salud para la población sin seguro.', 'https://www.gob.pe/sis'),
('Ministerio de Salud', 'MINSA', 'Salud', 'Entidad rectora del sistema de salud del Perú.', 'https://www.minsa.gob.pe'),
('Oficina de Normalización Previsional', 'ONP', 'Economía y Finanzas', 'Administra el Sistema Nacional de Pensiones y otros regímenes previsionales a cargo del Estado.', 'https://www.onp.gob.pe'),
('Ministerio de Desarrollo e Inclusión Social', 'MIDIS', 'Desarrollo e Inclusión Social', 'Entidad rectora de la política social y de los programas de lucha contra la pobreza.', 'https://www.gob.pe/midis'),
('Superintendencia Nacional de Fiscalización Laboral', 'SUNAFIL', 'Trabajo', 'Supervisa y fiscaliza el cumplimiento del ordenamiento sociolaboral y de seguridad en el trabajo.', 'https://www.sunafil.gob.pe'),
('Ministerio de Trabajo y Promoción del Empleo', 'MTPE', 'Trabajo', 'Entidad rectora en materia de trabajo, promoción del empleo y derechos laborales.', 'https://www.gob.pe/mtpe'),
('Instituto Nacional de Defensa de la Competencia y de la Protección de la Propiedad Intelectual', 'INDECOPI', 'Presidencia del Consejo de Ministros', 'Protege los derechos de los consumidores y promueve la libre y leal competencia.', 'https://www.gob.pe/indecopi'),
('Superintendencia de Banca, Seguros y AFP', 'SBS', 'Economía y Finanzas', 'Supervisa los sistemas financiero, de seguros y privado de pensiones.', 'https://www.sbs.gob.pe'),
('Jurado Nacional de Elecciones', 'JNE', 'Electoral', 'Fiscaliza la legalidad de los procesos electorales y administra justicia en materia electoral.', 'https://www.jne.gob.pe'),
('Oficina Nacional de Procesos Electorales', 'ONPE', 'Electoral', 'Organiza y ejecuta los procesos electorales, referéndums y consultas populares del país.', 'https://www.onpe.gob.pe');

INSERT INTO tipo_contenido (nombre, descripcion) VALUES
('TRAMITE',   'Procedimientos administrativos ante entidades públicas'),
('SERVICIO',  'Servicios en línea ofrecidos por las entidades'),
('REPORTE',   'Reportes y estadísticas oficiales'),
('GUIA',      'Guías paso a paso para el ciudadano');

INSERT IGNORE INTO etiqueta (nombre) VALUES
('aduanas'),
('capacitacion'),
('citas'),
('contrataciones'),
('dni'),
('electoral'),
('empresas'),
('identidad'),
('impuestos'),
('pagos'),
('plataforma-virtual'),
('reclamos'),
('registros'),
('salud'),
('seguridad'),
('transparencia'),
('vehicular');

-- REVISAR (RENIEC / 3.er Proceso de Evaluación y Certificación de Competencias d): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  '3.er Proceso de Evaluación y Certificación de Competencias del estándar “Ejecutar Procedimientos Registrales Civiles”',
  'El Reniec, como entidad certificadora, convoca a nivel nacional a este proceso para evaluar y certificar las competencias en procedimientos registrales civiles. Está dirigido a personas con más de un año de experiencia en trámites registrales civiles, desarrollada durante los...',
  'https://app.sineace.gob.pe/sigice/Proceso_PersonaCertificada/frmRegistroPersonas_DG_V2.aspx?id=MQAxADMANQA=',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ficha de inscripción:Debes completar tus datos personales, de contacto, laborales y de formación en el aplicativo.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Documentos de experiencia:Debes presentar documentos que demuestren un año de experiencia como mínimo ejecutando trámites de registros civiles. La experiencia debe haberse desarrollado dentro de los últimos 10 años. Los documentos válidos incluyen contratos de trabajo, certificados, constancias, bol');

-- REVISAR (RENIEC / Acceder a la información sobre quién consultó tu DNI): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Guía de Usuario Mesa de Partes Virtual',
  'La aplicación Mesa de Partes Virtual del Portal institucional del RENIEC, permite a ciudadanos y presentantes, ingresar sus documentos y anexos a través de un canal digital establecido',
  'https://apps.reniec.gob.pe/MesaPartesVirtual/recursos/pdf/INSTRUCTIVO_MPV.pdf?1790439661479',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (RENIEC / Acceder a las Convocatorias de Bienes y Servicios para Proce): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a las Convocatorias de Bienes y Servicios para Procesos Electorales 2026',
  'Te invitamos a participar en los procesos de selección para la contratación de bienes y servicios valorizados en más de 8 Unidades Impositivas Tributarias (UIT), necesarios para los procesos electorales 2026.¿Cómo participar?Para promover la libre concurrencia y una...',
  'https://identidad.reniec.gob.pe/contrataciones-de-bienes-y-servicios?p_l_back_url=%2Fbuscador%3F_com_liferay_portal_search_web_search_bar_portlet_SearchBarPortlet_INSTANCE_yshb_formDate%3D1757721465534%26emptySearchEnabled%3Dfalse%26q%3Dconvocatoria%26scope%3D',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ver requisitos en la convocatoria vigente');

-- REVISAR (RENIEC / Acceder al Repositorio Institucional del Reniec): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Repositorio Institucional del Reniec',
  'El Repositorio Institucional del RENIEC es un archivo digital diseñado para centralizar, preservar y difundir la producción académica, científica y técnica generada por la institución. Este espacio busca democratizar el acceso a la información y consolidarse como un pilar...',
  'https://repositorio.reniec.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Dispositivo:Computadora de escritorio, laptop, tablet o teléfono celular.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Conexión a Internet:Para la navegación y descarga de archivos PDF.');

-- REVISAR (RENIEC / Actualizar PIN de seguridad): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Actualizar PIN de seguridad',
  'El PIN de seguridad del Documento Nacional de Identidad Electrónico (DNIe) es una contraseña personal de 6 dígitos que creas en las oficinas de RENIEC al recibir tu DNIe.Esta clave es de uso exclusivo del titular que protege el acceso a la información y funcionalidades de tu...',
  'https://www.gob.pe/99724-actualizar-pin-de-seguridad',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Contar con DNI electrónico');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Contar con lector de tarjetas digitales');

-- REVISAR (RENIEC / Agendar citas presenciales en línea): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Agendar citas presenciales en línea',
  'El Gestor de citas es la plataforma del RENIEC diseñada para que puedas programar tu atención presencial en centros de atención autorizados, exclusivo para trámites de DNI, previo pago de trámite en Yape, Agente BCP, Págalo.pe u oficinas del Banco de la Nación.¿Qué podrás...',
  'https://www.gob.pe/116789-agendar-citas-presenciales-en-linea',
  'PRESENCIAL',
  30.00
);
SET @tid = LAST_INSERT_ID();

INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Correo electrónico activo: Recibirás un código de validación en tu bandeja de entrada.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Pago del trámite: Debes realizar el pago antes de agendar tu cita presencial.');

-- REVISAR (RENIEC / Autenticar o certificar una constancia o acta de nacimiento,): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autenticar o certificar una constancia o acta de nacimiento, matrimonio o defunción',
  'Para autenticar o certificar la firma de un funcionario municipal que expide una constancia o acta de nacimiento, matrimonio o defunción en una municipalidad, la cual no está incorporada al sistema de Reniec, puedes solicitarlo en un Centro de Atención del Reniec.',
  'https://www.gob.pe/21230-autenticar-o-certificar-una-constancia-o-acta-de-nacimiento-matrimonio-o-defuncion',
  'PRESENCIAL',
  31.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formato de solicitud que te brindan en el centro de atención.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Copia certificada del acta registral o de la constancia por autenticar (No fotocopia).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Exhibir tu DNI si eres peruano, o carnet de extranjería, pasaporte o cédula de identidad si eres extranjero.');

-- REVISAR (RENIEC / Cambiar el lugar de entrega del DNI): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Cambiar el lugar de entrega del DNI',
  'Se pide cambiar el lugar de entrega del DNI Electrónico cuando deseas recogerlo en un Centro de Atención del RENIEC distinto de dónde iniciaste el trámite. Esto se hace cuando estás haciendo tu rectificación, duplicado, emisión o renovación de tu DNI de manera presencial.  El...',
  'https://www.gob.pe/256-cambiar-el-lugar-de-entrega-del-dni',
  'PRESENCIAL',
  5.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formato de Solicitud suscrita con carácter de Declaración Jurada para hacer el cambio de lugar de recojo emitido enCentro de Atención del RENIEC');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Recibo de Pago por Derechos Administrativos.');

-- REVISAR (RENIEC / Canjear Libreta Electoral por DNI electrónico): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Canjear Libreta Electoral por DNI electrónico',
  'Es el proceso que deben realizar las personas que tengan la Libreta Electoral como su documento de identidad y aún no cuenten con el DNI.Este trámite es gratuito.Debes hacerlo de manera presencial en un centro de atención del Reniec o un centro MAC.',
  'https://www.gob.pe/248-canjear-libreta-electoral-por-dni-electronico',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Recibo original de servicios públicos, tributo municipal o Declaración Jurada de Domicilio en caso no contar con servicios públicos en tu domicilio.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Para registrar tu  estado civil, presenta la documentación del Anexo Nº 2 del TUPA según tu caso.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Para registrar tu grado de instrucción presenta los documentos especificados en elAnexo Nº 4 del TUPAsegún tu caso.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'En caso de tener alguna discapacidad, debes firmar la Declaración Jurada de Discapacidad y Asistencia. Además, deberás agregar:');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Original y copia simple del Certificado de Discapacidad en el formato aprobado por el Minsa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Resolución Ejecutiva del Conadis.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 7, 'Constancia médica de discapacidad que señale la discapacidad física, sensorial, mental o  intelectual');

-- REVISAR (RENIEC / Consultar estado de tu trámite para la entrega de tu DNI): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar estado de tu trámite para la entrega de tu DNI',
  'Si necesitas consultar el estado del trámite de tu Documento Nacional de Identidad Electrónico (DNIe) de menor o adulto en cualquier momento del día, incluso hasta 1 mes después de que recibiste el documento, puedes hacerlo de manera online. El sistema te mostrará los...',
  'https://serviciosportal.reniec.gob.pe/cetdnipi/inicio.htm',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Conocer el número de DNI o número de solicitud.');

-- REVISAR (RENIEC / Consultar los horarios de centros de atención del RENIEC a n): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Consultar los horarios de centros de atención del RENIEC a nivel nacional',
  'El Reniec pone a disposición de la ciudadanía el listado actualizado de sus oficinas, agencias y puntos de atención en todo el país. En este documento podrás consultar la ubicación exacta y los horarios de atención regular para realizar tus trámites de identificación y...',
  'https://www.gob.pe/116858-consultar-los-horarios-de-centros-de-atencion-del-reniec-a-nivel-nacional',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (RENIEC / Consultar trámites rechazados en Consulados): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar trámites rechazados en Consulados',
  'Si eres un funcionario consular, autorizado por el Ministerio de Relaciones Exteriores y Reniec, puedes consultar con detalle los motivos por los cuales un trámite de emisión de DNI solicitado por un peruano en una oficina consultar ha sido rechazado.',
  'http://cie.reniec.gob.pe/cie/login.do?accion=ini',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Usuario y clave de acceso que solicitas mediante oficio a la Gerencia de Servicios de Valor Añadido de Reniec del Ministerio de Relaciones Exteriores.');

-- REVISAR (RENIEC / Generar ticket para pagos de trámite a través de Yape y Agen): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Generar ticket para pagos de trámite a través de Yape y Agente BCP',
  'La Ticketera RENIEC es una plataforma en línea que te permite generar un ticket de pago para realizar 14 trámites del RENIEC de forma segura y accesible a través del aplicativo Yape, o acercarte al Agente BCP más cercano para completar el pago. Conoce los trámites disponibles...',
  'https://recaudacion.reniec.gob.pe/recaudacionTasas/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Conocer el trámite que vas a realizar y el código correspondiente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Acceder a laTicketera RENIEC desde cualquier dispositivo con conexión a internet.');

-- REVISAR (RENIEC / Inscribir Modificaciones en Actas Registrales): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Inscribir reconocimiento de paternidad por escritura pública o testamento',
  'Este trámite permite ingresar la anotación marginal en el acta de nacimiento y otorga derecho a la rectificación de la misma.',
  'https://www.gob.pe/32989-inscribir-modificaciones-en-actas-registrales-inscribir-reconocimiento-de-paternidad-por-escritura-publica-o-testamento',
  'PRESENCIAL',
  12.30
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud suscrita con carácter de declaración jurada.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Parte notarial de otorgamiento de reconocimiento o protocolización del testamento.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Exhibir tu DNI.');

-- REVISAR (SUNAT / Acceder a la Calculadora Tributaria): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la Calculadora Tributaria',
  'Es una herramienta que te ayuda a conocer los intereses moratorios generados por pagar tus tributos, después de su vencimiento.',
  'http://e-consulta.sunat.gob.pe/cl-at-itcalculibre/actdeuS01Alias',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (SUNAT / Acceder a la atención de consultas en Redes Sociales): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la atención de consultas en Redes Sociales',
  'Si necesitas realizar consultas sobre temas tributarios y/o aduaneros, puedes hacerlo a través de la cuenta oficial de la SUNAT en Facebook. Mediante este canal, la Sunat ofrece orientación de carácter general, por tanto, no se brindarán respuestas a consultas personalizadas ni se resolverán casos específicos.',
  'https://www.gob.pe/93860-acceder-a-la-atencion-de-consultas-en-redes-sociales',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Contar con cuenta de Facebook');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Servicio activo de lunes a viernes en el horario de las 8:30 a. m. a 5:30 p. m');

-- REVISAR (SUNAT / Acceder a la información pública de la Sunat): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la información pública de la Sunat',
  'Si como persona natural o jurídica necesitas acceder a información pública de la Superintendencia Nacional de Aduanas y de Administración Tributaria (Sunat), puedes solicitarla de manera física o virtual, de acuerdo a la Ley 27806.',
  'http://www.sunat.gob.pe/ol-ti-itpresf5030/rsdS01Alias',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud de acceso a la información pública.');

-- REVISAR (SUNAT / Acceder a tu expediente electrónico de cobranza coactiva en ): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a tu expediente electrónico de cobranza coactiva en la Sunat',
  'Si tienes una deuda tributaria con la Sunat y te abrieron un procedimiento de cobranza coactiva, puedes consultar los documentos electrónicos emitidos por esta entidad en el Expediente Electrónico de Cobranza Coactiva.En este, se recopilan la Resolución de Ejecución de...',
  'https://ww3.sunat.gob.pe/sol.html',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Clave SOL.');

-- REVISAR (SUNAT / Acceder al Buzón SOL): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Buzón SOL',
  'Si deseas revisar las notificaciones que Sunat te ha enviado sobre el resultado o avance de un trámite con la entidad, puedes hacerlo a través del buzón electrónico.Los documentos y notificaciones que puedes ver en el buzón electrónico son:Órdenes de pago.Resoluciones de...',
  'https://api-seguridad.sunat.gob.pe/v1/clientessol/4f3b88b3-d9d6-402a-b85d-6a0bc857746a/oauth2/loginMenuSol?originalUrl=https://e-menu.sunat.gob.pe/cl-ti-itmenu/AutenticaMenuInternet.htm&state=rO0ABXNyABFqYXZhLnV0aWwuSGFzaE1hcAUH2sHDFmDRAwACRgAKbG9hZEZhY3RvckkACXRocmVzaG9sZHhwP0AAAAAAAAx3CAAAABAAAAADdAAEZXhlY3B0AAZwYXJhbXN0AEsqJiomL2NsLXRpLWl0bWVudS9NZW51SW50ZXJuZXQuaHRtJmI2NGQyNmE4YjVhZjA5MTkyM2IyM2I2NDA3YTFjMWRiNDFlNzMzYTZ0AANleGV0AAVidXpvbng=',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'RUC y Clave SOL.');

-- REVISAR (SUNAT / Acceder al Chat Sunat): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Chat Sunat',
  'Si necesitas realizar consultas sobre temas tributarios, aduaneros, informáticos, entre otros relacionados a la administración de la Sunat, puedes hacerlo a través de su chat virtual para obtener respuestas inmediatas de orientadores especializados.Para utilizar este servicio,...',
  'https://www.sunat.gob.pe/institucional/contactenos/chat-SUNAT-online.html',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Horario de atención de lunes a viernes de 8:30 a.m. a 6:00 p.m.');

-- REVISAR (SUNAT / Acceder al Nuevo RUS): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Nuevo RUS',
  'Por este procedimiento podrás elegir como régimen tributario al NRUS, cuando inicies tu negocio.  Para cumplir con tus obligaciones tributarias en éste régimen puedes hacerlo de este modo.',
  'https://www.gob.pe/1212-acceder-al-nuevo-rus',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ser persona natural o sucesión indivisa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'DNI vigente, Carnet de Extranjería, Carnet de Identidad, Carnet de Permiso Temporal de Permanencia o Pasaporte con calidad migratoria para la generación de renta de fuente peruana.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Si cuentas con representante legal, debes exhibir el DNI de éste.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Si vas a registrar una dirección distinta a la de tu DNI, debes presentar el original de tu DNI y cualquier documento privado o público en el que conste la dirección del domicilio fiscal.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Carta poder con firma legalizada notarialmente o autenticada por fedatario de SUNAT, que lo autorice expresamente a realizar el trámite de inscripción en el RUC.  (Si el trámite lo hace un tercero)');

-- REVISAR (SUNAT / Acceder al Programa de Envío de Información (PEI)): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Programa de Envío de Información (PEI)',
  'Si eres emisor electrónico y necesitas enviar archivos a la Sunat, puedes utilizar la plataforma Programa de Envío de Información (PEI).El PEI facilita el envío de información a través de archivos, permite hacer validaciones, obtener constancias de recepción de los archivos...',
  'https://cpe.sunat.gob.pe/sites/default/files/inline-files/PEI%20PARA%20WINDOWS_0.pdf',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'RUC.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Tener la información de los comprobantes a enviar (contingencia, percepción y retención u otros).');

-- REVISAR (SUNAT / Acceder al Régimen General): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Declarar y pagar impuestos en el Régimen General',
  'Es el procedimiento por el que registras los ingresos obtenidos por tu actividad empresarial dentro del régimen Régimen General como establecen las obligaciones tributarias.',
  'https://www.gob.pe/1173-declaracion-y-pago-del-impuesto-para-negocios-declaracion-y-pago-en-el-regimen-general',
  'SEMIPRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ventas e ingresos del mes (periodo a declarar).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Compras por adquisición de bienes y prestación de servicios del mes (periodo a declarar).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Saldo a favor del periodo anterior, de corresponder.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Monto de retenciones y percepciones del IGV que te efectuaron en el periodo y/o saldo de periodos anteriores .');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Coeficiente para el pago a cuenta mensual de renta, de corresponder.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Pagos previos, de corresponder (efectuados con boletas de pago).');

-- REVISAR (SUNAT / Acceder al Sistema de Despacho Aduanero (SDA)): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema de Despacho Aduanero (SDA)',
  'A través de esta plataforma digital puedes ingresar de manera directa a la opción de Operador de Comercio Exterior. Aquí podrás realizar trámites relacionados a las siguientes operaciones:
Manifiesto de carga de ingreso.
Despacho aduanero de ingreso.',
  'https://e-menu.sunat.gob.pe/cl-ti-itmenu/MenuInternet.htm?exe=ad',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'RUC y clave SOL.');

-- REVISAR (SUNAT / Acceder al Teledespacho): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Teledespacho',
  'Si eres operador de comercio exterior y necesitas enviar o recibir documentos de las Intendencias de Aduanas, puedes hacerlo de manera online a través del servicio Teledespacho.Este servicio te permite realizar tus despachos aduaneros de manera rápida y económica. Además,...',
  'http://www.sunat.gob.pe/ol-ad-pd/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Usuario y contraseña .');

-- REVISAR (SUNAT / Activar RUC de persona jurídica): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Activar RUC de persona jurídica',
  'Si has constituido tu empresa en Sunarp a través del sistema Sid-Sunarp, la entidad incluirá en tu ficha de inscripción un número RUC inactivo. Por ese motivo, debes activar tu RUC de persona jurídica virtualmente a través de Sunat Operaciones en Línea (SOL).',
  'https://e-menu.sunat.gob.pe/cl-ti-itmenu/MenuInternet.htm',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Clave SOL. Si no la tienes, trámitala a través de Sunat Virtual del App Personas.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Información de la empresa como nombre comercial, fecha de inicio de actividades, actividad principal y secundaria, dirección de domicilio fiscal, datos de contacto, entre otros.');

-- REVISAR (ESSALUD / Acceder a la Plataforma VIVA): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la Plataforma VIVA',
  'Es una Oficina Virtual desde donde el asegurado o representante de empresa puede acceder desde cualquier dispositivo electrónico con internet (computadora, tablet o teléfono móvil) los 365 días del año y las 24 horas del día, para realizar consultas y transacciones...',
  'https://viva.essalud.gob.pe/viva/login',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Contar con acreditación vigente del Seguro EsSalud.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Documento de identidad (DNI), Pasaporte, Carnet de Extranjería (CE) o  Permiso Temporal de permanencia (PTP).');

-- REVISAR (ESSALUD / Acreditación de tu seguro en EsSalud): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acreditación de tu seguro en EsSalud',
  'Sirve para demostrar que eres afiliado activo de EsSalud cuando el sistema muestre que no lo eres.',
  'https://www.gob.pe/52303-acreditacion-de-tu-seguro-en-essalud',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI, certificado de extranjería, permiso temporal de permanencia');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Si eres trabajador regular (dependiente), presenta tu última boleta o penúltima boleta de remuneración.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Si eres trabajadora del hogar, presenta tus tres últimos recibos de pago del seguro.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Si erespensionista,presenta tu resolución de pensionista');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Si eres beneficiario de la Ley 30425, presenta tu constancia de retiro');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Si eres afiliado al seguro independiente, presenta tu recibo del último pago realizado');

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Oficinas de Seguros y Prestaciones Económicas (OSPE)',
  'Puedes observar las sedes que se encuentran activas. En nuestras OSPE, puedes realizar trámites de afiliación, recibir orientación sobre los seguros administrados por EsSalud y gestionar tus prestaciones económicas.',
  'https://www.gob.pe/114429-oficinas-de-seguros-y-prestaciones-economicas-ospe',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (ESSALUD / Consultar dónde atenderte en EsSalud): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar dónde atenderte en EsSalud',
  'Si necesitas verificar el tipo y vigencia de tu seguro en EsSalud o conocer tu Centro Asistencial asignado, puedes hacerlo a través del servicio Dónde me atiendo.',
  'https://dondemeatiendo.essalud.gob.pe/#/consulta',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (ESSALUD / Ingresa al  Repositorio Institucional del Seguro Social de S): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Ingresa al  Repositorio Institucional del Seguro Social de Salud – EsSalud',
  'El Repositorio Institucional de EsSalud, es una plataforma que tiene el propósito de recopilar, preservar y difundir de manera organizada y accesible publicaciones de carácter académico, científico, producidos por el Seguro Social de Salud – ESSALUD.Accede en línea y a texto...',
  'https://repositorio.essalud.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (ESSALUD / Ingresa al catálogo en línea de EsSalud): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Ingresa al catálogo en línea de EsSalud',
  'Si deseas acceder a libros, revistas y estudios sobre la seguridad social, medicina y otros, puedes consultar el catálogo en Línea de EsSalud.',
  'http://catalogo.essalud.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (ESSALUD / Inscribirse en Padomi): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Inscribirse en Padomi',
  'Si eres un adulto mayor o una persona con discapacidad asegurado en EsSalud, y no puedes acercarte a un centro de salud debido a tu condición médica, puedes inscribirte al Programa de Atención domiciliaria (Padomi) de la Subgerencia de Atención Domiciliaria, para recibir atención en casa.',
  'https://www.gob.pe/59827-inscribirse-en-padomi',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI original del paciente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'DNI original del familiar responsable.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Si tienes alguna discapacidad, presenta tuCarnet de Conadis en físico (amarillo).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Referencia de tu centro asistencial.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Asistir a charla de inducción brindada por Padomi.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Si no eres familiar directo del paciente, debes presentar una carta poder simple.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 7, 'Croquis de cómo llegar a tu domicilio');

-- REVISAR (ESSALUD / Presentar Declaración Jurada de Conflicto de Intereses para ): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Presentar Declaración Jurada de Conflicto de Intereses para para funcionarios, servidores, locadores y practicantes de EsSalud',
  'Si trabajas en el Seguro Social de Salud (EsSalud), debes presentar tu Declaración Jurada de Conflicto de Intereses en un máximo de 15 días hábiles después haber iniciado tus funciones.',
  'https://apps.essalud.gob.pe/declaracion-jurada/#/login',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI o Carnet de Extranjería.');

-- REVISAR (ESSALUD / Procedimiento de Selección.): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Procedimiento de Selección.',
  'Si eres miembro del comité o eres un representante del Órgano Encargado de las Contrataciones en el Seguro Social de Salud (EsSalud), debes presentar tu Declaración Jurada de Conflicto de Intereses en un máximo de 2 días hábiles después de ser nombrado.',
  'https://apps.essalud.gob.pe/declaracion-jurada/#/comite',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI o Carnet de Extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Resolución de designación');

-- REVISAR (ESSALUD / Sacar una cita médica en EsSalud): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Sacar una cita médica en EsSalud',
  'Antes de ser atendido en un establecimiento de salud de la red de EsSalud, debes programar una cita en el centro de salud que se te ha asignado. Revisa cuál es tu centro de salud asignado.En caso requieras una atención especializada que no se encuentre en el establecimiento...',
  'https://miconsulta.essalud.gob.pe/auth/login',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento de identidad, carnet de extranjería o pasaporte.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Para ser atendido en EsSalud tu seguro debe de estar activo, para verificarlo puedes hacerlo a través de:');

-- REVISAR (ESSALUD / Acceder a mesa de partes): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a mesa de partes',
  'Si necesitas enviar documentos para realizar tus trámites, puedes hacerlo a través de la mesa de partes de las entidades públicas.',
  'https://mpv.essalud.gob.pe/Login/Index',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud simple que exprese claramente tu pedido.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Número de DNI, RUC, pasaporte o carnet de extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Correo electrónico y número de teléfono.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Documentos (oficio, carta, solicitud u otro) que sustente el trámite que deseas realizar.');

-- REVISAR (ESSALUD / Atención de denuncias por presuntos actos de corrupción en E): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Atención de denuncias por presuntos actos de corrupción en Essalud',
  'Si necesitas denunciar un posible acto de corrupción o falta de ética cometida por personal de una entidad del Estado, puedes hacerlo a través de la Plataforma de Denuncias Ciudadanas, habilitada por la Presidencia del Consejo de Ministros (PCM), o de manera presencial o en línea, en la entidad que quieres denunciar.',
  'https://denuncias.servicios.gob.pe',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Marcar como entidad donde se origina la denuncia: Seguro Social de Salud');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico y número telefónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'En caso de presentar la denuncia como persona jurídica, número de RUC.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Documentación original o copia simple que sustente tu denuncia. También puedes precisar la unidad o dependencia donde se efectuó el hecho.');

-- REVISAR (ESSALUD / Presentar un reclamo ante una entidad pública): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Presentar un reclamo en la hoja de reclamación en salud',
  'Si estás insatisfecho o disconforme con la atención brindada, puedes presentar una queja o reclamo en su Libro de Reclamaciones. Con esto, se busca proteger tus derechos y lograr la eficiencia del Estado en la atención de los servicios brindados.',
  'https://ww10.essalud.gob.pe/libro-reclamaciones/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI, Certificado de extranjería, pasaporte o RUC');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Número celular');

-- REVISAR (SUNARP / Acceder a consulta registral para municipalidades y gobierno): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a consulta registral para municipalidades y gobiernos regionales',
  'Si trabajas en una municipalidad o gobierno regional y deseas realizar consultas sobre el Registro de Predios, puedes hacerlo de forma gratuita a través del Servicio de Publicidad Registral en Línea (SPRL).',
  'https://enlinea.sunarp.gob.pe/sunarpweb/pages/acceso/ingreso.faces',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Contar con usuario y contraseña en el SPRL.');

-- REVISAR (SUNARP / Acceder a la Plataforma de Servicios Institucionales): costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la Plataforma de Servicios Institucionales',
  'Si deseas acceder al Módulo Sistema Notario o al Módulo Nacional de Empresas Emprendedoras, Acreditación de Concesionarios Autorizados y Gestores, puedes hacerlo desde la Plataforma de Servicios Institucionales. La información que incorpora el o la Notaria o la Empresa...',
  'https://psi.sunarp.gob.pe/ProyOrganizaSII/login.jsf',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Contar con usuario y contraseña del sistema.');

-- REVISAR (SUNARP / Acceder a las convocatorias de 8 UIT de la Sunarp): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a las convocatorias de 8 UIT de la Sunarp',
  'En esta aplicación los ciudadanos a nivel nacional, deben registrarse para postular las diversas convocatorias de bienes y servicios cuyo valor económico sea menor o igual a las 8uits*.',
  'https://8uit.sunarp.gob.pe/portal',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'RUC');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Razón social');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Registro Nacional de Proveedores (RNP)');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Email');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Teléfono');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Persona de contacto');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 7, 'Grupo de convocatoria al que postula.');

-- REVISAR (SUNARP / Acceder al Visor de la Base Gráfica Registral): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Visor de la Base Gráfica Registral',
  'Si deseas visualizar los mapas de los predios inscritos e incorporados a la Base Gráfica Registral en el ámbito nacional, puedes hacerlo a través del Visor de la Base Gráfica Registral.',
  'https://visor-bgr.sunarp.gob.pe/visor-bgr/inicio',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Fecha de emisión de DNI.');

-- REVISAR (SUNARP / Acceder al formato de inmatriculación vehicular): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al formato de inmatriculación vehicular',
  'El formato de inmatriculación vehicular es una herramienta informática que ayuda a dar una mayor seguridad jurídica respecto a la información del vehículo que se va a inmatricular. La inmatriculación es el acto por el cual se incorpora un bien al registro.',
  'https://formelec.sunarp.gob.pe/FormatoInmatriculacion/Forms/Frm_InmaVehi.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Datos personales del titular del vehículo');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Detalles de las características del vehículo');

-- REVISAR (SUNARP / Alertar el robo de un vehículo): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Alertar el robo de un vehículo',
  'Si cuentas con tarjeta de identificación vehicular electrónica (Tive), puedes realizar la comunicación inmediata del robo de tu vehículo a través del servicio "Alerta Robo", para su difusión en las siguientes plataformas digitales: Consulta vehicular gratuita, Sistema de...',
  'https://alertarobo.sunarp.gob.pe/alerta-robo/inicio',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de Documento Nacional de Identidad (DNI).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Número del teléfono celular del usuario.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Número de placa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Número de TIVE.');

-- REVISAR (SUNARP / Buscar y reservar el nombre de una empresa en la Sunarp): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar y reservar el nombre de una empresa en la Sunarp',
  'La reserva de nombre es un paso previo a la constitución de una empresa. No es un trámite obligatorio, pero sí recomendable para facilitar la inscripción de la empresa en el Registro de Personas Jurídicas de la Sunarp. Durante la calificación de la reserva de nombre, el...',
  'https://sidciudadano.sunarp.gob.pe/sid/sesion.htm',
  'VIRTUAL',
  25.60
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Usuario y contraseña para acceder al SID - SUNARP.');



-- REVISAR (SUNARP / Calcular el valor de los derechos registrales - Calculadora ): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Calcular el valor de los derechos registrales - Calculadora Registral',
  'Esta herramienta es referencial, pues corresponde al Registrador en su labor de calificación evaluar la exactitud de las liquidaciones y de los pagos que se efectúen por concepto de derecho registrales.',
  'https://www.sunarp.gob.pe/Calculadora/index.asp',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- REVISAR (SUNARP / Cambiar la tarjeta de identificación vehicular (TIV) a la ve): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Cambiar la tarjeta de identificación vehicular (TIV) a la versión electrónica (TIVe)',
  'En esta plataforma puedes cambiar por única vez tu tarjeta de identificación vehicular. De esta manera, podrás llevarla en tu celular, tablet u otro dispositivo móvil.',
  'https://tivative.sunarp.gob.pe/tivative/inicio',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Fecha de emisión del DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Correo electrónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Última tarjeta de identificación vehicular (TIV) física expedida por la Sunarp.');

-- REVISAR (SUNARP / Conocer el directorio nacional de personas jurídicas): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Conocer el directorio nacional de personas jurídicas',
  'Si deseas conocer información referencial sobre las personas jurídicas inscritas en los registros públicos, puedes hacerlo de manera gratuita a través de este servicio.El Directorio Nacional se actualiza mensualmente, y permite consultas libres para conocer si una determinada...',
  'https://www.sunarp.gob.pe/dn-personas-juridicas.asp',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();

-- vinculos tramite <-> etiqueta (por nombre+entidad, no por ID fijo)
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = '3.er Proceso de Evaluación y Certificación de Competencias del estándar “Ejecutar Procedimientos Registrales Civiles”' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = '3.er Proceso de Evaluación y Certificación de Competencias del estándar “Ejecutar Procedimientos Registrales Civiles”' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'capacitacion')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Guía de Usuario Mesa de Partes Virtual' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a las Convocatorias de Bienes y Servicios para Procesos Electorales 2026' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'contrataciones')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a las Convocatorias de Bienes y Servicios para Procesos Electorales 2026' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Repositorio Institucional del Reniec' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Actualizar PIN de seguridad' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'seguridad')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Agendar citas presenciales en línea' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Agendar citas presenciales en línea' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Agendar citas presenciales en línea' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Agendar citas presenciales en línea' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Autenticar o certificar una constancia o acta de nacimiento, matrimonio o defunción' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'identidad')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Cambiar el lugar de entrega del DNI' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Canjear Libreta Electoral por DNI electrónico' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Canjear Libreta Electoral por DNI electrónico' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'identidad')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Canjear Libreta Electoral por DNI electrónico' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Consultar estado de tu trámite para la entrega de tu DNI' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Consultar trámites rechazados en Consulados' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Generar ticket para pagos de trámite a través de Yape y Agente BCP' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Generar ticket para pagos de trámite a través de Yape y Agente BCP' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Inscribir reconocimiento de paternidad por escritura pública o testamento' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'identidad')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la Calculadora Tributaria' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la atención de consultas en Redes Sociales' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la atención de consultas en Redes Sociales' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'aduanas')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la información pública de la Sunat' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'transparencia')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la información pública de la Sunat' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a tu expediente electrónico de cobranza coactiva en la Sunat' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Buzón SOL' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Buzón SOL' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Chat Sunat' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Chat Sunat' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'aduanas')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Chat Sunat' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Nuevo RUS' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Programa de Envío de Información (PEI)' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Declarar y pagar impuestos en el Régimen General' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Declarar y pagar impuestos en el Régimen General' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Sistema de Despacho Aduanero (SDA)' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'aduanas')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Sistema de Despacho Aduanero (SDA)' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Teledespacho' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'aduanas')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Activar RUC de persona jurídica' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Activar RUC de persona jurídica' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la Plataforma VIVA' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la Plataforma VIVA' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acreditación de tu seguro en EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Oficinas de Seguros y Prestaciones Económicas (OSPE)' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Consultar dónde atenderte en EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Ingresa al  Repositorio Institucional del Seguro Social de Salud – EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Ingresa al  Repositorio Institucional del Seguro Social de Salud – EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Ingresa al catálogo en línea de EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Ingresa al catálogo en línea de EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Inscribirse en Padomi' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Presentar Declaración Jurada de Conflicto de Intereses para para funcionarios, servidores, locadores y practicantes de EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Procedimiento de Selección.' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Procedimiento de Selección.' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'contrataciones')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Sacar una cita médica en EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Sacar una cita médica en EsSalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Atención de denuncias por presuntos actos de corrupción en Essalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Atención de denuncias por presuntos actos de corrupción en Essalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Atención de denuncias por presuntos actos de corrupción en Essalud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Presentar un reclamo en la hoja de reclamación en salud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Presentar un reclamo en la hoja de reclamación en salud' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a consulta registral para municipalidades y gobiernos regionales' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la Plataforma de Servicios Institucionales' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a la Plataforma de Servicios Institucionales' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a las convocatorias de 8 UIT de la Sunarp' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder a las convocatorias de 8 UIT de la Sunarp' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'contrataciones')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al Visor de la Base Gráfica Registral' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al formato de inmatriculación vehicular' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'vehicular')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Acceder al formato de inmatriculación vehicular' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Alertar el robo de un vehículo' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'vehicular')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Alertar el robo de un vehículo' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Alertar el robo de un vehículo' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'seguridad')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Buscar y reservar el nombre de una empresa en la Sunarp' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Buscar y reservar el nombre de una empresa en la Sunarp' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Calcular el valor de los derechos registrales - Calculadora Registral' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Calcular el valor de los derechos registrales - Calculadora Registral' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Cambiar la tarjeta de identificación vehicular (TIV) a la versión electrónica (TIVe)' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'vehicular')
);
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Cambiar la tarjeta de identificación vehicular (TIV) a la versión electrónica (TIVe)' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual')
);
 
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (
  (SELECT id_tramite FROM tramite WHERE nombre = 'Conocer el directorio nacional de personas jurídicas' AND id_entidad = (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP')),
  (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros')
);

-- segundo hilo de inserts

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la información sobre quién consultó tu DNI',
  'Como titular de tus datos personales, tienes derecho a saber quién consultó tu DNI. Este derecho es personal y solo puede ser ejercido por ti. El trámite es gratuito. RENIEC podrá denegar la solicitud en estos casos.',
  'https://apps.reniec.gob.pe/MesaPartesVirtual/',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('dni');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni'));

-- REVISAR (RENIEC / Consultar identidad de una persona): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud clara y precisa con tus datos: nombres completos y número de DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Copia legible de tu DNI vigente (anverso y reverso).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Firma del titular de los datos personales.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'En caso de representante legal: carta poder notarial vigente y copia del DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Documentos adicionales que sustenten la solicitud (si corresponde).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar identidad de una persona',
  'Para consultar la identidad de una persona, solo necesitas ingresar el DNI y el sistema te brindará los datos completos (apellidos y nombres), así como también el dígito de verificación del DNI.',
  'https://www.gob.pe/13390-consultar-identidad-de-una-persona',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni'));

-- REVISAR (RENIEC / Descubre nombres originarios del Perú y sus significados): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'RENIEC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Descubre nombres originarios del Perú y sus significados',
  'Ingresa a la plataforma web Sutichay Wawa y conoce el significado de los nombres originarios del Perú. Ahora, también puedes descargar el aplicativo móvil para sistema operativo Android. Te invitamos a explorar la herencia cultural de nuestros pueblos ancestrales y a encontrar.',
  'https://play.google.com/store/apps/details?id=pe.gob.reniec.sutichaywawaapp&hl=es_PE',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (SUNAT / Acceder a la App Sunat): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la App Sunat',
  'Si eres trabajador independiente, micro, pequeño empresario (MYPE) u operador de comercio, y deseas consultar tus obligaciones tributarias o cumplir con el pago de impuestos, puedes hacerlo a través de la App Sunat. Esta aplicación te permite: Acceder al Buzón Electrónico para.',
  'https://www.gob.pe/13929-acceder-a-la-app-sunat',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pagos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('impuestos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos'));

-- REVISAR (SUNAT / Acceder a la Categoría Especial del Nuevo RUS): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de RUC o DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Clave SOL; si no tienes,puedes obtenerla.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la Categoría Especial del Nuevo RUS',
  'Si eres contribuyente del tipo persona natural o sucesión indivisa, puedes acceder a la Categoría Especial del Nuevo RUS bajo ciertas condiciones y cumpliendo con algunos requisitos. Ten presente que si accedes a la Categoría Especial, no estás obligado a realizar ningún pago.',
  'https://www.gob.pe/1213-acceder-a-la-categoria-especial-del-nuevo-rus',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos'));

-- REVISAR (SUNAT / Acceder a servicios e información a través del aplicativo Su): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formulario 2010, llenado y firmado');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a servicios e información a través del aplicativo Sunat',
  'Si eres trabajador independiente, MYPE u Operadores de Comercio y necesitas efectuar consultas, o requieres de un servicio e información para cumplir con tus obligaciones tributarias, puedes descargar la aplicación App SUNAT, que te permite: Buzón SOL Mis Declaraciones y.',
  'https://www.gob.pe/7358-acceder-a-servicios-e-informacion-a-traves-del-aplicativo-sunat',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (SUNAT / Acceder al Régimen General): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Régimen General',
  'Por este procedimiento podrás acceder al régimen tributario Régimen General, cuando inicies tu negocio, como persona natural, persona jurídica, sucesión indivisa, sociedad conyugal u otros. Presenta tu declaración mensual desde la web de SUNAT dentro de la fecha de.',
  'https://www.gob.pe/7330-acceder-al-regimen-general',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (MIGRACIONES / Actualizar tus datos en Migraciones (con emisión de document): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI vigente, Carnet de Extranjería, Carnet de Identidad, Carnet de Permiso Temporal de Permanencia o Pasaporte con calidad migratoria para la generación de renta de fuente peruana.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Si cuentas con representante legal, debes exhibir elDNI de éste. (ejemplo: tutor o curador).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Si vas a registrar una dirección distinta a la de tu DNI, debes  presentar el original de tu DNI y cualquier documento privado o público  en el que conste la dirección del domicilio fiscal.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Carta poder con firma legalizada notarialmente o autenticada por  fedatario de SUNAT, que lo autorice expresamente a realizar el trámite  de inscripción en el RUC.  (Si el trámite lo hace un tercero)');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Formulario 2119: Solicitud de Inscripción o Comunicación de Afectación a Tributos.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Actualizar tus datos en Migraciones (con emisión de documento)',
  'Si eres un ciudadano extranjero que necesita actualizar los datos de su documento de identificación emitido por Migraciones, debes solicitarlo a la entidad a través de su agencia digital. De esta manera, obtienes tu documento actualizado y mantienes el Registro de Información.',
  'https://agenciavirtual.migraciones.gob.pe/agencia-virtual/identidad',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('migraciones');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (MIGRACIONES / Bloquear mi Pasaporte Electrónico): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formulariogratuito.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Indicar número de recibo y fecha de pago por derecho de trámite.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Copia simple del pasaporte o documento de viaje.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Bloquear mi Pasaporte Electrónico',
  'Cuando pierdes o te roban tu Pasaporte Electrónico es importante que lo bloquees para que no pueda ser utilizado por otra persona. Esta operación es gratuita y lo anulará automáticamente, por lo que deberás tramitar un nuevo pasaporte pagando previamente su costo.',
  'https://epbs.migraciones.gob.pe/sistema-de-bloqueo/bloquear',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pasaporte');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pasaporte'));

-- REVISAR (MIGRACIONES / Completar declaración jurada de salud en línea para ingresar): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Completar declaración jurada de salud en línea para ingresar a Perú',
  'Si deseas ingresar al Perú, es necesario que completes en línea el formato de “Declaración jurada electrónica de salud del viajero y compromiso para realizar aislamiento o cuarentena del viajero”, dentro de las 72 horas antes de viajar.',
  'https://e-notificacion.migraciones.gob.pe/dj-salud/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('salud');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (MIGRACIONES / Conocer las medidas sobre movilidad y temas sanitarios en Am): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Conocer las medidas sobre movilidad y temas sanitarios en América del Sur - Suramérica Abierta',
  'Si deseas conocer las medidas adoptadas por los gobiernos de América del Sur respecto a restricciones fronterizas, requisitos de cuarentena, pruebas de COVID-19 para migrantes y viajeros, entre otras medidas sobre movilidad humana y temas sanitarios, puedes hacerlo.',
  'https://suramericaabierta.info/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIGRACIONES / Conocer las medidas sobre movilidad y temas sanitarios en Am): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIGRACIONES / Crea tu usuario en Migracheck): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Crea tu usuario en Migracheck',
  'Si vas a viajar al extranjero, debes crear tu usuario en MigraCheck por única vez, para realizar tu prerregistro migratorio antes de salir del país.',
  'https://www.gob.pe/109753-crea-tu-usuario-en-migracheck',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (MIGRACIONES / Emisión de pasaporte en casos especiales): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Emisión de pasaporte en casos especiales',
  'Si necesitas programar una cita para obtener tu pasaporte mediante una solicitud de atención especial, pero no tienes un viaje inmediato, puedes solicitar tu pasaporte electrónico ante Superintendencia Nacional de Migraciones, en los siguientes casos.',
  'https://agenciavirtual.migraciones.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('citas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pasaporte'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (MIGRACIONES / Haz tu prerregistro migratorio en MigraCheck): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documentación que justifique la necesidad especial para obtener el pasaporte, según los siguientes casos:');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Salud:presenta las constancias de citas médicas programadas en el exterior y documentos que acrediten el diagnóstico de la enfermedad y la necesidad de la atención (por ejemplo carta médica para el traslado intrahospitalario). Una vez evaluada y aprobada la solicitud, Migraciones acudirá al domicili');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Visa:presenta la constancia de programación de cita o el comprobante de pago para iniciar el trámite de la visa o formulario.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Solicitud de residencia en otro país:presenta la solicitud de residencia en otro país o el cargo de la carta enviada al consulado o embajada.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Beca de estudio:presenta la carta del centro de estudios que indique que el solicitante fue aceptado o el pago de postulación a la beca y el formulario de inscripción o matrícula.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Intercambio estudiantil:presenta la carta de presentación de la institución encargada de realizar el intercambio estudiantil o el correo electrónico institucional que acredite el caso y el comprobante de pago.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 7, 'En caso de pérdida o robo del pasaporte, presenta ladeclaración jurada de la anulación de dicho documento de viaje.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Haz tu prerregistro migratorio en MigraCheck',
  'Ahora que ya tienes tu cuenta de usuario y estás por viajar al extranjero, realiza tu prerregistro migratorio de forma digital, desde tu computadora o celular.',
  'https://www.gob.pe/109786-haz-tu-prerregistro-migratorio-en-migracheck',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (MIGRACIONES / Obtener pasaporte electrónico para mayores de edad): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Pasaporte vigente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Billete electrónico oe-ticket(impreso o digital).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Obtener pasaporte electrónico para mayores de edad',
  'Si deseas obtener el pasaporte electrónico para mayores de edad, puedes tramitarlo presencialmente en las oficinas de la Superintendencia Nacional de Migraciones, en los Migracentros de Puruchuco y Villa María o en los centros MAC Arequipa, MAC Ancash, MAC Ayacucho, MAC.',
  'https://citaspasaporte.migraciones.gob.pe/citas-pasaporte-v2/',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pasaporte'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (MIGRACIONES / Obtener pasaporte electrónico para menores de edad): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI en buen estado y último emitido.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Recibo de pago por derecho de trámite.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Declaración jurada por pérdida o robo de pasaporte, de ser el caso.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Obtener pasaporte electrónico para menores de edad',
  'Si deseas obtener el pasaporte electrónico para un menor de edad, puedes tramitarlo presencialmente en las oficinas de la Superintendencia Nacional de Migraciones, en los Migracentros de Puruchuco y Villa María o en los centros MAC Arequipa, MAC Ancash, MAC Ayacucho, MAC.',
  'https://citaspasaporte.migraciones.gob.pe/citas-pasaporte-v2/pasaporte',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pasaporte'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (MIGRACIONES / Obtener pasaporte en casos de urgencia): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI del menor, vigente y en buen estado.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Declaración jurada por pérdida o robo de pasaporte, de ser el caso.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Recibo de pago por derecho de trámite.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'DNI, carnet de extranjería, pasaporte u otro documento del padre o madre que acompaña al menor.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIGRACIONES'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Obtener pasaporte en casos de urgencia',
  'Si tienes un viaje de urgencia y necesitas tu pasaporte electrónico , puedes tramitarlo dentro de los dos días hábiles previos a la salida de tu vuelo en cualquier oficina de Migraciones o en los Centros de Mejor Atención al Ciudadano (MAC) que expiden pasaportes electrónicos ordinarios, a nivel nacional. En la sede del Aeropuerto Internacional Jorge Chávez podrás tramitarlo dentro de las 8 horas previas a tu vuelo.',
  'https://www.gob.pe/156-obtener-pasaporte-en-casos-de-urgencia',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pasaporte'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (ESSALUD / Cita médica por referencia en EsSalud): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formulario PA – Pasaporte Electrónico ordinario para casos de urgencia.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Recibo de pago por derecho de trámite.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Tarjeta de embarque de la aerolínea (boarding pass) o el boleto de transporte aéreo  (entiéndase como tal, al documento que acredita la compra del pasaje), con los datos del ciudadano correctamente indicados, en el que se acredite la proximidad del viaje internacional.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Declaración jurada por pérdida o robo de pasaporte, de ser el caso.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Demás requisitos paramayoresomenores de edad, según sea el caso. Ten en cuenta queel código de pago para casos de urgencia es diferente(código01808).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Cita médica por referencia en EsSalud',
  'En caso requieras una atención especializada con la que no cuente el establecimiento de salud al que fuiste asignado, podrás ser derivado a otro establecimiento de salud que si cuente con dicha especialidad, a esto se le llama Referencia.',
  'https://miconsulta.essalud.gob.pe',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('citas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('salud');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (ESSALUD / Consultar mis citas médicas, recetas y exámenes pendientes a): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar mis citas médicas, recetas y exámenes pendientes a través de EsSalud Mi Consulta',
  'Puedes consultar tus citas programadas, recetas emitidas, atenciones pasadas, trámite de referencias, exámenes auxiliares y citas en espera de atención con la aplicación EsSalud Mi Consulta. Esta aplicación móvil es de uso exclusivo para los asegurados a EsSalud.',
  'https://play.google.com/store/search?q=essalud&c=apps&hl=es_419',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (ESSALUD / Presentar un reclamo ante una entidad pública): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Teléfono con sistema operativo Android.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Presentar un reclamo ante una entidad pública',
  'Si estás insatisfecho o disconforme con la atención brindada en una entidad pública, puedes presentar una queja o reclamo en su Libro de Reclamaciones. Con esto, se busca proteger tus derechos y lograr la eficiencia del Estado en la atención de los servicios brindados.',
  'https://www.gob.pe/52103-seguro-social-de-salud-presentar-un-reclamo-ante-una-entidad-publica',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (SUNARP / Acceder a la Plataforma de Servicio de Publicidad Registral ): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI, Certificado de extranjería, pasaporte o RUC');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Número celular');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la Plataforma de Servicio de Publicidad Registral en Línea (SPRL)',
  'Si deseas acceder a los índices de los distintos registros y las imágenes de las partidas registrales inscritas en los Registros Públicos del país, así como solicitar publicidad certificada, puedes hacerlo a través de esta plataforma. La Plataforma de Servicio de Publicidad.',
  'https://sprl.sunarp.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (SUNARP / Acceder al Buzón de Sugerencias y Propuestas de Innovación d): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Inscripción de Alerta Registral');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Solicitar copia de registro de propiedad vehicular');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Solicitar copias literales o simples en SUNARP');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Registrar o constituir empresa en Registros Públicos');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Buzón de Sugerencias y Propuestas de Innovación de la Sunarp',
  'Si trabajas en la Superintendencia Nacional de los Registros Públicos (Sunarp), puedes enviar sugerencias o propuestas de innovación para contribuir a la mejora y optimización de los servicios institucionales. A través de este canal, la Sunarp recibe iniciativas orientadas.',
  'https://serviciosoppm.sunarp.gob.pe/sugerencia-innova-ui/buzondesugerencias',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (SUNARP / Acceder al Sistema Integrado de Precedentes - SIP Sunarp): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ser trabajador de la Sunarp.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Contar con correo electrónico institucional.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Acceder desde la red institucional de la Sunarp.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema Integrado de Precedentes - SIP Sunarp',
  'Si necesitas acceder al contenido de los precedentes de observancia obligatoria aprobados por el Tribunal Registral, puedes hacerlo a través de esta herramienta gratuita. Podrás encontrar la información que necesites realizando búsquedas según los siguientes criterios.',
  'https://scr.sunarp.gob.pe/sip/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (SUNARP / Conocer el contenido o pagar a cuenta tu título en trámite e): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNARP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Conocer el contenido o pagar a cuenta tu título en trámite en la Sunarp - Síguelo Plus',
  'Podrás acceder de forma gratuita y desde cualquier lugar con conexión a Internet, a la lectura de tu título en trámite, y la posibilidad de hacer, en línea, pagos a cuenta a través de la herramienta Síguelo Plus.',
  'https://sigueloplus.sunarp.gob.pe/siguelo/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pagos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('educacion');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder a Edutalentos del Minedu): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a Edutalentos del Minedu',
  'Si trabajas en una Dirección Regional de Educación (DRE) o en una Unidad de Gestión Educativa Local y deseas fortalecer tus capacidades para un mejor desempeño de tus funciones, puedes acceder a la plataforma Edutalentos, del Ministerio de Educación de Perú (Minedu).',
  'https://edutalentos.pe',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('educacion');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder a educación a distancia - Aprendo en casa): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Correo electrónico.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a educación a distancia - Aprendo en casa',
  'Este es un servicio multicanal de educación a distancia por televisión, radio e Internet. El objetivo a corto plazo es que los estudiantes de educación básica (inicial, primaria y secundaria), educación básica especial (Prite y Cebe) y educación básica alternativa avancen.',
  'https://aprendoencasa.pe/#/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la oferta formativa que brinda el Sistema Integrado de Formación Docente en Servicio',
  'Con miras a modernizar y democratizar el acceso a la formación docente, el Ministerio de Educación (Minedu) presenta el Sistema Integrado de Formación Docente en Servicio, un entorno virtual diseñado para que el docente peruano gestione su desarrollo profesional de manera.',
  'https://sifods.minedu.gob.pe/',
  'SEMIPRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder a los Materiales Educativos Digitales (MED) de la Pl): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los Materiales Educativos Digitales (MED) de la Plataforma Tecnológica Educativa - PerúEduca',
  'La Plataforma Tecnológica Educativa PerúEduca del Ministerio de Educación brinda Materiales Educativos Digitales (MED) para complementar los aprendizajes dentro y fuera del aula. Presenta los materiales agrupados en diversas colecciones para inicial, primaria, secundaria.',
  'https://www.perueduca.pe/#/home/materiales-educativos',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder a materiales pedagógicos bilingües del Ministerio de): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Computadora o dispositivo móvil');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Conexión a Internet');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a materiales pedagógicos bilingües del Ministerio de Educación',
  'Si eres docente que enseña a niños y niñas que hablan una lengua materna originaria, como quechua, aimara, awajún, shipibo-conibo, asháninka, etc, y requieres encontrar materiales pedagógicos para brindar tus clases.',
  'http://umc.minedu.gob.pe/educacion-intercultural-bilingue/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder a plataforma de autoyuda para profesionales de la ed): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a plataforma de autoyuda para profesionales de la educación - Te escucho, docente',
  'Si eres profesional de la educación, docente o directivo, puedes obtener apoyo de parte de un equipo de psicólogos para cuidar tu bienestar emocional y fortalecer tus capacidades socioemocionales, a través del servicio Te escucho, docente. A través de una llamada telefónica.',
  'https://www.minedu.gob.pe/teescuchodocente',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder al E-SINAD Minedu): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al E-SINAD Minedu',
  'Si eres un servidor del Ministerio de Educación de Lima Metropolitana puedes gestionar documentos, de manera interna, a través de la plataforma E-SINAD. Este servicio te permite derivar del Minedu a: Dirección Regional de Educación de Lima MetropolitanaUnidad de Gestión.',
  'http://esinad.minedu.gob.pe/e_sinadmed',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder al Sistema de Gestión de la Calidad del Servicio Edu): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema de Gestión de la Calidad del Servicio Educativo (SIMON)',
  'A través del Sistema de Gestión de la Calidad del Servicio Educativo (SIMON), podrás gestionar información objetiva, relevante y oportuna (en tiempo real) para la toma de decisiones a todo nivel de Gobierno. Esta plataforma está conectada en línea a las bases de datos.',
  'https://simon.minedu.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MINEDU / Acceder al Sistema de Gestión de la Información y Seguimient): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema de Gestión de la Información y Seguimiento a los casos comprendidos en la Ley N° 29988 (SGIS)',
  'Si eres un especialista de una Dirección Regional de Educación o de una Unidad de Gestión Educativa Local, podrás monitorear la información del personal docente y administrativo registrado en el sistema REGIEP por los directores de las instituciones educativas privadas.',
  'https://sgis.minedu.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder al Sistema de Registro de Datos del Personal Docente): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema de Registro de Datos del Personal Docente y Administrativo de Instituciones Educativas Privadas (REGIEP)',
  'El Sistema de Registro de Datos del Personal Docente y Administrativo de Instituciones Educativas Privadas (REGIEP) permite a los directores de las Instituciones Educativas Privadas de Educación Básica Regular, Educación Básica Especial y Educación Básica Alternativa.',
  'https://regiep.minedu.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder al Sistema de seguimiento a los actos administrativo): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Para ingresar utiliza las mismas credenciales de tu cuenta de usuario del Sistema de Información de Apoyo a la Gestión de la Institución Educativa (SIAGIE).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema de seguimiento a los actos administrativos, actividades de supervisión y procedimiento administrativos sancionador (SISPAS)',
  'Si trabajas en una Dirección o Gerencia Regional de Educación o en una Unidad de Gestión Educativa Local, y desear atender o darle seguimiento a las solicitudes de actos administrativos, así como de actividad de supervisión y del procedimiento administrativo sancionador.',
  'https://sispas.minedu.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceder al correo institucional del Minedu): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Cuenta de usuario y contraseña');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Si eresnuevoen SISPAS, debes registrarte. Para registrarte la DRE/GRE o UGEL debe solicitar el registro asoportesispas@minedu.gob.pea través del Especialista SISPAS o autoridad respectiva, adjuntando elformato respectivo.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Sino recuerdaslas credenciales para ingresar a SISPAS, puedes escribir asoportesispas@minedu.gob.pe, adjuntando tus datos como: Nombres y apellidos completos, N° de DNI y Correo electrónico registrado en SISPAS.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al correo institucional del Minedu',
  'Si eres docente o directivo de una institución educativa debes activar tu correo institucional para acceder a los siguientes beneficios: Mantenerte informado de las últimas noticias y datos proporcionadas por el Minedu. Realizar gestiones académicas y administrativas.',
  'https://www.gob.pe/38348-acceder-al-correo-institucional-del-minedu',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINEDU / Acceder al correo institucional del Minedu): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINEDU / Acceder al repositorio institucional del Minedu): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ser docente o directivo activo de una institución educativa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Contar con un número de celular activo.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al repositorio institucional del Minedu',
  'Encuentra de forma gratuita material e investigaciones educativas, así como publicaciones oficiales del Ministerio de Educación, a través de su repositorio institucional.',
  'https://repositorio.minedu.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Acceso a información que posean o produzcan las dependencias): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceso a información que posean o produzcan las dependencias de las instancias intermedias de gestión del sector educación',
  'Base Legal: D. S. Nº 018-2001-PCM Ley Nº 27806 Ley Nº 27927 D.',
  'https://www.gob.pe/21992-acceso-a-informacion-que-posean-o-produzcan-las-dependencias-de-las-instancias-intermedias-de-gestion-del-sector-educacion',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINEDU / Aplicación móvil ALERTA MINEDU): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINEDU'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aplicación móvil ALERTA MINEDU',
  'ALERTA MINEDU es la aplicación móvil oficial del Ministerio de Educación, de uso exclusivo para directores de instituciones educativas, que permite comunicar oportunamente emergencias ocasionadas por peligros de origen natural o inducidos por la acción humana que generen daños.',
  'https://play.google.com/store/apps/details?id=pe.gob.minedu.alertaminedu',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));


-- REVISAR (MTC / Acceder a información sobre accidentes de tránsito en la apl): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Contar con unusuario y contraseña activos dePerúEduca.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Tener el rol de director validado mediante SIAGIE (EBR, EBA o EBE).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Contar con conexión a internet para registrar y enviar la alerta.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Si aún no cuentas con credenciales dePerúEduca, puedes registrarte en:');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a información sobre accidentes de tránsito en la aplicación SRAT Móvil',
  'Puedes revisar en tiempo real información georreferenciada sobre accidentes de tránsito con la app SRAT Móvil. La aplicación es de uso libre, pero los miembros de la Policía Nacional del Perú tienen el permiso para ingresar reportes sobre vehículos involucrados y personas.',
  'https://www.gob.pe/66967-acceder-a-informacion-sobre-accidentes-de-transito-en-la-aplicacion-srat-movil',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('vehicular');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'vehicular'));

-- REVISAR (MTC / Adhesión al Observatorio de Sostenibilidad Social en Infraes): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Teléfono con sistema operativo Android.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Adhesión al Observatorio de Sostenibilidad Social en Infraestructura de Transportes y Comunicaciones',
  'A la fecha, el Observatorio de Sostenibilidad Social en Infraestructura de Transportes y Comunicaciones (ObsSocial) cuenta con 30 entidades adherentes.',
  'https://www.gob.pe/54569-adhesion-al-observatorio-de-sostenibilidad-social-en-infraestructura-de-transportes-y-comunicaciones',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Adhesión al Observatorio de Sostenibilidad Social en Infraes): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Afiliarte a la casilla electrónica del MTC): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Afiliarte a la casilla electrónica del MTC',
  'En el caso de personas naturales, la casilla electrónica está habilitada para tramitar solo la licencia de conducir.',
  'https://casilla.mtc.gob.pe/#/auth/login',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (MTC / Aprobación de acuerdos de cooperación comercial y de código ): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Correo electrónico.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aprobación de acuerdos de cooperación comercial y de código compartido',
  'Aprobación de acuerdos de cooperación comercial y de código compartido.',
  'https://www.gob.pe/22685-aprobacion-de-acuerdos-de-cooperacion-comercial-y-de-codigo-compartido',
  'PRESENCIAL',
  3266.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Aprobación de acuerdos de cooperación comercial y de código ): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Aprobación de memoria técnica de reparaciones o alteraciones): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aprobación de memoria técnica de reparaciones o alteraciones mayores',
  'Aprobación de memoria técnica de reparaciones o alteraciones mayores.',
  'https://www.gob.pe/22686-aprobacion-de-memoria-tecnica-de-reparaciones-o-alteraciones-mayores',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Aprobación de memoria técnica de reparaciones o alteraciones): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Aprobación de planes de contingencia para el transporte de m): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aprobación de planes de contingencia para el transporte de materiales y residuos peligrosos en el sector transportes',
  'Aprobación de planes de contingencia para el transporte de materiales y residuos peligrosos en el sector transportes.',
  'https://www.gob.pe/22687-aprobacion-de-planes-de-contingencia-para-el-transporte-de-materiales-y-residuos-peligrosos-en-el-sector-transportes',
  'PRESENCIAL',
  441.50
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Aprobación de planes de contingencia para el transporte de m): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorización de funcionamiento para escuelas y centros de in): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización de funcionamiento para escuelas y centros de instrucción',
  'Autorización para escuelas y centros de instrucción.',
  'https://www.gob.pe/22693-autorizacion-de-funcionamiento-para-escuelas-y-centros-de-instruccion',
  'PRESENCIAL',
  1633.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorización de funcionamiento para escuelas y centros de in): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorización para Talleres de Mantenimiento Aeronáutico (TMA): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para Talleres de Mantenimiento Aeronáutico (TMA)',
  'Autorización para Talleres de Mantenimiento Aeronáutico (TMA).',
  'https://www.gob.pe/22706-autorizacion-para-talleres-de-mantenimiento-aeronautico-tma',
  'PRESENCIAL',
  1633.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorización para Talleres de Mantenimiento Aeronáutico (TMA): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorización para el cambio de categoría a la inmediata supe): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para el cambio de categoría a la inmediata superior del servicio de radioaficionados (categoría intermedia o superior)',
  'Base Legal: Arts. 14, 22, 48 y 55 del Texto Único Ordenado de la Ley de Telecomunicaciones, aprobado por Decreto Supremo N.° 013-93-TCC (06/05/93). Arts. 111, 171, 174, 181 y 227 del Texto Único Ordenado del Reglamento General de la Ley de Telecomunicaciones, aprobado por.',
  'https://www.gob.pe/22698-autorizacion-para-el-cambio-de-categoria-a-la-inmediata-superior-del-servicio-de-radioaficionados-categoria-intermedia-o-superior',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorización para el cambio de categoría a la inmediata supe): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorización para instalación de red propia para prestar ser): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para instalación de red propia para prestar servicio de valor añadido en caso no utilice espectro radioeléctrico',
  'Base Legal: Art. 33 del Texto Único Ordenado de la Ley de Telecomunicaciones, aprobado por D. S. N.° 013-93-TCC (06/05/93) y modificatorias. Art. 101 del Texto Único Ordenado del Reglamento General de la Ley de Telecomunicaciones, aprobado por D. S. N.° 020-2007-MTC (04/07/07).',
  'https://www.gob.pe/22699-autorizacion-para-instalacion-de-red-propia-para-prestar-servicio-de-valor-anadido-en-caso-no-utilice-espectro-radioelectrico',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorización para instalación de red propia para prestar ser): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorización para instalación de red propia para prestar ser): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para instalación de red propia para prestar servicio de valor añadido en caso utilice espectro radioeléctrico',
  'Base Legal: Art. 33 del Texto Único Ordenado de la Ley de Telecomunicaciones, aprobado por D. S. N.° 013-93-TCC (06/05/93) y modificatorias. Art. 101 del Texto Único Ordenado del Reglamento General de la Ley de Telecomunicaciones, aprobado por D. S. N.° 020-2007-MTC (04/07/07).',
  'https://www.gob.pe/22700-autorizacion-para-instalacion-de-red-propia-para-prestar-servicio-de-valor-anadido-en-caso-utilice-espectro-radioelectrico',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorización para instalación de red propia para prestar ser): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorización para la construcción, mejoramiento y rehabilita): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para la construcción, mejoramiento y rehabilitación de infraestructura ferroviaria',
  'Autorización para la construcción, mejoramiento y rehabilitación de infraestructura ferroviaria.',
  'https://www.gob.pe/22701-autorizacion-para-la-construccion-mejoramiento-y-rehabilitacion-de-infraestructura-ferroviaria',
  'PRESENCIAL',
  725.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorización para la construcción, mejoramiento y rehabilita): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorización para las construcciones y/o instalaciones dentr): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para las construcciones y/o instalaciones dentro de las áreas cubiertas por las superficies limitadoras de obstáculos de los aeródromos públicos o privados',
  'Autorización para las construcciones y/o instalaciones dentro de las áreas cubiertas por las superficies limitadoras de obstáculos de los aeródromos públicos o privados.',
  'https://www.gob.pe/22705-autorizacion-para-las-construcciones-y-o-instalaciones-dentro-de-las-areas-cubiertas-por-las-superficies-limitadoras-de-obstaculos-de-los-aerodromos-publicos-o-privados',
  'PRESENCIAL',
  430.10
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorización para las construcciones y/o instalaciones dentr): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorizar cierre o levantamiento de vías férreas): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorizar cierre o levantamiento de vías férreas',
  'Si deseas cerrar, ya sea de forma temporal o permanente, o ejecutar el levantamiento de vías férreas, debes tramitarlo con el Ministerio de Transportes y Comunicaciones.',
  'https://www.gob.pe/22692-autorizar-cierre-o-levantamiento-de-vias-ferreas',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorizar cierre o levantamiento de vías férreas): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTC / Autorizar puesta en servicio de infraestructura ferroviaria): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud según formulario.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTC'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Autorizar puesta en servicio de infraestructura ferroviaria',
  'Si quieres solicitar la autorización de una infraestructura ferroviaria, debes tramitarlo con el Ministerio de Transportes y Comunicaciones.',
  'https://www.gob.pe/22695-autorizar-puesta-en-servicio-de-infraestructura-ferroviaria',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTC / Autorizar puesta en servicio de infraestructura ferroviaria): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Acceder a los indicadores de la ejecución presupuestal en to): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud según formulario.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Pago por derecho de tramitación.');

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los indicadores de la ejecución presupuestal en torno a la seguridad en el Perú',
  'Si deseas acceder a las principales cifras estadísticas sobre la ejecución del Programa Presupuestal 030: Reducción de delitos y faltas que afectan la seguridad ciudadana, puedes revisar el tablero interactivo elaborado por el Ministerio del Interior (Mininter).',
  'https://public.tableau.com/views/Seguimientopresupuestal/seguimientopresupuestal?:language=es-ES&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link&publish=yes&%3AshowVizHome=no',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MININTER / Acceder a los indicadores de la ejecución presupuestal en to): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Acceder a los indicadores de la violencia contra la mujer e ): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los indicadores de la violencia contra la mujer e integrantes del grupo familiar',
  'Si deseas conocer las principales cifras estadísticas actualizadas sobre la violencia contra la mujer y los integrantes del grupo familiar, puedes revisar el tablero interactivo del Ministerio del Interior (Mininter). En este tablero interactivo podrás acceder a información.',
  'https://public.tableau.com/views/VIOLENCIACONTRALAMUJER/Violenciacontralamujer?:language=es-ES&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link&publish=yes&%3AshowVizHome=no',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MININTER / Acceder a los indicadores de la violencia contra la mujer e ): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Acceder a los indicadores de personas desaparecidas en Perú): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los indicadores de personas desaparecidas en Perú',
  'Si deseas conocer las principales cifras estadísticas sobre las denuncias de personas desaparecidas, puedes revisar el tablero interactivo del Ministerio del Interior (Mininter). En este tablero interactivo podrás acceder a información sobre: La evolución mensual de denuncias.',
  'https://public.tableau.com/views/personas_desaparecidas/pers_des_v2_1?:language=es-ES&:sid=&:redirect=auth&:toolbar=n&:display_count=n&:origin=viz_share_link&publish=yes&%3AshowVizHome=no',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (MININTER / Acceder a los indicadores de seguridad ciudadana a nivel sub): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los indicadores de seguridad ciudadana a nivel subnacional',
  'Si deseas acceder a las principales cifras estadísticas actualizadas sobre la seguridad ciudadana del gobierno subnacional peruano, puedes revisar el tablero interactivo del Ministerio del Interior (Mininter). En este tablero interactivo podrás conocer información.',
  'https://public.tableau.com/views/INDICADORES_DASH_SC-REGIONAL/regional?:language=es-ES&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link&publish=yes&%3AshowVizHome=no',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MININTER / Acceder a los indicadores de seguridad ciudadana a nivel sub): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Acceder a los indicadores de trata de personas en el Perú): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los indicadores de trata de personas en el Perú',
  'Si deseas acceder a las principales cifras estadísticas sobre la trata de personas en el Perú, puedes revisar el tablero interactivo del Ministerio del Interior (Mininter). En este tablero interactivo podrás conocer información sobre: El perfil de las víctimas en las denuncias.',
  'https://public.tableau.com/views/TRATADEPERSONAS/Denunciasdetratadepersonas?:showVizHome=no',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (MININTER / Acceder a los indicadores del estado de las comisarías básic): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Acceder a los indicadores del estado de las comisarías básicas en el Perú',
  'Si deseas acceder a las principales cifras estadísticas del estado de las comisarías básicas peruanas como la demografía del personal policial, la infraestructura de los locales, el equipamiento que poseen, entre otros.',
  'https://public.tableau.com/views/SIUP_16293903145830/c200?:language=es-ES&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link&publish=yes&%3AshowVizHome=no',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MININTER / Acceder a los indicadores del estado de las comisarías básic): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Brindar información que permita la captura de personas más b): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Brindar información que permita la captura de personas más buscadas por la justicia - Tu dato te recompensa',
  'Si tienes información sobre el paradero de algún prófugo por feminicidio, violación sexual, homicidio, corrupción u otros delitos, puedes denunciarlo por teléfono de forma anónima a través del programa Tu dato te recompensa del Ministerio del Interior (Mininter).',
  'https://www.gob.pe/44183-brindar-informacion-que-permita-la-captura-de-personas-mas-buscadas-por-la-justicia-tu-dato-te-recompensa',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (MININTER / Brindar información sobre una persona desaparecida en la Lín): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de teléfono o correo electrónico, para ser contactado.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Brindar información sobre una persona desaparecida en la Línea 114',
  'Si tienes información sobre el paradero de una persona reportada como desaparecida, puedes utilizar la Línea 114, una línea gratuita de la Policía Nacional del Perú (PNP). Puedes llamar en los siguientes casos: Para brindar información que pueda servir a que la PNP encuentre a.',
  'https://www.gob.pe/84675-brindar-informacion-sobre-una-persona-desaparecida-en-la-linea-114',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MININTER / Brindar información sobre una persona desaparecida en la Lín): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Conoce la lista de menores de edad desaparecidos): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Conoce la lista de menores de edad desaparecidos',
  'En esta página, podrás revisar la lista de menores de edad desaparecidos, así como la lista de aquellos que fueron encontrados. Puedes buscarlos por: Nombre Lugar donde desapareció Sexo Edad Vestimenta que llevaba.',
  'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/desaparecidos_menor_mujer_hombre',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MININTER / Conoce la lista de menores de edad desaparecidos): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Conocer los indicadores de seguridad del Observatorio Nacion): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Conocer los indicadores de seguridad del Observatorio Nacional de Seguridad Ciudadana',
  'Si deseas conocer los indicadores de seguridad con los que cuenta el Observatorio Nacional de Seguridad Ciudadana, puedes hacerlo a través de este servicio.',
  'https://www.gob.pe/33282-conocer-los-indicadores-de-seguridad-del-observatorio-nacional-de-seguridad-ciudadana',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MININTER / Conocer los indicadores de seguridad del Observatorio Nacion): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MININTER / Consultar Visor de búsqueda de Instrumentos de Cooperación S): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar Visor de búsqueda de Instrumentos de Cooperación Suscritos',
  'El Visor cuenta con más de 1 300 instrumentos suscritos registrados en el aplicativo Sistema de Gestión de Convenios – SISGCONV, el cual contiene información de los instrumentos de cooperación nacional e internacional vigentes y concluidos de 1991 a la fecha.',
  'https://aplicaciones.mininter.gob.pe/visor-convenios',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (MININTER / Denunciar casos que no respeten el aislamiento o la inmovili): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Denunciar casos que no respeten el aislamiento o la inmovilización social',
  'Si eres testigo de algún caso que no respete la inmovilización social (locales que continúen funcionando, medios de transporte público que excedan la cantidad de pasajeros, realización de reuniones o fiestas, personas diagnosticadas que salgan a la calle, etc.) que busca prevenir la propagación del coronavirus (COVID-19), puedes denunciarlo por teléfono al Sistema Integrado de Comunicación de la Policía Nacional.',
  'https://www.gob.pe/8806-denunciar-casos-que-no-respeten-el-aislamiento-o-la-inmovilizacion-social',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Denunciar la desaparición de una persona',
  'Si una persona se encuentra ausente de su domicilio habitual y se desconoce su paradero, se considera desaparecida.',
  'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/Index',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (MININTER / Denunciar llamadas de extorsionadores): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Denunciar llamadas de extorsionadores',
  'Si eres víctima de extorsiones telefónicas, puedes denunciarlo telefónicamente a la Policía Nacional del Perú (PNP) para que hagan las investigaciones correspondientes. Adicionalmente, sigue estas recomendaciones: Solicita a tu empresa operadora el registro de tus llamadas.',
  'https://www.gob.pe/573-denunciar-llamadas-de-extorsionadores',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (MININTER / Denunciar un presunto delito ante el Ministerio del Interior): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MININTER'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Denunciar un presunto delito ante el Ministerio del Interior a través del app CUD 1818',
  'Puedes denunciar un presunto acto indebido de la Policía Nacional, personal del Ministerio del Interior, trata de personas, violencia contra la mujer, venta de drogas u otro tipo de denuncias, mediante la aplicación CUD 1818. Este aplicativo móvil sirve para que la ciudadanía.',
  'https://www.gob.pe/72311-denunciar-un-presunto-delito-ante-el-ministerio-del-interior-a-traves-del-app-cud-1818',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));



-- REVISAR (PJ / Antecedentes Penales): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Antecedentes Penales',
  'Es un documento oficial que certifica si una persona registra o no sentencias condenatorias impuestas como consecuencia de haber cometido un delito. El Certificado de Antecedentes Penales, como documento oficial, es utilizado para realizar diversos trámites personales ante.',
  'https://cape.pj.gob.pe/cape/pages/terminos-uso.xhtml',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (PJ / Autenticación de documentos y certificación de firma por fed): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI, pasaporte o carnet de extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Si el trámite lo hace un apoderado, deberá presentar además los documentos que lo acrediten.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autenticación de documentos y certificación de firma por fedatario de la Corte Superior',
  'Dónde: Registro Nacional de CondenasHorario:&nbsp;&nbsp;8:00 a.m. a 1:30 p.m. y 2:15 p.m. a 4:15 p.m. Costo: GratuitoCalificación:&nbsp; Automática - X 2 días hábilesCuando el cumplimiento de los requisitos solicitados es suficiente para dar por cumplido el trámite o servicio.',
  'https://www.gob.pe/20576-autenticacion-de-documentos-y-certificacion-de-firma-por-fedatario-de-la-corte-superior',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (PJ / Certificación de libros de los martilleros públicos): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documentos originales');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Copias de los Documentos a fedatear.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Certificación de libros de los martilleros públicos',
  'Registro Nacional de CondenasHorario:&nbsp;&nbsp;8:00 a.m. a 1:30 p.m. y 2:15 p.m. a 4:15 p.m. Costo: S/.70.70 por cada Libro. Calificación: Automática - x 7 dias hábilesCuando el cumplimiento de los requisitos solicitados es suficiente para dar por cumplido el trámite o.',
  'https://www.gob.pe/20626-certificacion-de-libros-de-los-martilleros-publicos',
  'VIRTUAL',
  70.70
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (PJ / Constancia de inscripción del perito judicial): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud dirigida al Presidente de la Corte Superior, en el lugar de residencia del Martillero.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Recibo de pago del Banco de la Nación.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Resolución de nombramiento como Martillero expedida por la Superintendencia Nacional de Registros Públicos (publicada en el Diario Oficial El Peruano)');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Constancia de inscripción del perito judicial',
  'Registro Nacional de CondenasHorario:&nbsp;&nbsp;8:00 a.m. a 1:30 p.m. y 2:15 p.m. a 4:15 p.m. Costo: 0.5039% UIT (S/.19.40) Calificación:&nbsp; Automática - X 3 días hábilesCuando el cumplimiento de los requisitos solicitados es suficiente para dar por cumplido el trámite o.',
  'https://www.gob.pe/20621-constancia-de-inscripcion-del-perito-judicial',
  'VIRTUAL',
  19.40
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (PJ / Consultar Casilleros Digitales de jueces y juezas): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud dirigida al Jefe de la Oficina de Administración Distrital de la Corte Superior.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Comprobante de pago emitido por el Banco de la Nación');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar Casilleros Digitales de jueces y juezas',
  'Si deseas consultar las resoluciones que emite cada magistrado en su trabajo jurisdiccional, puedes ingresar a los casilleros digitales de jueces y juezas. Este servicio se encuentra disponible las 24 horas del día, los 365 días del año.',
  'https://sap.pj.gob.pe/casillero-digital-web/#/busqueda',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (PJ / Consultar Casilleros Digitales de jueces y juezas): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (PJ / Consultar Jurisprudencia Nacional Sistematizada): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar Jurisprudencia Nacional Sistematizada',
  'Si eres un litigante, estudias derecho o estás interesado en conocimiento legal, y deseas enterarte de los principales lineamientos y criterios jurídicos establecidos por las salas especializadas de la Corte Suprema de Justicia, puedes consultar este servicio del Poder.',
  'https://jurisprudencia.pj.gob.pe/jurisprudenciaweb/faces/page/inicio.xhtml',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (PJ / Consultar Jurisprudencia Nacional Sistematizada): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (PJ / Consultar Registro de Deudores Alimentarios Morosos - Redam): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar Registro de Deudores Alimentarios Morosos - Redam',
  'Si deseas conocer el nombre de las personas que no están cumpliendo con el pago de sus obligaciones alimentarias, puedes hacerlo a través del siguiente aplicativo. Toma en cuenta que el sistema solo muestra la información que ha sido debidamente cargada por los órganos.',
  'https://casillas.pj.gob.pe/redam/#/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pagos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (PJ / Consultar certificados y boletas de pago electrónico como tr): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Nombre o DNI de la persona a consultar.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Consultar certificados y boletas de pago electrónico como trabajador del Poder Judicial',
  'Si, como servidor interno del Poder Judicial a nivel nacional, deseas consultar o imprimir tu Boleta de Pago de Planilla Electrónica, Certificado de Retenciones de Cuarta y Quinta Categoría, así como el Depósito de la Compensación por Tiempo de Servicios, puedes realizarlo.',
  'https://aplicativo.pj.gob.pe/sisbpe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));

-- REVISAR (PJ / Consultar edictos judiciales vía electrónica): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Usuario y contraseña del sistema.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar edictos judiciales vía electrónica',
  'Si quieres consultar los edictos judiciales (notificaciones de resoluciones judiciales que se hace a las partes que intervienen en el proceso) publicados por los órganos jurisdiccionales, tienes a tu disposición el Servicio de Edicto Judicial Electrónico.',
  'http://cej.pj.gob.pe/edictos/pages/boletin.xhtml',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (PJ / Consultar edictos judiciales vía electrónica): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (PJ / Consultar el estado situacional de expedientes judiciales): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar el estado situacional de expedientes judiciales',
  'El trámite es informativo y cuesta S/ 1.00 por los últimos 5 actos procesales. Observaciones a tener en cuenta al realizar el trámite: Emisión de reportes impresos: Indicar el N° de expediente. Pago de derecho de Trámite en caja.',
  'https://www.gob.pe/20613-consultar-el-estado-situacional-de-expedientes-judiciales',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));

-- REVISAR (PJ / Consultar expedientes judiciales de la Corte Suprema): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar expedientes judiciales de la Corte Suprema',
  'Mediante esta plataforma, podrás buscar expedientes tramitados ante la Corte Suprema de la República.',
  'https://apps.pj.gob.pe/cejSupremo/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (PJ / Consultar información sobre magistrado - Conoce a tu Juez): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Consultar información sobre magistrado - Conoce a tu Juez',
  'Si requieres información sobre los jueces y juezas como su nombre, el juzgado donde labora, la dirección donde está ubicado y cómo localizarlo a través de Google maps; podrás hacerlo a través de esta plataforma.',
  'https://sap.pj.gob.pe/casillero-digital/#/conoce-tu-juez',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (PJ / Consultar módulo de sentido de decisiones judiciales): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar módulo de sentido de decisiones judiciales',
  'Mediante este registro, puedes acceder en forma sencilla a todas y cada una de las decisiones jurisdiccionales que jueces o tribunales emiten en un proceso judicial (autos y sentencias), las cuales son publicadas en el día de votación del juzgado. El funcionamiento de este.',
  'https://gestionsij.pj.gob.pe/sentidoFallo-web/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (PJ / Consultar notificaciones judiciales enviadas - Consernot): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar notificaciones judiciales enviadas - Consernot',
  'Si quieres consultar notificaciones judiciales referidas al emplazamiento o citación al demandado, rebeldes no apersonados o citaciones para la lectura de sentencias de procesos, entre otras, enviadas físicamente por el Sernot (Servicio de Notificaciones del Poder Judicial).',
  'http://consernot.pj.gob.pe/sernot/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (PJ / Consultar notificaciones judiciales enviadas - Consernot): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (PJ / Consultar programación de tu audiencia): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'PJ'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar programación de tu audiencia',
  'Si necesitas saber cuál es la fecha y hora de tu audiencia a desarrollarse en tu distrito judicial, puedes consultar la guía de programación digital del Poder Judicial. Toma en cuenta que para usar la guía eficientemente necesitas saber el distrito judicial o el centro.',
  'https://apps.pj.gob.pe/guiaprogramacion/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (PJ / Consultar programación de tu audiencia): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Acceder a centro de arbitraje popular Arbitra Perú): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a centro de arbitraje popular Arbitra Perú',
  'El Centro de Arbitraje Popular «Arbitra Perú» es una institución arbitral creada por el Ministerio de Justicia y Derechos Humanos (MINJUSDH), cuya finalidad es facilitar el acceso a la justicia mediante el arbitraje como mecanismo alternativo de solución de controversias.',
  'https://www.gob.pe/14689-acceder-a-centro-de-arbitraje-popular-arbitra-peru',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Acceder a centro de arbitraje popular Arbitra Perú): ninguna etiqueta matcheo, asignar a mano si aplica

INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud simple dirigida al coordinador administrativo del Centro de Arbitraje del Ministerio de Justicia, que contenga:');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Datos de identificación y domicilio del demandante: nombre, número de DNI, número de teléfono, correo electrónico o cualquier otro medio de comunicación para las notificaciones, y domicilio real que debe estar dentro del radio urbano donde funciona Arbitra Perú.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Copia del poder si se actúa a través de un representante. Si eres persona jurídica: datos de la razón social, de su inscripción en el registro de Personas Jurídicas, y copia de los poderes inscritos en los Registros Públicos.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Datos de identificación y domicilio del demandado para notificarlo adecuadamente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Pretensión de la demanda, incluyendo un resumen de la controversia o conflicto, y precisión de las pretensiones y el monto involucrado.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Designación del árbitro: el nombre del árbitro designado por el o la demandante, el que debe formar parte de la Nómina de Árbitros de Arbitra Perú. En caso de no designar al árbitro, debes indicar el procedimiento pactado para su designación o su sometimiento al árbitro que designe Arbitra Perú.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 7, 'Reglas: la indicación de cuáles son las reglas que se aplicarán al procedimiento arbitral o la indicación de que estas son determinadas por Arbitra Perú, con la aceptación expresa de someterse a ellas.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 8, 'Medida cautelar: debes informar si se ha ejecutado una medida cautelar antes de la solicitud de arbitraje.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 9, 'Copia de contrato que contenga lacláusula arbitralo delconvenio arbitral.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la lista de abogados sancionados por mala práctica  profesional',
  'Para averiguar si un abogado ha sido sancionado por alguna conducta antiética, puedes hacerlo de manera gratuita ingresando al Registro Nacional de Abogados Sancionados por Mala Práctica Profesional. Este registro fue creado por el Ministerio de Justicia y Derechos Humanos.',
  'https://rnas.minjus.gob.pe/rnas/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (MINJUS / Acceder a los servicios digitales del Sistema Integrado de J): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los servicios digitales del Sistema Integrado de Justicia',
  'Puedes encontrar información sobre los servicios digitales del Ministerio de Justicia y Derechos Humanos (Minjusdh) con la aplicación Sistema Integrado de Justicia. Esta aplicación móvil sirve para que los usuarios encuentren información sobre servicios como el Sistema de.',
  'https://www.gob.pe/66362-acceder-a-los-servicios-digitales-del-sistema-integrado-de-justicia',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Acceder a los servicios digitales del Sistema Integrado de J): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Acceder al aplicativo móvil del Sistema Peruano de Informaci): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Teléfono con sistema operativo Android.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al aplicativo móvil del Sistema Peruano de Información Jurídica (SPIJ)',
  'Podrás consultar normativa de acceso libre mediante el SPIJ Móvil. Para ello, solo descarga la aplicación del SPIJ desde tu teléfono celular, ingresando a Play Store si usas Android, o desde tu iPhone ingresando a App Store.',
  'https://www.gob.pe/749-acceder-al-aplicativo-movil-del-sistema-peruano-de-informacion-juridica-spij',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Acceder al aplicativo móvil del Sistema Peruano de Informaci): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Acreditación de conciliador extrajudicial): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acreditación de conciliador extrajudicial',
  'Base Legal: ARTÍCULO 33º DEL REGLAMENTO DE LA LEY N.º 26872 APROBADO POR D. S. 014-2008-JUS. NUMERAL 40.1.5 DEL ARTÍCULO 40º DE LA LEY Nº. 27444, LEY DEL PROCEDIMIENTO ADMINISTRATIVO GENERAL.',
  'https://www.gob.pe/21820-acreditacion-de-conciliador-extrajudicial',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Acreditación de conciliador extrajudicial): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Acreditación de municipalidades para llevar a efecto el proc): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acreditación de municipalidades para llevar a efecto el procedimiento no contencioso de la separación convencional y divorcio ulterior - Ley Nº 29227',
  'Base Legal: ARTÍCULO 8º DE LA LEY N.º 29227, LEY QUE REGULA EL PROCEDIMIENTO NO CONTENCIOSO DE LA SEPARACIÓN CONVENCIONAL Y DIVORCIO ULTERIOR EN LAS MUNICIPALIDADES Y NOTARÍAS. ARTÍCULO 16ºDEL REGLAMENTO DE LA LEY N.º 29227, LEY QUE REGULA EL PROCEDIMIENTO NO CONTENCIOSO.',
  'https://www.gob.pe/21823-acreditacion-de-municipalidades-para-llevar-a-efecto-el-procedimiento-no-contencioso-de-la-separacion-convencional-y-divorcio-ulterior-ley-n-29227',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Acreditación de municipalidades para llevar a efecto el proc): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Autorización de cierre de centro de conciliación): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización de cierre de centro de conciliación',
  'Base Legal: ARTÍCULOS 58º Y 87 DEL REGLAMENTO DE LA LEY N.º 26872, APROBADO POR D.',
  'https://www.gob.pe/21815-autorizacion-de-cierre-de-centro-de-conciliacion',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Autorización de cierre de centro de conciliación): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Autorización de cierre de centros de formación y capacitació): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización de cierre de centros de formación y capacitación de conciliadores',
  'Base Legal: ARTÍCULOS 86º Y 87º DEL REGLAMENTO DE LA LEY N.º 26872, APROBADO POR D.',
  'https://www.gob.pe/21821-autorizacion-de-cierre-de-centros-de-formacion-y-capacitacion-de-conciliadores',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('capacitacion');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'capacitacion'));

-- REVISAR (MINJUS / Autorización de funcionamiento de centro de conciliación): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización de funcionamiento de centro de conciliación',
  'Base Legal: Artículo 27º de la ley N.º 26872 - ley de conciliación. Articulos 47º y 53º del reglamento de la ley Nº 26872, aprobado por D.',
  'https://www.gob.pe/21811-autorizacion-de-funcionamiento-de-centro-de-conciliacion',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Autorización de funcionamiento de centro de conciliación): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Autorización para el cambio de dirección del centro de conci): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para el cambio de dirección del centro de conciliación',
  'Autorización para el cambio de dirección de Centro de Conciliación.',
  'https://www.gob.pe/21828-autorizacion-para-el-cambio-de-direccion-del-centro-de-conciliacion',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Autorización para el cambio de dirección del centro de conci): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Autorización para funcionamiento de centro de formación y ca): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para funcionamiento de centro de formación y capacitación de conciliadores',
  'Base Legal: ARTÍCULOS 71º, 72º, 73º Y 74º DEL REGLAMENTO DE LA LEY N.º 26872, APROBADO POR D.',
  'https://www.gob.pe/21817-autorizacion-para-funcionamiento-de-centro-de-formacion-y-capacitacion-de-conciliadores',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'capacitacion'));

-- REVISAR (MINJUS / Autorización para la variación del dictado de curso de forma): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización para la variación del dictado de curso de formación y capacitación',
  'Base Legal: ARTÍCULO 79º DEL REGLAMENTO DE LA LEY N.º 26872, APROBADO POR D.',
  'https://www.gob.pe/21819-autorizacion-para-la-variacion-del-dictado-de-curso-de-formacion-y-capacitacion',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'capacitacion'));

-- REVISAR (MINJUS / Autorización y registro de modificación de la información de): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización y registro de modificación de la información de centros de conciliación y centros de formación',
  'Base Legal: ARTÍCULO 54º DEL REGLAMENTO DE LA LEY N.º 26872, APROBADO POR D.',
  'https://www.gob.pe/21813-autorizacion-y-registro-de-modificacion-de-la-informacion-de-centros-de-conciliacion-y-centros-de-formacion',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (MINJUS / Calificación de capacitador para el módulo de conceptos lega): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Calificación de capacitador para el módulo de conceptos legales básicos',
  'El trámite es Interactivo ¿Cuanto cuesta realizar el trámite?',
  'https://www.gob.pe/21826-calificacion-de-capacitador-para-el-modulo-de-conceptos-legales-basicos',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MINJUS / Calificación de capacitador para el módulo de conceptos lega): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MINJUS / Capacitarse en el Centro de Estudios en Justicia y Derechos ): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINJUS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Capacitarse en el Centro de Estudios en Justicia y Derechos Humanos',
  'Si estás interesado en capacitarte en temas de justicia y derechos humanos, puedes participar en los cursos, seminarios y conferencias del Centro de Estudios en Justicia y Derechos Humanos del Ministerio de Justicia y Derechos Humanos (MINJUSDH).',
  'https://www.gob.pe/44163-capacitarse-en-el-centro-de-estudios-en-justicia-y-derechos-humanos',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'capacitacion'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('educacion');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (SIS / Acceder a la plataforma de datos abiertos del SIS): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Acceder a la plataforma de datos abiertos del SIS',
  'Si quieres acceder a información detallada sobre atenciones oncológicas, medicamentos para recién nacidos y diagnóstico de diabetes mellitus del Seguro Integral de Salud (SIS) puedes hacerlo a través de la Plataforma Nacional de Datos Abiertos (PNDA) de la Presidencia.',
  'https://www.datosabiertos.gob.pe/group/seguro-integral-de-salud-sis?fbclid=IwZXh0bgNhZW0CMTAAAR2oJgvEoiOBCefCcCwKvJJh7a3xRRlJHgAMkxZZUXdaqAQlA3B9NB5fJaE_aem_ATb_lLrKW4GthQYtEnF9e73mw9_BNMBvXWmHHRPPFTnYWTbhLPJHzefeLe3TLxoJp8yD_X-rLe9pOBrPnuiNwh3_',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('salud');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (SIS / Acceder al repositorio Institucional del Seguro Integral de ): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al repositorio Institucional del Seguro Integral de Salud - SIS',
  'Si quieres acceder a material académico e informativo sobre temas de salud, puedes ingresar al repositorio Institucional del Seguro Integral de Salud (SIS). Este servicio es gratuito y de acceso libre&nbsp;e implementado en una herramienta denominada DSpace, que recopila.',
  'https://repositorio.sis.gob.pe/home',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (SIS / Afiliarte al SIS Emprendedor): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Afiliarte al SIS Emprendedor',
  'Este plan de seguro de salud es para los ciudadanos residentes dentro del territorio nacional con el cual se atenderán de manera gratuita en todos los centros de salud públicos del Ministerio de Salud y de los gobiernos regionales. Ofrece una cobertura integral que cubre más de 12 mil diagnósticos, incluidos varios tipos de cáncer, enfermedades raras y huérfanas.',
  'https://www.gob.pe/152-afiliarte-al-sis-emprendedor',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Afiliarte al SIS Gratuito): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Afiliarte al SIS Gratuito',
  'Este plan de seguro de salud es subsidiado por el estado, para que todos los residentes en el territorio peruano puedan acceder de manera gratuita a los servicios de salud en los establecimientos de salud públicos del Ministerio de Salud y de los gobiernos regionales.',
  'https://afiliacion.sis.gob.pe/sisAfiliacionVirtual',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Afiliarte al SIS Independiente): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de DNI o carnet de extranjería.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Afiliarte al SIS Independiente',
  'El SIS Independiente es un plan de seguro de salud dirigido a personas y familias que no cuenten con otro seguro de salud y puedan pagar un aporte mensual.',
  'https://www.gob.pe/172-afiliarte-al-sis-independiente',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Afiliarte al SIS Microempresas): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Afiliarte al SIS Microempresas',
  'Este plan de seguro de salud del SIS es para los trabajadores de las microempresas con el cual podrán atenderse de manera gratuita en todos los centros de salud públicos del Ministerio de Salud y de los gobiernos regionales. El costo de este seguro es asumido por la microempresa pero está semi subsidiado por el estado. El proceso de afiliación al seguro lo realiza exclusivamente el empleador y no los trabajadores.',
  'https://www.gob.pe/180-afiliarte-al-sis-microempresas',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Buscar Establecimientos de Salud a nivel nacional): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar Establecimientos de Salud a nivel nacional',
  'Conoce cuáles son los establecimientos de salud más cercanos a tu casa o del lugar donde te encuentras, puedes hacerlo de manera online mediante el Buscador Nacional de Establecimientos de Salud del SIS.',
  'https://sigeps.sis.gob.pe/BuscadorEESS/PortalSIS/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Cambiar mi centro de salud SIS): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Cambiar mi centro de salud SIS',
  'Si estás afiliado a un plan de Seguro Integral de Salud (SIS) y deseas cambiar el centro de salud que tienes asignado, puedes hacerlo de manera virtual mediante su aplicación móvil SIS.',
  'https://play.google.com/store/apps/details?id=gob.pe.sis',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Consultar el estado de un trámite de sepelios): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNIocarnet de extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Número de celular.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar el estado de un trámite de sepelios',
  'Si tienes un reembolso por sepelio pendiente con el Seguro Integral de Salud (SIS) y ya lo tramitaste, puedes averiguar el estado de tu trámite a través del servicio.',
  'https://www.sis.gob.pe/NUEVO/consultaSepelio/frmConsultaSepelioOnLine.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Planes del Seguro Integral de Salud (SIS)): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI o Carné de Extranjería del afiliado fallecido.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'DNI o Carné de Extranjería de la persona que realizó el pago del servicio.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'DNI o Carné de Extranjería del acreditado.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Planes del Seguro Integral de Salud (SIS)',
  'El SIS es un seguro de salud dirigido para todas las personas residentes en el Perú que no cuenten con otro seguro de salud. El SIS cubre tus medicinas, procedimientos, operaciones, insumos, beneficio de sepelio y traslados de emergencia. Cubre más de 12 mil diagnósticos.',
  'http://app.sis.gob.pe/SisConsultaEnLinea/Consulta/frmConsultaEnLinea.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Preguntas frecuentes de los planes de seguros SIS): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Preguntas frecuentes de los planes de seguros SIS',
  'Aquí podrás encontrar respuestas a las preguntas más frecuentes que puedas tener sobre los planes de seguros que ofrece el Seguro Integral de Salud (SIS) a todos sus asegurados y público en general.',
  'https://www.gob.pe/76693-preguntas-frecuentes-de-los-planes-de-seguros-sis',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Acceder a la mesa de partes virtual del Seguro Integral de S): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la mesa de partes virtual del Seguro Integral de Salud (SIS)',
  'Si necesitas enviar documentos para realizar tus trámites, puedes hacerlo a través de la mesa de partes de las entidades públicas.',
  'https://mpv.sis.gob.pe:8181/appmesapartesenlinea/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (SIS / Presentar una queja o reclamo en el Seguro Integral de Salud): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI, RUC, pasaporte o carnet de extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico y teléfono de contacto.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Documento que sustente el trámite que deseas realizar debe ser legible, estar en formato PDF y debe incluir tus datos personales, documento de identificación, dirección, correo electrónico, teléfono y firma, según lo señalado en el artículo 113 delTexto Único Ordenado de la Ley N° 27444, Ley del Pro');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'El documento principal debe sustentar el trámite que deseas realizar. Podrás incluir anexos o documentos adjuntos. En el caso que desees y sea necesario ampliar la información, puedes incluir hasta 10 anexos de 10 MB (como máximo) cada uno en formato PDF, Word, Excel y JPG, además puedes ingresar un');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Los documentos que envíes tienen carácter de declaración jurada. Eres responsable de su contenido y registro de información. Por ello, te sugerimos revisar elmanual del usuario.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Presentar una queja o reclamo en el Seguro Integral de Salud (SIS)',
  'Si estás insatisfecho o disconforme con la atención brindada en una entidad pública, puedes presentar una queja o reclamo en su Libro de Reclamaciones. Con esto, se busca proteger tus derechos y lograr la eficiencia del Estado en la atención de los servicios brindados.',
  'https://www.gob.pe/387-seguro-integral-de-salud-presentar-una-queja-o-reclamo-en-el-seguro-integral-de-salud-sis',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SIS / Solicitar acceso a la información pública): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Solicitar acceso a la información pública',
  'Puedes acceder a la información de las instituciones del Estado según el principio de transparencia, el Texto Único Ordenado de la Ley N° 27806, Ley de Transparencia y Acceso a la Información Pública , y el Reglamento de la Ley N°27806, Ley de Transparencia y Acceso a la Información pública .',
  'https://www.gob.pe/111009-seguro-integral-de-salud-solicitar-acceso-a-la-informacion-publica',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('transparencia');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'transparencia'));

-- REVISAR (MINSA / Acceder a la Red Nacional de Investigación en Tuberculosis (): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Nombres y apellidos, número de identificación y domicilio.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Firma o huella digital, que debes completar en la unidad de recepción documental de la entidad.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Solicitud simple, debidamente llenado, indicando la expresión concreta y precisa de la información que requieres.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Si vas a solicitar la información por un medio digital, indica tu correo electrónico y teléfono de contacto.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'De manera opcional, puedes indicar la dependencia que posee la información, los datos que propicien la localización de la misma; y datos personales del solicitante como sexo, edad, discapacidad, entre otros.');




INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la Red Nacional de Investigación en Tuberculosis (RENAI TB)',
  'Si eres un profesional de la salud o investigador interesado en estudios sobre tuberculosis (TB) en el Perú, puedes acceder a la información disponible a través de la Red Nacional de Investigación en Tuberculosis (RENAI TB). Esta red articula la colaboración entre instituciones.',
  'http://www.tuberculosis.minsa.gob.pe/renai-tb',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('salud');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('educacion');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (MINSA / Acceder a los servicios de salud en Minsa Digital): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Organización y líneas de acción de la red.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Eventos científicos y espacios de difusión de investigaciones.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Documentación y evidencias científicas disponibles.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Normatividad y requisitos de afiliación.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a los servicios de salud en Minsa Digital',
  'Si eres paciente del Ministerio de Salud (Minsa), puedes gestionar tus atenciones médicas de forma virtual a través de la plataforma Minsa Digital.',
  'https://minsadigital.minsa.gob.pe/',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('citas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MINSA / Acceder a orientación y métodos de planificación familiar): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento de Identidad(DNI o Carnet de Extranjería).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónicoynúmero de celular personal.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Acceder a orientación y métodos de planificación familiar',
  'Si necesitas acceder a un método anticonceptivo como condones, pastillas anticonceptivas, implante subdérmico, vasectomía y ligadura de trompas , o recibir orientación sobre cómo prevenir un embarazo no planificado , puedes acudir a cualquier establecimiento de salud del Ministerio de Salud (Minsa).',
  'https://www.gob.pe/111276-acceder-a-orientacion-y-metodos-de-planificacion-familiar',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (MINSA / Acceder al Buzón de Sugerencias Virtual del Ministerio de Sa): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento de Identidad (DNI, carnet de extranjería o pasaporte).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Buzón de Sugerencias Virtual del Ministerio de Salud',
  'Si tienes un comentario o una propuesta para optimizar la eficiencia, calidad o la experiencia general de los servicios que brinda el Ministerio de Salud (Minsa), puedes enviarla en línea a través del Buzón de Sugerencias Virtual del Ministerio de Salud (Minsa).',
  'https://sgd.minsa.gob.pe/appmesapartesenlinea/buzondesugerencia',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (MINSA / Acceder al Libro de Reclamaciones en Salud del SAMU para Lim): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'No necesitas presentar documentos ni cumplir requisitos previos.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Libro de Reclamaciones en Salud del SAMU para Lima Metropolitana',
  'Si has recibido atención por el Sistema de Atención Móvil de Urgencia (SAMU) del Ministerio de Salud en Lima Metropolitana, y deseas presentar una insatisfacción, queja o reclamo, debes completar el Libro de Reclamaciones en Salud. Este registro permite a la entidad mejorar la.',
  'https://www.gob.pe/24223-acceder-al-libro-de-reclamaciones-en-salud-del-samu-para-lima-metropolitana',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (MINSA / Acceder al Registro Médico Electrónico (EMR)): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento de identidad (DNI, carnet de extranjería o pasaporte).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Formulario del Libro de reclamaciones, si realizas el trámite de forma virtual.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Registro Médico Electrónico (EMR)',
  'Si eres personal de salud autorizado, puedes consultar en línea la información histórica de los casos de tuberculosis drogo resistente (TB DR) a través del Registro Médico Electrónico (EMR) del Ministerio de Salud (Minsa). Esta herramienta te permite acceder a diagnósticos.',
  'http://www.tuberculosis.minsa.gob.pe/PortalDpctb/rme/emr.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (MINSA / Acceder al Sistema de Alerta SERUMS (SAS)): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Usuario y contraseña.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema de Alerta SERUMS (SAS)',
  'Si eres profesional del Serums y necesitas reportar un incidente en tu lugar de labor, puedes hacerlo a través del Sistema de Alertas Serums (SAS). Esta plataforma del Ministerio de Salud (Minsa), gestionada por la Dirección General de Personal de la Salud (DIGEP), permite.',
  'http://inforhus.minsa.gob.pe/apps/sas/index.php',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MINSA / Acceder al Sistema de Información Gerencial de Tuberculosis ): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'No requiere presentar documentos ni cumplir requisitos previos.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Sistema de Información Gerencial de Tuberculosis (SIGTB)',
  'Si eres personal de salud autorizado y necesitas registrar o acceder a información de casos diagnosticados con tuberculosis (TB), puedes hacerlo online con el Sistema de Información Gerencial de Tuberculosis (SIGTB).',
  'https://appsalud.minsa.gob.pe/sigtbdata/wflogin.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (MINSA / Acceder al Tablero de Control PP 0018 del Ministerio de Salu): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Usuario y contraseña.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Tablero de Control PP 0018 del Ministerio de Salud',
  'Si necesitas monitorear la ejecución del presupuesto, las metas físicas y los indicadores analíticos de las enfermedades no transmisibles, puedes realizarlo en línea a través del visualizador interactivo del Ministerio de Salud (Minsa). En esta plataforma virtual, coordinada.',
  'https://mef.pythonanywhere.com',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MINSA / Acceder al Tablero de Control de las Declaratorias de Estado): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Tablero de Control de las Declaratorias de Estado de Emergencia',
  'Si necesitas visualizar las regiones, provincias y distritos declarados en estado de emergencia por peligro inminente o desastre, puedes hacerlo a través del Tablero de Control de las Declaratorias de Estado de Emergencia del Ministerio de Salud (Minsa).',
  'https://app.powerbi.com/view?r=eyJrIjoiZTVlYTM4ZDMtZTIyYy00ZjY5LThmM2EtZWIyZDNiMTRmMjQ3IiwidCI6Ijc5MDVjMWZjLTkzM2MtNDUyYS04YjgzLWIyZTU2NDU1ZDE2YSIsImMiOjR9',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (MINSA / Acceder al Visor de Seguimiento Financiero de Inversiones en): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'COE Salud');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Visor de Seguimiento Financiero de Inversiones en Salud 2024',
  'Si deseas conocer el estado financiero detallado de las inversiones en el sector salud, puedes hacerlo a través de la plataforma del Ministerio de Salud (Minsa). Este visor te permite consultar en tiempo real el avance del presupuesto (PIA, PIM, certificado, comprometido.',
  'https://app.powerbi.com/view?r=eyJrIjoiMTUwMmUwY2UtNTk1Mi00NmRjLTkwMWItMzE3NDIzMjFhNzhjIiwidCI6IjZkYmJmOWQ4LTAzNWEtNDhmMS04NmE5LTgyNDIwZjU3Y2M0MCJ9',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MINSA / Acceder al mapa interactivo de daños registrados en establec): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Oficina de Programación Multianual de Inversiones (OPMI) del sector Salud');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al mapa interactivo de daños registrados en establecimientos de salud por la temporada de lluvias',
  'Si deseas conocer la ubicación exacta de los establecimientos de salud y sedes administrativas afectados por la temporada de lluvias durante los años 2023 y 2024, puedes hacerlo a través de la plataforma del Ministerio de Salud (Minsa). Esta herramienta, gestionada por el COE.',
  'https://www.arcgis.com/apps/webappviewer/index.html?id=7a33a5568b824b41a866b74b8307543c',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MINSA / Acceder al mapa interactivo de establecimientos de salud afe): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'COE Salud');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al mapa interactivo de establecimientos de salud afectados por bajas temperaturas 2024',
  'Si necesitas conocer la ubicación exacta de los establecimientos de salud y sedes administrativas afectados por la temporada de bajas temperaturas 2024, puedes hacerlo a través del mapa temático del Ministerio de Salud (Minsa). Esta herramienta, elaborada por el COE Salud.',
  'https://www.arcgis.com/apps/webappviewer/index.html?id=415396c4d73f41af8b6456cc3bfa8dc5',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (MINSA / Acceder al tablero de control del Sistema de Registro de Eme): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'COE Salud');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al tablero de control del Sistema de Registro de Emergencias y Desastres (Sireed)',
  'Si deseas conocer el impacto de las emergencias y desastres monitoreados en el país, puedes hacerlo a través de la plataforma del Ministerio de Salud (Minsa). Este tablero de control, basado en los datos del Sireed, presenta información consolidada sobre los eventos registrados.',
  'https://app.powerbi.com/view?r=eyJrIjoiMDg1ZjJlNGUtY2FhNi00YTg4LWIzM2EtNzJmNmQ0NjRjMjBmIiwidCI6Ijc5MDVjMWZjLTkzM2MtNDUyYS04YjgzLWIyZTU2NDU1ZDE2YSIsImMiOjR9',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MINSA / Acceder al tablero de datos estadísticos sobre tuberculosis ): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'COE Salud');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MINSA'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al tablero de datos estadísticos sobre tuberculosis (TB) en el Perú',
  'Si deseas consultar la situación epidemiológica y estadística de la tuberculosis en el país, puedes hacerlo a través de la plataforma oficial del Ministerio de Salud (Minsa). Este tablero utiliza datos consolidados del Sistema de Información Gerencial de Tuberculosis (SIGTB).',
  'http://www.tuberculosis.minsa.gob.pe/DashboardDPCTB/Dashboard.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (ONP / Acceder a actividades virtuales para pensionistas - Yuyaq): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Dirección de Prevención y Control de Tuberculosis (DPCTB)');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Acceder al Sistema de Información Gerencial de Tuberculosis (SIGTB)');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Normativa en tuberculosis');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a actividades virtuales para pensionistas - Yuyaq',
  'Porque sabes que nunca dejamos de aprender, te invitamos a participar en las charlas y los talleres gratuitos de nuestro programa Yuyaq. La palabra “yuyaq”, en quechua, nos habla de alguien que piensa, que sabe. Igual que tú. En nuestras cuentas de Yuyaq en Facebook y YouTube.',
  'https://www.gob.pe/10300-acceder-a-actividades-virtuales-para-pensionistas-yuyaq',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Acceder a actividades virtuales para pensionistas - Yuyaq): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Acceder al Bono de Reconocimiento (BdR)): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Bono de Reconocimiento (BdR)',
  'Si optaste por dejar el Sistema Nacional de Pensiones (SNP) (D. L. N° 19990), para afiliarte al Sistema Privado de Pensiones (SPP), puedes solicitar este bono del Estado siempre que cuentes con alguno de los siguientes requisitos.',
  'https://www.gob.pe/12414-acceder-al-bono-de-reconocimiento-bdr',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Acceder al Bono de Reconocimiento (BdR)): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Afiliar el personal a mi cargo al Régimen Especial Pesquero): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Antes de tu incorporación al SPP, debes haber aportado 4 años (48 unidades de aporte) al SNP, ya sea de manera consecutiva o no.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Debes haber aportado al SNP durante las siguientes fechas:');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Bono 1992: entre el 6 de diciembre de 1982 y el 5 de diciembre de 1992.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Bono 1996:entre el 1 de enero de 1987 y el 31 de diciembre de 1996. En este caso se requiere que la afiliación al SPP se haya producido entre el 6 de noviembre de 1996 y el 31 de diciembre de 1997.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Bono 2001:entre el 1 de enero de 1992 y el 31 de diciembre de 2001.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Afiliar el personal a mi cargo al Régimen Especial Pesquero',
  'Si eres armador pesquero o representante legal de una empresa con embarcación pesquera autorizada para la pesca por el Ministerio de la Producción y necesitas afiliar al personal a tu cargo al Régimen Especial Pesquero - REP (Ley N° 30003), podrás hacerlo ingresando al Módulo.',
  'https://app.onp.gob.pe/MAF/paginas/registro/bienvenidaPescador.faces',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (ONP / Aseguramiento facultativo al Sistema Nacional de Pensiones (): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de RUC de la entidad pesquera.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Datos del representante de la entidad pesquera.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Estar previamente registrado en el Módulo de Registro. Si no cuentas con este acceso, podrás solicitarla en el mismo módulo, seleccionando la opción ''Solicitud de acceso armador''.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aseguramiento facultativo al Sistema Nacional de Pensiones (SNP)',
  'Si trabajas de manera independiente y deseas asegurar tu futuro y el de tu familia, afíliate al Sistema Nacional de Pensiones (SNP) de manera facultativa. En caso culmine tu vínculo laboral, puedes seguir realizando aportes de manera facultativa, teniendo en cuenta lo.',
  'https://aseguramiento.onp.gob.pe/facultativo/#/inicio/solicitud-incorporacion-SNP',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Aseguramiento facultativo al Sistema Nacional de Pensiones (): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Cobrar pensión en el extranjero): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Eres trabajador independiente (no tienes empleador).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'No estar afiliado alSistema Privado de Pensiones (SPP).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'No eres pensionista de discapacidad o de jubilación en el SNP.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'No eres beneficiario del Programa Nacional de Asistencia Solidaria Pensión 65, Programa Nacional de entrega de la pensión no contributiva a personas con discapacidad severa en situación de pobreza - CONTIGO o de una pensión no contributiva a cargo del MIDIS.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'No recibes pensión a cargo del Estado.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Cobrar pensión en el extranjero',
  'Si eres pensionista del Sistema Nacional de Pensiones ( D. L. N° 19990 ) y vives en Argentina, Canadá, Chile, Ecuador, Uruguay, España u otro país comprendido en el Convenio Multilateral Iberoamericano de Seguridad Social, puedes recibir tu pensión en el país de residencia, cada mes, mediante transferencias bancarias.',
  'https://www.gob.pe/10299-cobrar-pension-en-el-extranjero',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('migraciones');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (ONP / Consulta el estado de tu trámite administrativo ante la ONP): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formulario de exportacióndel país en el que radicas.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consulta el estado de tu trámite administrativo ante la ONP',
  'A través de este canal puedes consultar el estado de los trámites presentados en la Mesa de Partes presencial de la sede central Centro Cívico o en la Mesa de Partes Digital. Importante: Esta plataforma está habilitada exclusivamente para la consulta de solicitudes o trámites.',
  'https://consultasgd.onp.gob.pe/consultatutramiteonp/inicio.do',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (ONP / Consultar comprobantes de pago del Seguro Complementario de ): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de expediente con el que fue registrado tu trámite.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar comprobantes de pago del Seguro Complementario de Trabajo de Riesgo (SCTR)',
  'Si tienes una póliza del Seguro Complementario de Trabajo de Riesgo (SCTR) y deseas consultar o descargar tus comprobantes de pago, puedes hacerlo online a través de este servicio.',
  'http://see.ebizlatin.com/#/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pagos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));

-- REVISAR (ONP / Consultar constancias de pago de pensiones en la ONP): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar constancias de pago de pensiones en la ONP',
  'Si eres pensionista de algún régimen administrado por la Oficina de Normalización Previsional (ONP), puedes ver el contenido de tu boleta de pago de pensiones del mes a través de su plataforma Soy Pensionista.',
  'https://tuzonasegura.onp.gob.pe',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (ONP / Consultar declaraciones indebidas al Sistema Nacional de Pen): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Clave virtual ONP. Si no tienes una,puedes solicitarla en línea.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar declaraciones indebidas al Sistema Nacional de Pensiones',
  'Si eres empleador o empleadora, es posible que hayas realizado declaraciones indebidas al Sistema Nacional de Pensiones (D. L. N° 19990) por trabajadores afiliados a una AFP. Verifícalo a través de este servicio.',
  'https://www.onp.gob.pe/servicios/soy_empleador/consultar_pagos_indebidos_al_snp/1',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Consultar declaraciones indebidas al Sistema Nacional de Pen): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Consultar documentos no notificados para independientes): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de RUC de tu empresa.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar documentos no notificados para independientes',
  'Si eres afiliado(a) independiente y no has recibido cartas, notificaciones o resoluciones sobre tu afiliación u otras solicitudes, podrás consultar la documentación no recibida a través de este servicio.',
  'https://www.onp.gob.pe/Paginas/ResolucionesnoEntregadasdenotificacionesdeSeguroFacultativo.aspx#titleMixto',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Consultar documentos no notificados para independientes): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Consultar documentos no notificados por Libre Desafiliación ): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documentación previa');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar documentos no notificados por Libre Desafiliación Informada del Sistema Privado de Pensiones',
  'Si retornaste al Sistema Nacional de Pensiones (SNP) luego del proceso de Libre Desafiliación Informada (LDI), pero no recibiste tu carta u oficio emitido por la ONP, puedes consultar la relación de documentos que no fueron notificados, así como su fecha de emisión y tu.',
  'https://www.onp.gob.pe/Paginas/LibreDesafiliacionInformada.aspx#titleMixto',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Consultar documentos no notificados por Libre Desafiliación ): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Consultar documentos no recibidos por el empleador): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar documentos no recibidos por el empleador',
  'Si eres empleador y realizaste trámites ante la ONP por pagos indebidos de trabajadores afiliados a una AFP, puedes consultar la relación de documentos rezagados o no entregados sobre pagos indebidos.',
  'https://www.onp.gob.pe/Paginas/DocumentosONPNoRecibidosEmp.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));

-- REVISAR (ONP / Consultar e imprimir información de pensionista): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar e imprimir información de pensionista',
  'Este servicio te permite consultar e imprimir información sobre pensionistas y beneficiarios de los regímenes previsionales administrados por la ONP.',
  'https://zonasegura.onp.gob.pe/ONP.PortalONP.Web/soy_pensionista/consultar_imprimir_informacion_pensionista_onp',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Consultar e imprimir información de pensionista): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Consultar el estado de solicitudes a entidades externas a la): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar el estado de solicitudes a entidades externas a la ONP',
  'Si perteneces al Sistema Nacional de Pensiones (SNP) y esperas la respuesta a una solicitud que hiciste a una entidad distinta de la Oficina de Normalización Previsional (ONP), puedes consultar su estado en el servicio Consulta tu Expediente.',
  'https://www.onp.gob.pe/Paginas/ExpedientesEnEsperadeRespuestadeEntidadesExternas.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONP / Consultar el estado de solicitudes a entidades externas a la): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONP / Consultar importes no cobrados por pensionista fallecida(o)): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONP'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar importes no cobrados por pensionista fallecida(o)',
  'Este es un servicio gratuito de la Oficina de Normalización Previsional (ONP) que permite a los beneficiarios debidamente acreditados de un/una pensionista fallecida(o) consultar si existe registrado en el sistema de planillas algún mes en el que la/el pensionista no cobró.',
  'https://www.onp.gob.pe/paginas/otrasolicitud.aspx',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (MIDIS / Acceder al ChatBot Suyay): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Solicitud simple presentada por una(o) de sus hijas(os) o la/el cónyuge.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Sucesión intestada o declaratoria de herederos del (a) pensionista fallecida(o).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al ChatBot Suyay',
  'Si necesitas consultar sobre los programas sociales y otros servicios que ofrece el Ministerio de Desarrollo e Inclusión Social (Midis), puedes hacerlo a través de su chat virtual, para que obtengas respuestas inmediatas de orientadores especializados.',
  'https://app.midis.gob.pe/Sis_Chatbot',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MIDIS / Acceder al bono Yo me quedo en casa): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al bono Yo me quedo en casa',
  'Consulta cómo cobrar el bono de S/ 380 para hogares en condición de pobreza o pobreza extrema, que se encuentran en los ámbitos geográficos con mayor riesgo sanitario durante el estado de emergencia por el coronavirus (COVID-19).',
  'https://www.gob.pe/8782-acceder-al-bono-yo-me-quedo-en-casa',
  'PRESENCIAL',
  380.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Acceder al bono Yo me quedo en casa): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIDIS / Acceder al bono rural): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Tener la clasificación de pobre o pobre extremo en el padrón delSistema de Focalización de Hogares(SISFOH).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al bono rural',
  'Puedes consultar si te corresponde el subsidio monetario de S/ 760 para hogares de zonas rurales en condición de pobreza o pobreza extrema, que no han sido beneficiados con otros apoyos económicos ni reciben ayuda de programas sociales durante la emergencia nacional por COVID-19, en la plataforma Bono Rural.',
  'https://www.gob.pe/9070-acceder-al-bono-rural',
  'VIRTUAL',
  760.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Acceder al bono rural): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIDIS / Cobrar el apoyo económico Yanapay a través de Banca Celular): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Cobrar el apoyo económico Yanapay a través de Banca Celular',
  'Si eres beneficiario del Yanapay a través de la modalidad Banca Celular, podrás retirarlo a través de los canales alternos del Banco de la Nación (más de 900 cajeros automáticos y 12,000 agentes Multired a nivel nacional). Toma en cuenta que si bien el inicio de pagos se.',
  'https://www.gob.pe/15100-cobrar-el-apoyo-economico-yanapay-a-traves-de-banca-celular',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pagos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));

-- REVISAR (MIDIS / Consultar la Biblioteca MIDIS): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Tener un celular conlínea a tu nombre,con 30 días de activación como mínimo.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Ser beneficiario del Yanapay en la modalidad Banca Celular.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Consultar la Biblioteca MIDIS',
  'El Ministerio de Desarrollo e Inclusión Social pone a tu disposición su Biblioteca MIDIS. En ella tendrás acceso de manera gratuita a libros, revistas y otros documentos relacionados con el desarrollo e inclusión social del país. Entre las colecciones que encontrarás en la.',
  'https://www.gob.pe/813-consultar-la-biblioteca-midis',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Consultar la Biblioteca MIDIS): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIDIS / Consultar mi clasificación socioeconómica en el Sistema de F): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar mi clasificación socioeconómica en el Sistema de Focalización de Hogares (Sisfoh)',
  'Si quieres conocer cuál es el estado de tu clasificación socioeconómica en el Sistema de Focalización de Hogares (Sisfoh) del Midis, puedes hacerlo de manera online. El Sisfoh identifica hogares en situación de pobreza y no pobreza, a través de una evaluación socioeconómica.',
  'https://focalizacion.sisfoh.gob.pe/ConsultaCSE/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Consultar mi clasificación socioeconómica en el Sistema de F): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIDIS / Consultar si recibes el apoyo económico Yanapay): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar si recibes el apoyo económico Yanapay',
  'Este fue una ayuda económica individual de S/ 350 que el Gobierno otorgó a nivel nacional a personas mayores de edad en situación de pobreza o vulnerabilidad, así como a los usuarios de los programas sociales Juntos , Pensión 65 o Contigo del Ministerio de Desarrollo e Inclusión Social (Midis) , en el contexto de la pandemia por la COVID-19.',
  'https://www.gob.pe/14565-consultar-si-recibes-el-apoyo-economico-yanapay',
  'PRESENCIAL',
  350.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Consultar si recibes el apoyo económico Yanapay): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIDIS / Hacer el seguimiento de las citas en línea con los intérpret): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Cobrar tu apoyo económico Yanapay por Cuenta DNI');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Cobrar el apoyo económico Yanapay a través de Banca Celular');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Modalidades de pago del Yanapay');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Cobrar el Yanapay por pago en ventanilla');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Hacer el seguimiento de las citas en línea con los intérpretes de señas',
  'Si solicitaste una cita con un intérprete de lengua de señas peruana a través del formulario virtual, puede hacerle seguimiento y revisar su avance de manera virtual o presencial en el Ministerio de Desarrollo e Inclusión Social (Midis).',
  'https://app.midis.gob.pe/Sis_Cita_Interprete_Consulta',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('citas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas'));

-- REVISAR (MIDIS / Inscríbete en los cursos virtuales de la Fundación Romero di): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de cita.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Inscríbete en los cursos virtuales de la Fundación Romero dirigidos a usuarios de los programas sociales del Midis',
  'Si eres usuario o usuaria de los programas sociales Foncodes , PAIS , Juntos , representante o usuario(a) de los comedores populares y ollas comunes, actor comunal del comité de gestión del Programa Cuna Más , gestor del tambo del programa PAIS, gestor del programa Juntos o yachachiq (maestro de campo) del programa Foncodes, puedes inscribirte en los cursos virtuales gratuitos y cortos sobre informática, marketing, desarrollo personal, negocios, creatividad e innovación, entre otros.',
  'https://www.gob.pe/29844-inscribete-en-los-cursos-virtuales-de-la-fundacion-romero-dirigidos-a-usuarios-de-los-programas-sociales-del-midis',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Inscríbete en los cursos virtuales de la Fundación Romero di): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIDIS / Acceder a la información pública del Midis): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Contar con acceso a internet y a un dispositivo móvil o computadora que te permita ingresar a la plataforma virtual del curso.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Conocimiento y manejo de ofimática básica y navegación en internet.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la información pública del Midis',
  'Puedes acceder a la información de las instituciones del Estado según el principio de transparencia, el Texto Único Ordenado de la Ley N° 27806, Ley de Transparencia y Acceso a la Información Pública , y el Reglamento de la Ley N°27806, Ley de Transparencia y Acceso a la Información pública .',
  'https://www.gob.pe/17011-ministerio-de-desarrollo-e-inclusion-social-acceder-a-la-informacion-publica-del-midis',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('transparencia');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'transparencia'));

-- REVISAR (MIDIS / Acceder al Libro de Reclamaciones del Midis): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al Libro de Reclamaciones del Midis',
  'Si estás insatisfecho o disconforme con la atención brindada en una entidad pública, puedes presentar una queja o reclamo en su Libro de Reclamaciones. Con esto, se busca proteger tus derechos y lograr la eficiencia del Estado en la atención de los servicios brindados.',
  'https://www.gob.pe/21400-ministerio-de-desarrollo-e-inclusion-social-acceder-al-libro-de-reclamaciones-del-midis',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (MIDIS / Consultar estado de trámite): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar estado de trámite',
  'Si realizaste un trámite en alguna entidad del Estado, puedes hacerle seguimiento y revisar su avance de manera virtual, presencial o telefónica.',
  'https://www.gob.pe/32900-ministerio-de-desarrollo-e-inclusion-social-consultar-estado-de-tramite',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Consultar estado de trámite): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MIDIS / Consultar registro de visitas de las entidades del Estado pe): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de registro');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Consultar registro de visitas de las entidades del Estado peruano',
  'Si deseas acceder al registro de las visitas que reciben los funcionarios y servidores que laboran en cualquiera de las instituciones públicas del Estado peruano, con información en tiempo real, puedes ingresar a la plataforma habilitada por la Presidencia del Consejo de Ministros (PCM) o consultar el registro de visitas de cada entidad.',
  'https://www.gob.pe/41778-ministerio-de-desarrollo-e-inclusion-social-consultar-registro-de-visitas-de-las-entidades-del-estado-peruano',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MIDIS / Denunciar un acto de corrupción en el Midis): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Denunciar un acto de corrupción en el Midis',
  'Si necesitas denunciar un posible acto de corrupción o falta de ética cometida por personal de una entidad del Estado, puedes hacerlo a través de la Plataforma de Denuncias Ciudadanas , habilitada por la Presidencia del Consejo de Ministros (PCM) , o de manera presencial o en línea, en la entidad que quieres denunciar.',
  'https://www.gob.pe/17010-ministerio-de-desarrollo-e-inclusion-social-denunciar-un-acto-de-corrupcion-en-el-midis',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MIDIS / Renunciar al cobro de tu apoyo económico Yanapay): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento de identidad.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico y número telefónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'En caso de presentar la denuncia como persona jurídica, número de RUC.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Documentación original o copia simple que sustente tu denuncia. También puedes precisar la unidad o dependencia donde se efectuó el hecho.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Firma o huella digital (en caso de no poder firmar o estar impedido de hacerlo).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MIDIS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Renunciar al cobro de tu apoyo económico Yanapay',
  'Si te corresponde el subsidio monetario del Estado, pero por diferentes motivos deseas renunciar al cobro del Yanapay, puedes hacerlo de manera online.',
  'https://www.gob.pe/15103-renunciar-al-cobro-de-tu-apoyo-economico-yanapay',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MIDIS / Renunciar al cobro de tu apoyo económico Yanapay): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (SUNAFIL / Acceder a Sunafil en Línea): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Estar en elpadrón de beneficiarios.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Declaración jurada de renuncia o devolución del Yanapayen formato PDF, cuyo archivo no pese más de 2 MB. También puedes descargarla en la plataforma cuando registres tu caso. Toma en cuenta:');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Si aún no te realizaron el depósitodel apoyo económico, coloca únicamente tus datos personales y firma.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Si ya te depositaron el apoyo económico,primero deberás devolver el dinero a la cuenta corriente del Banco de la Naciónque aparece en elformularioy luego, adjuntar tu declaración jurada completa junto al comprobante.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a Sunafil en Línea',
  'Si eres un trabajador o empleador y quieres acceder a los servicios digitales que brinda la Superintendencia Nacional de Fiscalización Laboral (Sunafil), como hacer denuncias laborales, consultas en la materia, gestionar trámites, verificar información, entre otros, puedes.',
  'https://aplicativosweb7.sunafil.gob.pe/si.sunafilLinea/#/consulta',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (SUNAFIL / Acceder a la casilla electrónica de Sunafil): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la casilla electrónica de Sunafil',
  'Si participas en actuaciones o procedimientos administrativos de competencia de la Superintendencia Nacional de Fiscalización Laboral (Sunafil), puedes acceder a esta casilla para ver las notificaciones emitidas.',
  'https://casillaelectronica.sunafil.gob.pe/si.inbox/Login/SUNAT',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SUNAFIL / Acceder a la casilla electrónica de Sunafil): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (SUNAFIL / Buscar resoluciones del Sistema inspectivo de la Sunafil): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar resoluciones del Sistema inspectivo de la Sunafil',
  'Puedes buscar todas las resoluciones de primera y segunda instancia de las inspecciones laborales realizadas por la Superintendencia Nacional de Fiscalización Laboral (Sunafil). Entre las opciones de búsqueda puedes utilizar el RUC o razón social de una empresa, así.',
  'https://aplicativosweb2.sunafil.gob.pe/si.consultaMultasSIIT',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('impuestos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (SUNAFIL / Calcular cuota de empleo de personas con discapacidad en mi ): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Calcular cuota de empleo de personas con discapacidad en mi empresa',
  'De acuerdo a la Ley N° 29973 (Ley de la persona con discapacidad) los empleadores privados que cuenten con más de 50 trabajadores en planilla están obligados a contratar personas con discapacidad en una proporción no menor al 3% de la totalidad de su personal.',
  'https://aplicativosweb2.sunafil.gob.pe/si.cuotaEmpleo',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (SUNAFIL / Consultar el expediente inspectivo de Sunafil): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar el expediente inspectivo de Sunafil',
  'Si necesitas darle seguimiento a una inspección solicitada, puedes hacerlo a través de este servicio que te brinda la Superintendencia Nacional de Fiscalización Laboral (Sunafil).',
  'https://aplicativosweb7.sunafil.gob.pe/si.consultaExpediente',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SUNAFIL / Consultar el expediente inspectivo de Sunafil): ninguna etiqueta matcheo, asignar a mano si aplica

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Denunciar a una empresa privada que no cumple con el estado de emergencia',
  'Si laboras o laborabas en una empresa privada que no esté respetando el estado de emergencia nacional declarado por el Decreto Supremo N° 008-2021-PCM, poniendo en riesgo la salud pública, podrás denunciarlo de manera virtual a través de la página de la Superintendencia.',
  'https://aplicativosweb2.sunafil.gob.pe/si.denunciasVirtuales',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('salud');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (SUNAFIL / Enviar alerta contra el trabajo infantil y forzoso): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de RUC de la empresa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Dirección del centro de trabajo a denunciar.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Documentos que sustenten tu denuncia (boletas de pago, contrato de trabajo, etc) escaneados y en formato PDF.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Contar con un correo electrónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Número de celular personal.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Enviar alerta contra el trabajo infantil y forzoso',
  'Si crees conocer un presunto caso de trabajo infantil o forzoso, envía una alerta con las evidencias (fotos o videos) y la ubicación del centro de trabajo en el que se estaría dando el caso con tu celular o cualquier dispositivo móvil al aplicativo "Alerta de trabajo infantil.',
  'https://aplicativosweb7.sunafil.gob.pe/si.alerta',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SUNAFIL / Enviar alerta contra el trabajo infantil y forzoso): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (SUNAFIL / Realizar consultas laborales a la Sunafil): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Razón Social de la empresa donde está ocurriendo el suceso');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Actividad Económica de la empresa donde está ocurriendo el suceso');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Dirección donde está ocurriendo el suceso');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Fotos o videos donde se evidencie el trabajo infantil o forzoso');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Realizar consultas laborales a la Sunafil',
  'Puedes hacerle consultas a la Superintendencia Nacional de Fiscalización Laboral (Sunafil) sobre temas sociolaborales, de seguridad y salud en el trabajo, derechos laborales, entre otros. Revisa las preguntas frecuentes por si se encuentra ahí la respuesta a tu consulta.',
  'http://aplicativosweb5.sunafil.gob.pe/si.consultasLaborales/inicio',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'salud'));

-- REVISAR (SUNAFIL / Acceder a mesa de partes): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a mesa de partes',
  'Si necesitas enviar documentos para realizar tus trámites, puedes hacerlo a través de la mesa de partes de las entidades públicas.',
  'https://www.gob.pe/12910-superintendencia-nacional-de-fiscalizacion-laboral-acceder-a-mesa-de-partes',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SUNAFIL / Acceder a mesa de partes): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (SUNAFIL / Verificar identificación de inspectores de Sunafil): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Nombres y apellidos completos, domicilio y número de Documento Nacional de Identidad o carnet de extranjería del administrado, y en su caso, la calidad de representante y de la persona a quien represente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'La expresión concreta de lo pedido, los fundamentos de hecho que lo apoye y, cuando le sea posible, los de derecho.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Lugar, fecha, firma o huella digital, en caso de no saber firmar o estar impedido.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'La indicación del órgano, la entidad o la autoridad a la cual es dirigida, entendiéndose por tal, en lo posible, a la autoridad de grado más cercano al usuario, según la jerarquía, con competencia para conocerlo y resolverlo.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'La dirección del lugar donde se desea recibir las notificaciones del procedimiento, cuando sea diferente al domicilio real expuesto en virtud del numeral 1. Este señalamiento de domicilio surte sus efectos desde su indicación y es presumido subsistente, mientras no sea comunicado expresamente su cam');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'La relación de los documentos y anexos que acompaña, indicados en el TUPA.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 7, 'La identificación del expediente de la materia, tratándose de procedimientos ya iniciados.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Verificar identificación de inspectores de Sunafil',
  'Si se presentan inspectores de la Superintendencia Nacional de Fiscalización Laboral (Sunafil) en tu centro de trabajo, puedes verificar la identidad de cada uno de ellos en este servicio web. Recuerda que una vez que los inspectores han sido identificados, debes permitir.',
  'https://aplicativosweb2.sunafil.gob.pe/si.consultaInspectores',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SUNAFIL / Verificar identificación de inspectores de Sunafil): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (SUNAFIL / Verificar si estás en planilla): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAFIL'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Verificar si estás en planilla',
  'Corrobora si tu empleador te ha registrado en la planilla electrónica colocando tu documento de identidad y RUC de la empresa donde laboras con "Verifica tu Chamba".Si no te encuentras, el aplicativo enviará una alerta a la Casilla Electrónica de la empresa que responde.',
  'https://aplicativosweb6.sunafil.gob.pe/si.verificacionPlanillaElectronica',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'impuestos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (MTPE / Acceder a asesorías sobre temas laborales en el Ministerio d): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a asesorías sobre temas laborales en el Ministerio de Trabajo y Promoción del Empleo',
  'Si deseas recibir asesorías sobre temas laborales, puedes reservar una cita de manera online en el Ministerio de Trabajo y Promoción del Empleo (MTPE).',
  'https://extranet.trabajo.gob.pe/extranet/web/citas',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('citas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'citas'));

-- REVISAR (MTPE / Acceder a la Suspensión Perfecta de Labores): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'DNI, pasaporte, carnet de extranjería o permiso temporal de permanencia.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Número de teléfono.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Correo electrónico.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la Suspensión Perfecta de Labores',
  'Si eres empleador y no puedes implementar el teletrabajo o la licencia con goce de haber por el rubro de tus actividades o la afectación económica durante el estado de emergencia por coronavirus, puedes aplicar la Suspensión Perfecta de Labores.',
  'http://apps.trabajo.gob.pe/suspension-perfecta/autenticacion',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Acceder a la Suspensión Perfecta de Labores): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Acceder a la casilla electrónica del Ministerio de Trabajo y): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Usuario yclave SOL.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Nombres completos y DNI del trabajador.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Declaración jurada en formato PDF.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la casilla electrónica del Ministerio de Trabajo y Promoción del Empleo (MTPE)',
  'Si eres un empleador o trabajador, un ciudadano o representante de alguna persona jurídica o entidad pública, puedes acceder a la casilla electrónica del Ministerio de Trabajo y Promoción del Empleo (MTPE), para recibir notificaciones y comunicaciones oficiales de manera.',
  'https://mesadigital360.trabajo.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (MTPE / Acceder a orientación vocacional en la plataforma Mi carrera): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Acceder a orientación vocacional en la plataforma Mi carrera',
  'Si estás terminando el colegio o ya terminaste, pero aún no sabes qué carrera profesional estudiar, puedes acceder a información sobre distintas profesiones, universidades, institutos o becas, mediante la plataforma Mi carrera. Esta herramienta, desarrollada por el Ministerio.',
  'https://micarrera.trabajo.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MTPE / Apertura de sucursales, oficinas, centros de trabajo u otros): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Apertura de sucursales, oficinas, centros de trabajo u otros establecimientos que desarrollan intermediación laboral',
  'Automática - 5 días hábiles. Cuando el cumplimiento de los requisitos solicitados es suficiente para dar por cumplido el trámite o servicio solicitado. Entidad a cargo: Oficina de Atención al Ciudadano y Gestión Documentaria.',
  'https://www.gob.pe/22889-apertura-de-sucursales-oficinas-centros-de-trabajo-u-otros-establecimientos-que-desarrollan-intermediacion-laboral',
  'PRESENCIAL',
  49.35
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Apertura de sucursales, oficinas, centros de trabajo u otros): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Aprobación de contratos de trabajo del régimen de exportació): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aprobación de contratos de trabajo del régimen de exportación no tradicional',
  'Silencio positivo - 30 días. Cuando transcurrido el plazo la institución no ha emitido un pronunciamiento expreso al trámite o servicio solicitado, este se da como aprobado. Entidad a cargo: Portal web del Ministerio de Trabajo y Promoción del Empleo.',
  'https://www.gob.pe/22896-aprobacion-de-contratos-de-trabajo-del-regimen-de-exportacion-no-tradicional',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Aprobación de contratos de trabajo del régimen de exportació): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Aprobación de programas de reducción de personal de empresas): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aprobación de programas de reducción de personal de empresas del Estado',
  'Silencio positivo - 5 días hábiles. Cuando transcurrido el plazo la institución no ha emitido un pronunciamiento expreso al trámite o servicio solicitado, este se da como aprobado. Entidad a cargo: Oficina de Atención al Ciudadano y Gestión Documentaria.',
  'https://www.gob.pe/22890-aprobacion-de-programas-de-reduccion-de-personal-de-empresas-del-estado',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (MTPE / Aprobación y modificación del reglamento interno de trabajo): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aprobación y modificación del reglamento interno de trabajo',
  'Automática - 5 días. Cuando el cumplimiento de los requisitos solicitados es suficiente para dar por cumplido el trámite o servicio solicitado. Entidad a cargo: Oficina de Atención al Ciudadano y Gestión Documentaria.',
  'https://www.gob.pe/22873-aprobacion-y-modificacion-del-reglamento-interno-de-trabajo',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Aprobación y modificación del reglamento interno de trabajo): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Aprobación, prórroga o modificación del contrato de personal): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Aprobación, prórroga o modificación del contrato de personal extranjero',
  'Silencio positivo - 3 días. Cuando transcurrido el plazo la institución no ha emitido un pronunciamiento expreso al trámite o servicio solicitado, este se da como aprobado. Entidad a cargo: Oficina de Atención al Ciudadano y Gestión Documentaria.',
  'https://www.gob.pe/22867-aprobacion-prorroga-o-modificacion-del-contrato-de-personal-extranjero',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('migraciones');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'migraciones'));

-- REVISAR (MTPE / Autorización de trabajo para adolescentes): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Autorización de trabajo para adolescentes',
  'Autorización previa a las y los adolescentes para que realicen trabajo por cuenta ajena o en relación de dependencia. Silencio negativo - 15 días hábiles. Cuando transcurrido el plazo la institución no ha emitido un pronunciamiento expreso al trámite o servicio solicitado.',
  'https://www.gob.pe/22874-autorizacion-de-trabajo-para-adolescentes',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Autorización de trabajo para adolescentes): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Buscar trabajo en el portal Empleos Perú): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar trabajo en el portal Empleos Perú',
  'Si eres mayor de 18 años y buscas trabajo, puedes acceder a la plataforma Empleos Perú y conocer las ofertas laborales vigentes.',
  'https://mtpe-candidatos.empleosperu.gob.pe/search-jobs#error=login_required&state=a83ff840-31be-4e43-8b44-5c17b225a708',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (MTPE / Calcular la liquidación de beneficios sociales para trabajad): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Correo electrónico.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Calcular la liquidación de beneficios sociales para trabajadores del sector privado',
  'Si eres trabajador o cesante del régimen general privado y quieres conocer cuánto te corresponde recibir por la liquidación de tus beneficios sociales, puedes acceder en línea a Calcula tus Beneficios Sociales del Ministerio de Trabajo y Promoción del Empleo (MTPE).',
  'https://portal.trabajo.gob.pe/calculadoraMTPE/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Calcular la liquidación de beneficios sociales para trabajad): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Comunicación de la reforma de los estatutos de la organizaci): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Comunicación de la reforma de los estatutos de la organización sindical',
  'Comunicación de la reforma de los estatutos de la organización sindical, de las federaciones y confederaciones, de la nómina de la junta directiva y de los cambios que en ella se produzcan. Automática - 5 días. Cuando el cumplimiento de los requisitos solicitados es.',
  'https://www.gob.pe/22860-comunicacion-de-la-reforma-de-los-estatutos-de-la-organizacion-sindical',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Comunicación de la reforma de los estatutos de la organizaci): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Comunicación de reforma de estatutos de las federaciones y c): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Comunicación de reforma de estatutos de las federaciones y confederaciones',
  'Automática - 5 dias. Cuando el cumplimiento de los requisitos solicitados es suficiente para dar por cumplido el trámite o servicio solicitado. Base Legal: D. S. N° 010-2003-TR, Art.10° inc. d) y 38° del 05/10/2003 D. S. N° 011-92-TR, Art.21° del 15/10/1992.',
  'https://www.gob.pe/22886-comunicacion-de-reforma-de-estatutos-de-las-federaciones-y-confederaciones',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Comunicación de reforma de estatutos de las federaciones y c): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (MTPE / Comunicación de reforma de estatutos de sindicatos): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'MTPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Comunicación de reforma de estatutos de sindicatos',
  'Automática - 5 días. Cuando el cumplimiento de los requisitos solicitados es suficiente para dar por cumplido el trámite o servicio solicitado. Entidad a cargo: Oficina de Atención al Ciudadano y Gestión Documentaria. Base legal: D. S. N° 010-2003-TR, Art.10° inc.',
  'https://www.gob.pe/22892-comunicacion-de-reforma-de-estatutos-de-sindicatos',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (MTPE / Comunicación de reforma de estatutos de sindicatos): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (INDECOPI / Accede al Mapa de Consumo): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Accede al Mapa de Consumo',
  'El Mapa de consumo es una herramienta informativa, creada para que los consumidores que tengan conflictos de consumo, conozcan ante qué entidad pública pueden acudir para presentar un reclamo o denuncia a nivel nacional.',
  'https://www.gob.pe/117541-accede-al-mapa-de-consumo',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (INDECOPI / Acceder a Boletín Concursal del Indecopi): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Acceder a Boletín Concursal del Indecopi',
  'En este boletín, puedes conocer los diferentes procesos publicados en Indecopi, como el listado de deudores, convocatorias de juntas de acreedores, publicidad de convenio de liquidación, difusión de resoluciones, por ejemplo, para la sanción a entidades que incumplen.',
  'https://enlinea.indecopi.gob.pe/boletinconcursal/pgw_deudores.seam',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('contrataciones');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'contrataciones'));

-- REVISAR (INDECOPI / Acceder a la plataforma de asesoría virtual de marcas): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a la plataforma de asesoría virtual de marcas',
  'Si eres emprendedor o emprendedora y deseas recibir asistencia técnica para registrar tu marca, accede a la Plataforma de Asesoría Virtual de Marcas del Indecopi. Para brindarte el servicio debes tener lista tu solicitud de registro y haber realizado el pago de la tasa correspondiente. Haremos un análisis de viabilidad de tu propuesta.',
  'https://www.gob.pe/17215-acceder-a-la-plataforma-de-asesoria-virtual-de-marcas',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pagos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (INDECOPI / Acceder a solicitudes de registros de marcas y patentes en I): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a solicitudes de registros de marcas y patentes en Indecopi',
  'Si deseas ver las solicitudes de registros de signos distintivos (marcas, nombres, lemas comerciales, denominaciones de origen, indicaciones geográficas, etc.), así como las solicitudes de registro de nuevas tecnologías (patentes de invención y diseños industriales), debes.',
  'https://servicio.indecopi.gob.pe/gaceta/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (INDECOPI / Acceder al catálogo de obras de dominio público): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder al catálogo de obras de dominio público',
  'Mediante esta plataforma, podrás consultar todas las obras de dominio público que pueden leerse, reproducirse, difundirse y hasta ser editadas de forma libre. La información contenida en este aplicativo es proporcionada por la Biblioteca Nacional del Perú e incluye títulos.',
  'http://bvirtual.indecopi.gob.pe/web-icopi/ic7spa.htm',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('educacion');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'educacion'));

-- REVISAR (INDECOPI / Acceder al sistema de reporte de reclamaciones del Indecopi): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Acceder al sistema de reporte de reclamaciones del Indecopi',
  'Si tienes un negocio o eres proveedor de un rubro orientado al consumidor y tus clientes han hecho uso del libro de reclamaciones, debes reportar dichos reclamos al Indecopi a través de su plataforma virtual. La información que brindes tiene carácter de declaración jurada y, si.',
  'https://servicios.indecopi.gob.pe/controlatusreclamos/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (INDECOPI / Buscar empresas sancionadas por Indecopi): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ser una empresa con un ingreso anual igual o mayor aS/  16,500,000.00.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Contar con usuario y contraseña, otorgado por la Dirección de Fiscalización, tras haber realizado lasolicitud de registro.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar empresas sancionadas por Indecopi',
  'A través de la plataforma virtual Mira a quién le compras, podrás conocer e identificar a todas las empresas que han sido sancionadas desde el 2011 y las penalidades aplicadas por el Instituto Nacional de Defensa de la Competencia y de la Protección de la Propiedad Intelectual.',
  'https://enlinea.indecopi.gob.pe/miraaquienlecompras/#/inicio',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (INDECOPI / Buscar expedientes de Protección al Consumidor en Indecopi): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Nombre comercial, razón social o RUC del proveedor. La búsqueda simple es posible con cualquiera de estos datos.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Año y número de resolución, siglas, año de la multa y sector económico del proveedor, en caso de realizar una búsqueda avanzada sobre sanciones.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar expedientes de Protección al Consumidor en Indecopi',
  'Si tienes un proceso abierto entre las instancias resolutivas de Protección al Consumidor en Indecopi, puedes revisar su estado actual a través de su plataforma virtual.',
  'https://servicio.indecopi.gob.pe/busquedaRapida/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (INDECOPI / Buscar productos y servicios para registrar tu marca - Busca): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Código de búsqueda rápida del expediente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Número y año del expediente.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Buscar productos y servicios para registrar tu marca - Buscador peruanizado',
  'Si deseas ubicar algún producto o servicio para obtener la información necesaria que te facilite el registro de tu marca o nombre comercial, puedes acceder al buscador peruanizado del Indecopi. Este buscador forma parte de las herramientas virtuales para el registro de marcas.',
  'https://servicio.indecopi.gob.pe/appNIZAWeb/index.seam',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (INDECOPI / Buscar resoluciones del Indecopi): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar resoluciones del Indecopi',
  'Si necesitas encontrar todas las resoluciones del Tribunal de Defensa de la Competencia y de la Propiedad Intelectual del Indecopi, así como las decisiones en los órganos de primera instancia de Lima y regiones por áreas específicas, puedes ingresar al buscador de resoluciones.',
  'http://servicio.indecopi.gob.pe/buscadorResoluciones',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (INDECOPI / Buscar resoluciones del Indecopi): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (INDECOPI / Buscar una marca o servicio registrado - Busca tu marca): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Buscar una marca o servicio registrado - Busca tu marca',
  'Si necesitas verificar que la marca o signo distintivo que deseas registrar no tenga marcas o signos similares o idénticos que hayan sido registrado previamente, puedes hacerlo a través de esta herramienta del Indecopi. Este buscador permite realizar las búsquedas por titular.',
  'https://enlinea.indecopi.gob.pe/buscatumarca/#/inicio',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));

-- REVISAR (INDECOPI / Calcular mora por retraso de pago): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Calcular mora por retraso de pago',
  'Si necesitas calcular el interés máximo que se debe aplicar por el retraso de pago a tus obligaciones contraídas con entidades o personas que no se encuentran en el sistema financiero, puedes acceder al simulador de moras de Indecopi. El Banco Central de Reserva (BCR) es la.',
  'https://www.gob.pe/14354-calcular-mora-por-retraso-de-pago',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));

-- REVISAR (INDECOPI / Calcular multas por imposición de barreras burocráticas): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Calcular multas por imposición de barreras burocráticas',
  'Las barreras burocráticas son obstáculos como limitaciones, prohibiciones o cobros, que se presentan cuando quieres acceder a algún servicio en la administración pública o estás realizando alguna gestión. Desarma barreras es una herramienta donde puedes calcular el monto de la.',
  'https://www.gob.pe/13868-calcular-multas-por-imposicion-de-barreras-burocraticas',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (INDECOPI / Calcular multas por imposición de barreras burocráticas): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (INDECOPI / Calcular tarifa por uso de obras musicales - Sintonízate): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'INDECOPI'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Calcular tarifa por uso de obras musicales - Sintonízate',
  'Si eres DJ, o conductor de eventos musicales o bailables, en locales permanentes o establecimientos como discotecas, bares, gimnasios, o cualquier local en donde celebren matrimonios o aniversarios.',
  'https://servicio.indecopi.gob.pe/sintonizate/pgw_indexCalculoBaile.seam',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (INDECOPI / Calcular tarifa por uso de obras musicales - Sintonízate): ninguna etiqueta matcheo, asignar a mano si aplica

INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Nombre del local o RUC.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Acceder a reporte de deuda en el Sistema Financiero',
  'Accede a la información créditos que contrataste con las empresas del sistema financiero, así como la calificación asignada por dichas entidades en base a tu comportamiento de pagos, a través del reporte de deuda de la Superintendencia de Banca, Seguros y AFP (SBS).',
  'https://servicios.sbs.gob.pe/serviciosenlinea',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('pagos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'pagos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('empresas');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Mostrar DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Si actúas como representante, presentar el documento que acredite el otorgamiento de poder.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar a la SBS sobre los servicios de las empresas del sistema financiero, de seguros y AFP',
  'Si deseas conocer sobre las actividades y servicios que ofrecen las empresas del sistema financiero, de seguros y AFP, o informarte sobre las normas que las regulan, puedes contactarte con la Superintendencia de Banca, Seguros y Administradoras Privadas de Fondos de Pensiones.',
  'https://servicios.sbs.gob.pe/VentanillaSBS/Solicitud/ConsultaSoho',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'empresas'));

-- REVISAR (SBS / Consultar tu reporte de deudas, gastos y afiliación a la AFP): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento de identidad.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico (para modalidad virtual).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Tener usuario en la plataforma Servicios SBS en línea (para modalidad virtual).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Consultar tu reporte de deudas, gastos y afiliación a la AFP con la aplicación móvil de la Superintendencia de Banca, Seguros y AFP',
  'Puedes revisar tu reporte de dudas, afiliación a la AFP y tipo de cambio actual con la aplicación App SBS de la Superintendencia de Banca, Seguros y Administradoras Privadas de Fondos de Pensiones (SBS). Esta aplicación móvil te permite, además, consultar tu reporte SOAT.',
  'https://www.gob.pe/67759-consultar-tu-reporte-de-deudas-gastos-y-afiliacion-a-la-afp-con-la-aplicacion-movil-de-la-superintendencia-de-banca-seguros-y-afp',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SBS / Consultar tu reporte de deudas, gastos y afiliación a la AFP): ninguna etiqueta matcheo, asignar a mano si aplica

INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Teléfono con sistema operativo Android. IOS o Harmony.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Número deDNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Correo electrónico.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Obtener certificado de pólizas de seguro',
  'Si eres heredero legal puedes acceder, de forma gratuita, a la información sobre la existencia de depósitos o productos pasivos de titularidad de la persona fallecida.',
  'http://www.sbs.gob.pe/usuarios/nuestros-servicios/tramites-en-linea/certificado-de-polizas',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SBS / Obtener certificado de pólizas de seguro): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (SBS / Obtener constancia de depósitos de personas fallecidas): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Presentar elformulariode solicitud con los datos.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Copia certificada de la Declaración de Herederos o del Testamento, inscritos en Registros Públicos.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Copia del Acta de Defunción del causante.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'En caso de actuar como representante legal, presentar copia de DNI del representado y representante, y el documento que acredite el otorgamiento de poder correspondiente.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Obtener constancia de depósitos de personas fallecidas',
  'Si eres heredero legal puedes acceder a información sobre la existencia de depósitos o productos pasivos que estén a nombre de la persona fallecida.',
  'https://www.gob.pe/596-obtener-constancia-de-depositos-de-personas-fallecidas',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SBS / Obtener constancia de depósitos de personas fallecidas): ninguna etiqueta matcheo, asignar a mano si aplica

INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Presentarformulario.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Copia certificada de la Declaración de Herederos o del Testamento, debidamente inscritos en Registros Públicos.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Copia del Acta de Defunción de la persona fallecida.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'En caso de actuar como representante legal, presentar copia de DNI del representado y representante, y el documento que acredite el otorgamiento de poder correspondiente.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Obtener constancia de estado pensionario en el Sistema Privado de Pensiones',
  'Con esta constancia de la Superintendencia de Banca, Seguros y AFP (SBS), puedes acreditar si recibes o no una pensión del Sistema Privado de Pensiones (SPP) bajo cualquiera de las modalidades. Este trámite es gratuito.',
  'http://www.sbs.gob.pe/usuarios/nuestros-servicios/seguimiento-de-tramites/constancia-de-estado-pensionario',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SBS / Obtener constancia de estado pensionario en el Sistema Priva): ninguna etiqueta matcheo, asignar a mano si aplica

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Rectificar datos de identidad en el Reporte de Deudas',
  'Si detectas un error de datos de identidad en tu Reporte de Deudas, puedes solicitar una rectificación a la Superintendencia de Banca, Seguros y AFP (SBS). Esto te permite corregir información como la de tu nombre, documento de identidad o código SBS. Este trámite es gratuito.',
  'http://www.sbs.gob.pe/usuarios/nuestros-servicios/seguimiento-de-tramites/rectificacion-de-datos-de-identidad-en-el-reporte-de-deudas-sbs',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SBS / Rectificar datos de identidad en el Reporte de Deudas): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (SBS / Tupa SBS): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Mostrar DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Si actúas como representante, presentar el documento que acredite el otorgamiento de poder.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SBS'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Tupa SBS',
  'Conoce el Texto Único de Procedimientos Administrativos Procedimientos (TUPA) de la SBS, que contiene toda la información relacionada a los procedimientos que los administrados pueden realizar ante la SBS y los servicios prestados en exclusividad que esta ofrece, incluyendo los requisitos, plazos de atención, derechos de tramitación a ser pagados, entre otra información.',
  'https://www.gob.pe/92868-tupa-sbs',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (SBS / Tupa SBS): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (JNE / Alerta de Afiliación Política): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'JNE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Alerta de Afiliación Política',
  'Es un servicio gratuito del Jurado Nacional de Elecciones (JNE) que te permite recibir una notificación inmediata si eres inscrito en un partido político sin tu consentimiento. Sirve para que los ciudadanos puedan proteger su identidad y derechos políticos, evitando.',
  'https://www.gob.pe/99764-alerta-de-afiliacion-politica',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('electoral');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (JNE / Consultar si tienes multas electorales): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Tener DNI vigente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Registrar un correo electrónico personal.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Contar con un número de celular activo para recibir notificaciones.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'JNE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Consultar si tienes multas electorales',
  'Recibes una multa electoral cuando no votaste, no cumpliste tu deber de asistir como miembro de mesa o te negaste a reemplazar a un miembro de mesa ausente. El monto de las multas electorales por no votar es diferente si eres considerado como No Pobre, Pobre o Pobre Extremo.',
  'https://multas.jne.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (JNE / Desafiliación a una organización política): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'JNE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Desafiliación a una organización política',
  '¿Qué es una afiliación a una organización política?Es cuando un ciudadano, de manera libre y voluntaria, decide pertenecer a un partido político y participar en la vida democrática del país. Solo los afiliados gozan de los derechos y deberes que establece la Ley de.',
  'https://www.gob.pe/99307-desafiliacion-a-una-organizacion-politica',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (JNE / Desafiliación a una organización política): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (JNE / Formación Electoral para Jueces y Fiscales del JNE y la UPC): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Tener unaCasilla Electrónica del JNE.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Tener el DNI físico');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Correo electrónico');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'JNE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Formación Electoral para Jueces y Fiscales del JNE y la UPC',
  'Con un costo del servicio de S/ 445.00 (cuatrocientos cuarenta y cinco soles), el Jurado Nacional de Elecciones (JNE) en alianza con la Universidad Peruana de Ciencias Aplicadas (UPC) ofrece un programa académico que brinda a jueces y fiscales capacitación especializada en materia electoral.',
  'https://www.gob.pe/99768-formacion-electoral-para-jueces-y-fiscales-del-jne-y-la-upc',
  'VIRTUAL',
  445.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('capacitacion');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'capacitacion'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (JNE / Infórmate sobre los candidatos a la Segunda Elección Regiona): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Ser juez o fiscal en ejercicio en cualquier distrito judicial del país.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Contar con DNI vigente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Llenar el formulario de inscripción en líneaFormulario de postulación.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Presentar hoja de vida resumida (CV no documentado).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Carta de motivación, explicando por qué desea participar en el programa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Compromiso de disponibilidad para asistir a las sesiones de formación en las fechas establecidas.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'JNE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Infórmate sobre los candidatos a la Segunda Elección Regional 2022 - Voto Informado',
  'Cuando se acercan nuevas elecciones (sean presidenciales, congresales, regionales o municipales), el Jurado Nacional de Elecciones habilita la página Voto Informado, para ayudarte a conocer mejor a los candidatos. Actualmente, la página contiene información sobre la Segunda.',
  'https://votoinformado.jne.gob.pe/voto',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (JNE / Denunciar un presunto acto de corrupción): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'JNE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Denunciar un presunto acto de corrupción',
  'Si necesitas denunciar un posible acto de corrupción o falta de ética cometida por personal de una entidad del Estado, puedes hacerlo a través de la Plataforma de Denuncias Ciudadanas , habilitada por la Presidencia del Consejo de Ministros (PCM) , o de manera presencial o en línea, en la entidad que quieres denunciar.',
  'https://www.gob.pe/99787-jurado-nacional-de-elecciones-denunciar-un-presunto-acto-de-corrupcion',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));
INSERT IGNORE INTO etiqueta (nombre) VALUES ('plataforma-virtual');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'plataforma-virtual'));

-- REVISAR (JNE / Pagar mi multa electoral): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento de identidad.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico y número telefónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'En caso de presentar la denuncia como persona jurídica, número de RUC.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Documentación original o copia simple que sustente tu denuncia. También puedes precisar la unidad o dependencia donde se efectuó el hecho.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Firma o huella digital (en caso de no poder firmar o estar impedido de hacerlo).');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'JNE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Pagar mi multa electoral',
  'Recibes una multa electoral cuando no votaste, no cumpliste tu deber de asistir como miembro de mesa o te negaste a reemplazar a un miembro de mesa ausente. Si no pagas tu multa, aún tienes derecho a voto, pero: No podrás inscribir cualquier acto relacionado con tu estado civil.',
  'https://www.pagalo.pe/',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));
	
-- REVISAR (ONPE / Acceder a datos abiertos): modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Documento Nacional de Identidad (DNI)');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Acceder a datos abiertos',
  'Si necesitas acceder a datos gubernamentales, en formato digital, estandarizados, comparables, accesibles, y con potencial de ser útiles para crear aplicaciones, realizar investigación, analizar oportunidades de negocio, desarrollar la economía, ejercer el control ciudadano.',
  'https://www.datosabiertos.gob.pe/group/oficina-nacional-de-procesos-electorales-onpe',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONPE / Acceder a datos abiertos): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONPE / Acceder a la rendición de cuentas de las organizaciones polí): modalidad asumida VIRTUAL, no se encontro en el texto
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Acceder a la rendición de cuentas de las organizaciones políticas - Claridad',
  'Si deseas conocer el financiamiento público y privado que reciben las organizaciones políticas del Perú, puedes hacerlo en línea a través del Sistema Informático Claridad de la Oficina Nacional de Procesos Electorales (ONPE).',
  'https://claridadportal.onpe.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('electoral');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (ONPE / Acceder a tus certificados digitales asociados a tu DNIe con): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Acceder a tus certificados digitales asociados a tu DNIe con la aplicación Onpeid',
  'Puedes autenticar tus certificados usando tu DNI electrónico y tu teléfono móvilcon la aplicación Onpeid. Esta aplicación móvil está dirigida a los usuarios del voto electrónico no presencial, para que puedan ejercer su derecho utilizando su celular. Onpeid está disponible para.',
  'https://www.gob.pe/67439-acceder-a-tus-certificados-digitales-asociados-a-tu-dnie-con-la-aplicacion-onpeid',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('dni');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'dni'));

-- REVISAR (ONPE / Actualizar lista de electores en localidades que cuentan con): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Teléfono con sistema operativo Android o IOS.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Funciona en equipos que cuenten con la interfaz NFC (Near Field Communication) y DNI electrónico v2.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Actualizar lista de electores en localidades que cuentan con mesas de sufragio',
  'Si eres representante de una localidad (centro poblado, comunidad campesina, comunidad nativa, caserío, anexo u otra) alejada que ya cuenta con mesas de sufragio, puedes solicitar la actualización de la lista de electores, para incorporar o excluir a los electores, remitiendo.',
  'https://www.web.onpe.gob.pe/mpve/#/',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONPE / Actualizar lista de electores en localidades que cuentan con): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONPE / Declarar información financiera como candidato - EG 2026): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Dirigido al Jefe de la ONPE, solicitando se incorpore a la mesa de sufragio de su localidad a los electores que residen en el distrito correspondiente y que no han sido registrados anteriormente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Además, en la solicitud debe indicar nombre de la persona de contacto y/o responsable para el envío de documentos, teléfonos de contacto y/o dirección de correo electrónico.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Declarar información financiera como candidato - EG 2026',
  'Si eres candidato a las Elecciones Generales EG 2026, debes presentar a la Oficina Nacional de Procesos Electorales (ONPE) tu información financiera de aportes e ingresos recibidos y gastos efectuados durante la campaña electoral de las EG 2026, según lo establecido.',
  'https://www.onpe.gob.pe/modMarco-Legal/casilla-electronica-onpe.pdf',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (ONPE / Declarar información financiera como promotor de la consulta): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formato n.° 7 de aportaciones e ingresos de campaña electoral recibidos por el candidato a cargo de elección popular, debidamente llenado y firmado por el candidato o responsable de campaña.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Formato n.° 8 de gastos de campaña electoral efectuados por el candidato a cargos de elección popular, debidamente llenado y firmado por el candidato o responsable de campaña.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Formato n.° 14 de acreditación del responsable de campaña de los candidatos a cargos de elección popular, debidamente llenado y firmado por el candidato.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Declarar información financiera como promotor de la consulta popular de revocatoria o como autoridad sometida a consulta',
  'Si fuiste o eres Un promotor de la consulta popular de revocatoria o una autoridad sometida a consulta, debes presentar a la Oficina Nacional de Procesos Electorales (ONPE) la información financiera de aportes e ingresos recibos y gastos efectuados durante la campaña electoral de la Consulta Popular de Revocatoria del Mandato de Autoridades Municipales 2025, conforme a lo señalado en el artículo 111 del Reglamento de Financiamiento y Supervisión de Fondos Partidarios aprobado por Resolución Jefatural n.° 000030-2025-JN/ONPE.',
  'https://www.gob.pe/96391-declarar-informacion-financiera-como-promotor-de-la-consulta-popular-de-revocatoria-o-como-autoridad-sometida-a-consulta',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (ONPE / Histórico de resultados electorales): tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano; modalidad asumida VIRTUAL, no se encontro en el texto; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'FORMATO CPR-I:Aportaciones / ingresos recibidos por promotores o autoridades sometidas a revocación.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Anexo 1: Detalle por actividad proselitista.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Anexo Confidencial.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'FORMATO CPR-II:Gastos de campaña electoral efectuados por promotores o autoridades sometidas a revocación');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Histórico de resultados electorales',
  'Si quieres informarte sobre los resultados de los procesos electorales, puedes consultar el archivo histórico de elecciones de la ONPE para conocer los resultados de los comicios desarrollados en el Perú durante los últimos años.',
  'https://www.onpe.gob.pe/elecciones/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (ONPE / Inscribirse en el Sistema para Registro de Personas con Disc): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Inscribirse en el Sistema para Registro de Personas con Discapacidad de ONPE',
  'Si tienes una discapacidad y quieres tener facilidades en tu centro de votación en las futuras elecciones, debes inscribirte en el Sistema de Registro de Personas con Discapacidad (REDIS).',
  'https://redis.onpe.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('registros');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'registros'));
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (ONPE / Obtener constancia de Locación de Servicios en ONPE): costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Correo electrónico y número telefónico.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Obtener constancia de Locación de Servicios en ONPE',
  'Si eres o fuiste trabajados de ONPE bajo la modalidad de Locador de Servicios, puedes obtener tu constancia de Locación de Servicios de manera virtual.',
  'https://tuconstancia.onpe.gob.pe/',
  'VIRTUAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONPE / Obtener constancia de Locación de Servicios en ONPE): ninguna etiqueta matcheo, asignar a mano si aplica

-- REVISAR (ONPE / Libro de reclamaciones): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'SERVICIO'),
  'Libro de reclamaciones',
  'Si estás insatisfecho o disconforme con la atención brindada en una entidad pública, puedes presentar una queja o reclamo en su Libro de Reclamaciones. Con esto, se busca proteger tus derechos y lograr la eficiencia del Estado en la atención de los servicios brindados.',
  'https://www.gob.pe/68703-oficina-nacional-de-procesos-electorales-libro-de-reclamaciones',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('reclamos');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'reclamos'));

-- REVISAR (ONPE / Solicitar acceso a la información pública): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Número de DNI o carnet de extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Correo electrónico y teléfono de contacto.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Documentos, fotos o videos que sustenten tu reclamo, si lo consideras necesario.');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Solicitar acceso a la información pública',
  'Puedes acceder a la información de las instituciones del Estado según el principio de transparencia, el Texto Único Ordenado de la Ley N° 27806, Ley de Transparencia y Acceso a la Información Pública , y el Reglamento de la Ley N°27806, Ley de Transparencia y Acceso a la Información pública .',
  'https://www.gob.pe/50497-oficina-nacional-de-procesos-electorales-solicitar-acceso-a-la-informacion-publica',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO etiqueta (nombre) VALUES ('transparencia');
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'transparencia'));

-- REVISAR (ONPE / Presentar excusa para no ser miembro de mesa): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formulario de Solicitud de Acceso a la Información Pública, debidamente llenado, o cualquier otro documento que cumpla con las formalidades establecidas en el artículo 10 del Reglamento de laLey de Transparencia y Acceso a la Información Pública. También puedes realizar tu solicitud de forma online');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Nombres y apellidos completos, número de DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Correo electrónico, dirección y teléfono de contacto.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Si presentas tu solicitud física o escaneada, debes firmarla o colocar tu huella digital, en caso de  no saber firmar o estar impedido de hacerlo.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 5, 'Si presentas tu solicitud en la unidad de recepción documentaria de la entidad, la solicitud debe contener la firma del solicitante o huella digital, de no saber firmar o estar impedido de hacerlo.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 6, 'Indica la expresión concreta y precisa del pedido de información, así como cualquier otro dato que propicie la localización o facilite la búsqueda de la información solicitada. Si conoces la dependencia que posea la información, indícalo en tu solicitud; y, opcionalmente, la forma o modalidad en la');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Presentar excusa para no ser miembro de mesa',
  'Si fuiste elegido como miembro de mesa y no puedes cumplir con tu deber electoral, presenta una excusa hasta 5 días hábiles después de la publicación definitiva del listado. Según la Ley Orgánica de Elecciones, Ley N° 26859, el cargo de miembro de mesa es irrenunciable, pero.',
  'https://www.gob.pe/8227-presentar-excusa-para-no-ser-miembro-de-mesa',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES (@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = 'electoral'));

-- REVISAR (ONPE / Presentar información financiera como organización política): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 1, 'Formulario P2 - Excusa o Justificación.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 2, 'Si vas en representación de una tercera persona, llevar carta poder.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 3, 'Copia del DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (@tid, 4, 'Documentos probatorios según circunstancia:');
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ONPE'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'GUIA'),
  'Presentar información financiera como organización política',
  'El numeral 34.2 del artículo 34 de la Ley N.° 28094, Ley de Organizaciones Políticas y, sus modificatorias, señala que, La verificación y el control externos de la actividad económico-financiera de las organizaciones políticas corresponden a la Oficina Nacional de Procesos Electorales, a través de la Gerencia de Supervisión de Fondos Partidarios.',
  'https://www.gob.pe/114402-presentar-informacion-financiera-como-organizacion-politica',
  'PRESENCIAL',
  0.00
);
SET @tid = LAST_INSERT_ID();
-- REVISAR (ONPE / Presentar información financiera como organización política): ninguna etiqueta matcheo, asignar a mano si aplic
 
-- Sin ninguna etiqueta asignada (ningun keyword matcheo), revisa si aplica una a mano:
--   RENIEC: Consultar los horarios de centros de atención del RENIEC a nivel nacional
--   ESSALUD: Acceder a mesa de partes

-- =====================================================================
-- CONSULTAS DE VERIFICACIÓN
-- =====================================================================
-- Trámites por entidad con tipo y URL oficial
SELECT e.siglas, t.nombre AS tramite, tc.nombre AS tipo, t.url_oficial
FROM tramite t
JOIN entidad e        ON e.id_entidad = t.id_entidad
JOIN tipo_contenido tc ON tc.id_tipo   = t.id_tipo
WHERE t.activo = 1
ORDER BY e.siglas, t.nombre;

-- Búsqueda textual sobre la tabla de detalle
SELECT id_tramite, nombre, MATCH(nombre, descripcion) AGAINST('dni' IN NATURAL LANGUAGE MODE) AS relevancia
FROM tramite
WHERE MATCH(nombre, descripcion) AGAINST('dni' IN NATURAL LANGUAGE MODE);

SELECT * FROM entidad;
SELECT * FROM tramite;
SELECT * FROM requisito;
SELECT * FROM etiqueta;
SELECT * FROM tramite_etiqueta;