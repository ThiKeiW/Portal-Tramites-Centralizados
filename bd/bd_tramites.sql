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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Ficha de inscripción:Debes completar tus datos personales, de contacto, laborales y de formación en el aplicativo.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Documentos de experiencia:Debes presentar documentos que demuestren un año de experiencia como mínimo ejecutando trámites de registros civiles. La experiencia debe haberse desarrollado dentro de los últimos 10 años. Los documentos válidos incluyen contratos de trabajo, certificados, constancias, bol');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Ver requisitos en la convocatoria vigente');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Dispositivo:Computadora de escritorio, laptop, tablet o teléfono celular.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Conexión a Internet:Para la navegación y descarga de archivos PDF.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Contar con DNI electrónico');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Contar con lector de tarjetas digitales');

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

INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Correo electrónico activo: Recibirás un código de validación en tu bandeja de entrada.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Pago del trámite: Debes realizar el pago antes de agendar tu cita presencial.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Formato de solicitud que te brindan en el centro de atención.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Copia certificada del acta registral o de la constancia por autenticar (No fotocopia).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Exhibir tu DNI si eres peruano, o carnet de extranjería, pasaporte o cédula de identidad si eres extranjero.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Formato de Solicitud suscrita con carácter de Declaración Jurada para hacer el cambio de lugar de recojo emitido enCentro de Atención del RENIEC');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Recibo de Pago por Derechos Administrativos.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Recibo original de servicios públicos, tributo municipal o Declaración Jurada de Domicilio en caso no contar con servicios públicos en tu domicilio.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Para registrar tu  estado civil, presenta la documentación del Anexo Nº 2 del TUPA según tu caso.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Para registrar tu grado de instrucción presenta los documentos especificados en elAnexo Nº 4 del TUPAsegún tu caso.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'En caso de tener alguna discapacidad, debes firmar la Declaración Jurada de Discapacidad y Asistencia. Además, deberás agregar:');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 5, 'Original y copia simple del Certificado de Discapacidad en el formato aprobado por el Minsa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 6, 'Resolución Ejecutiva del Conadis.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 7, 'Constancia médica de discapacidad que señale la discapacidad física, sensorial, mental o  intelectual');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Conocer el número de DNI o número de solicitud.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Usuario y clave de acceso que solicitas mediante oficio a la Gerencia de Servicios de Valor Añadido de Reniec del Ministerio de Relaciones Exteriores.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Conocer el trámite que vas a realizar y el código correspondiente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Acceder a laTicketera RENIEC desde cualquier dispositivo con conexión a internet.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Solicitud suscrita con carácter de declaración jurada.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Parte notarial de otorgamiento de reconocimiento o protocolización del testamento.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Exhibir tu DNI.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Contar con cuenta de Facebook');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Servicio activo de lunes a viernes en el horario de las 8:30 a. m. a 5:30 p. m');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Solicitud de acceso a la información pública.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Clave SOL.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'RUC y Clave SOL.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Horario de atención de lunes a viernes de 8:30 a.m. a 6:00 p.m.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Ser persona natural o sucesión indivisa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'DNI vigente, Carnet de Extranjería, Carnet de Identidad, Carnet de Permiso Temporal de Permanencia o Pasaporte con calidad migratoria para la generación de renta de fuente peruana.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Si cuentas con representante legal, debes exhibir el DNI de éste.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Si vas a registrar una dirección distinta a la de tu DNI, debes presentar el original de tu DNI y cualquier documento privado o público en el que conste la dirección del domicilio fiscal.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 5, 'Carta poder con firma legalizada notarialmente o autenticada por fedatario de SUNAT, que lo autorice expresamente a realizar el trámite de inscripción en el RUC.  (Si el trámite lo hace un tercero)');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'RUC.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Tener la información de los comprobantes a enviar (contingencia, percepción y retención u otros).');

-- REVISAR (SUNAT / Acceder al Régimen General): no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial; costo asumido 0.00, no se encontro monto -- verificar TUPA
INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'SUNAT'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'TRAMITE'),
  'Declarar y pagar impuestos en el Régimen General',
  'Es el procedimiento por el que registras los ingresos obtenidos por tu actividad empresarial dentro del régimen Régimen General como establecen las obligaciones tributarias.',
  'https://www.gob.pe/1173-declaracion-y-pago-del-impuesto-para-negocios-declaracion-y-pago-en-el-regimen-general',
  'PRESENCIAL O VIRTUAL',
  0.00
);
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Ventas e ingresos del mes (periodo a declarar).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Compras por adquisición de bienes y prestación de servicios del mes (periodo a declarar).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Saldo a favor del periodo anterior, de corresponder.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Monto de retenciones y percepciones del IGV que te efectuaron en el periodo y/o saldo de periodos anteriores .');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 5, 'Coeficiente para el pago a cuenta mensual de renta, de corresponder.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 6, 'Pagos previos, de corresponder (efectuados con boletas de pago).');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'RUC y clave SOL.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Usuario y contraseña .');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Clave SOL. Si no la tienes, trámitala a través de Sunat Virtual del App Personas.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Información de la empresa como nombre comercial, fecha de inicio de actividades, actividad principal y secundaria, dirección de domicilio fiscal, datos de contacto, entre otros.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Contar con acreditación vigente del Seguro EsSalud.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Documento de identidad (DNI), Pasaporte, Carnet de Extranjería (CE) o  Permiso Temporal de permanencia (PTP).');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'DNI, certificado de extranjería, permiso temporal de permanencia');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Si eres trabajador regular (dependiente), presenta tu última boleta o penúltima boleta de remuneración.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Si eres trabajadora del hogar, presenta tus tres últimos recibos de pago del seguro.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Si erespensionista,presenta tu resolución de pensionista');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 5, 'Si eres beneficiario de la Ley 30425, presenta tu constancia de retiro');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 6, 'Si eres afiliado al seguro independiente, presenta tu recibo del último pago realizado');

INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (
  (SELECT id_entidad FROM entidad WHERE siglas = 'ESSALUD'),
  (SELECT id_tipo FROM tipo_contenido WHERE nombre = 'REPORTE'),
  'Oficinas de Seguros y Prestaciones Económicas (OSPE)',
  'Puedes observar las sedes que se encuentran activas. En nuestras OSPE, puedes realizar trámites de afiliación, recibir orientación sobre los seguros administrados por EsSalud y gestionar tus prestaciones económicas.',
  'https://www.gob.pe/114429-oficinas-de-seguros-y-prestaciones-economicas-ospe',
  'VIRTUAL',
  0.00
);

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'DNI original del paciente.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'DNI original del familiar responsable.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Si tienes alguna discapacidad, presenta tuCarnet de Conadis en físico (amarillo).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Referencia de tu centro asistencial.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 5, 'Asistir a charla de inducción brindada por Padomi.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 6, 'Si no eres familiar directo del paciente, debes presentar una carta poder simple.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 7, 'Croquis de cómo llegar a tu domicilio');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'DNI o Carnet de Extranjería.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'DNI o Carnet de Extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Resolución de designación');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Documento de identidad, carnet de extranjería o pasaporte.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Para ser atendido en EsSalud tu seguro debe de estar activo, para verificarlo puedes hacerlo a través de:');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Solicitud simple que exprese claramente tu pedido.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Número de DNI, RUC, pasaporte o carnet de extranjería.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Correo electrónico y número de teléfono.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Documentos (oficio, carta, solicitud u otro) que sustente el trámite que deseas realizar.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Marcar como entidad donde se origina la denuncia: Seguro Social de Salud');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Correo electrónico y número telefónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'En caso de presentar la denuncia como persona jurídica, número de RUC.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Documentación original o copia simple que sustente tu denuncia. También puedes precisar la unidad o dependencia donde se efectuó el hecho.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'DNI, Certificado de extranjería, pasaporte o RUC');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Correo electrónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Número celular');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Contar con usuario y contraseña en el SPRL.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Contar con usuario y contraseña del sistema.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'RUC');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Razón social');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Registro Nacional de Proveedores (RNP)');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Email');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 5, 'Teléfono');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 6, 'Persona de contacto');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 7, 'Grupo de convocatoria al que postula.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Número de DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Fecha de emisión de DNI.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Datos personales del titular del vehículo');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Detalles de las características del vehículo');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Número de Documento Nacional de Identidad (DNI).');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Número del teléfono celular del usuario.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Número de placa.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Número de TIVE.');

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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Usuario y contraseña para acceder al SID - SUNARP.');



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
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 1, 'Número de DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 2, 'Fecha de emisión del DNI.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 3, 'Correo electrónico.');
INSERT INTO requisito (id_tramite, orden, descripcion) VALUES (LAST_INSERT_ID(), 4, 'Última tarjeta de identificación vehicular (TIV) física expedida por la Sunarp.');

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