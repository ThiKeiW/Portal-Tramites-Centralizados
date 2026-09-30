// Placeholders temporales (sin conexión a BD todavía).
// Estructura alineada a bd/bd_tramites.sql:
//   entidad -> tramite (sin requisitos inline) + requisito 1:N (orden, descripcion).

export const CATEGORIAS = [
  {
    id: 'tramite',
    nombre: 'Trámites',
    descripcion: 'DNI, pasaportes, licencias, antecedentes, etc.',
    icono: 'doc',
  },
  {
    id: 'servicio',
    nombre: 'Servicios',
    descripcion: 'Consulta de SIS, AFP, RUC, ofertas de empleo',
    icono: 'gear',
  },
  {
    id: 'reporte',
    nombre: 'Reportes',
    descripcion: 'Historial crediticio, multas, aportes, deudas',
    icono: 'chart',
  },
  {
    id: 'guia',
    nombre: 'Guías',
    descripcion: 'Manuales explicativos paso a paso para trámites complejos',
    icono: 'book',
  },
];

export const ENTIDADES = [
  { siglas: 'SUNAT', nombre: 'Superintendencia Nacional de Aduanas y de Administración Tributaria', rubro: 'Tributos y aduanas', color: '#1e3a8a', sitioWeb: 'https://www.sunat.gob.pe' },
  { siglas: 'MINEDU', nombre: 'Ministerio de Educación', rubro: 'Educación y becas', color: '#7c3aed', sitioWeb: 'https://www.gob.pe/minedu' },
  { siglas: 'SUNARP', nombre: 'Superintendencia Nacional de los Registros Públicos', rubro: 'Registros públicos', color: '#059669', sitioWeb: 'https://www.gob.pe/sunarp' },
  { siglas: 'ESSALUD', nombre: 'Seguro Social de Salud', rubro: 'Salud y seguros', color: '#dc2626', sitioWeb: 'https://www.essalud.gob.pe' },
  { siglas: 'RENIEC', nombre: 'Registro Nacional de Identificación y Estado Civil', rubro: 'Identidad y estado civil', color: '#0284c7', sitioWeb: 'https://www.gob.pe/reniec' },
  { siglas: 'PNP', nombre: 'Policía Nacional del Perú', rubro: 'Seguridad y certificados', color: '#0f766e', sitioWeb: 'https://www.gob.pe/pnp' },
  { siglas: 'MTPE', nombre: 'Ministerio de Trabajo y Promoción del Empleo', rubro: 'Empleo y trabajo', color: '#b45309', sitioWeb: 'https://www.gob.pe/mtpe' },
  { siglas: 'INPE', nombre: 'Instituto Nacional Penitenciario', rubro: 'Antecedentes judiciales', color: '#4d7c0f', sitioWeb: 'https://www.gob.pe/inpe' },
];

// Tabla tramite: costo DECIMAL (0.00 = gratuito), modalidad ENUM única.
export const TRAMITES = [
  {
    id: 1,
    nombre: 'Certificado de Antecedentes Penales',
    tipo: 'tramite',
    entidad: 'PNP',
    descripcion:
      'El Certificado de Antecedentes Penales es un documento oficial que acredita si una persona registra o no antecedentes penales. Es un requisito fundamental solicitado por diversas entidades para trámites laborales, migratorios, consulares y administrativos en general dentro y fuera del territorio nacional.',
    costo: 35.0,
    modalidad: 'PRESENCIAL',
    urlOficial: 'https://www.gob.pe/pnp',
  },
  {
    id: 2,
    nombre: 'Certificado Único Laboral',
    tipo: 'servicio',
    entidad: 'MTPE',
    descripcion:
      'El Certificado Único Laboral (CUL) es un documento gratuito emitido por el Ministerio de Trabajo que reúne en un solo archivo la identidad, los antecedentes y la experiencia laboral formal del ciudadano para facilitar su inserción laboral.',
    costo: 0.0,
    modalidad: 'VIRTUAL',
    urlOficial: 'https://www.gob.pe/mtpe',
  },
  {
    id: 3,
    nombre: 'Constancia de No Adeudo Tributario',
    tipo: 'tramite',
    entidad: 'SUNAT',
    descripcion:
      'Documento que certifica que el contribuyente no mantiene deuda tributaria exigible ante la SUNAT. Suele solicitarse en contrataciones con el Estado y trámites financieros.',
    costo: 0.0,
    modalidad: 'VIRTUAL',
    urlOficial: 'https://www.sunat.gob.pe',
  },
  {
    id: 4,
    nombre: 'Duplicado de DNI',
    tipo: 'tramite',
    entidad: 'RENIEC',
    descripcion:
      'Trámite para reponer el DNI en caso de pérdida, robo o deterioro. El duplicado mantiene los mismos datos del documento anterior.',
    costo: 24.0,
    modalidad: 'PRESENCIAL',
    urlOficial: 'https://www.gob.pe/reniec',
  },
  {
    id: 5,
    nombre: 'Certificado de Antecedentes Policiales',
    tipo: 'tramite',
    entidad: 'PNP',
    descripcion:
      'Certificado emitido por la Policía Nacional del Perú que informa sobre los antecedentes policiales del solicitante.',
    costo: 17.0,
    modalidad: 'PRESENCIAL',
    urlOficial: 'https://www.gob.pe/pnp',
  },
  {
    id: 6,
    nombre: 'Certificado de Antecedentes Judiciales',
    tipo: 'tramite',
    entidad: 'INPE',
    descripcion:
      'Documento emitido por el Instituto Nacional Penitenciario que certifica los antecedentes judiciales del ciudadano.',
    costo: 37.4,
    modalidad: 'PRESENCIAL',
    urlOficial: 'https://www.gob.pe/inpe',
  },
  {
    id: 7,
    nombre: 'Consulta RUC',
    tipo: 'servicio',
    entidad: 'SUNAT',
    descripcion:
      'Servicio en línea para verificar el número de RUC, razón social, estado del contribuyente y condición de domicilio fiscal.',
    costo: 0.0,
    modalidad: 'VIRTUAL',
    urlOficial: 'https://www.sunat.gob.pe',
  },
  {
    id: 8,
    nombre: 'Beca 18: guía de postulación',
    tipo: 'guia',
    entidad: 'MINEDU',
    descripcion:
      'Guía oficial del Pronabec con los pasos para la postulación a Beca 18, desde la creación de la casilla electrónica hasta la aceptación de la beca.',
    costo: 0.0,
    modalidad: 'VIRTUAL',
    urlOficial: 'https://www.gob.pe/minedu',
  },
  {
    id: 9,
    nombre: 'Reporte de deudas SBS',
    tipo: 'reporte',
    entidad: 'SUNAT',
    descripcion:
      'Reporte que consolida las deudas del ciudadano en el sistema financiero nacional, útil antes de solicitar créditos.',
    costo: 0.0,
    modalidad: 'VIRTUAL',
    urlOficial: 'https://www.sunat.gob.pe',
  },
];

// Tabla requisito normalizada 1:N (id_requisito, id_tramite, orden, descripcion).
export const REQUISITOS = [
  { id: 1, idTramite: 1, orden: 1, descripcion: 'DNI vigente del solicitante.' },
  { id: 2, idTramite: 1, orden: 2, descripcion: 'Pago de tasa administrativa (S/ 35.00) realizado en el Banco de la Nación o plataforma Págalo.pe.' },
  { id: 3, idTramite: 1, orden: 3, descripcion: 'Formulario de solicitud completado correctamente.' },
  { id: 4, idTramite: 1, orden: 4, descripcion: 'Fotografía tamaño pasaporte con fondo blanco (requerido únicamente para la modalidad presencial).' },
  { id: 5, idTramite: 2, orden: 1, descripcion: 'DNI vigente o carné de extranjería.' },
  { id: 6, idTramite: 2, orden: 2, descripcion: 'Cuenta registrada en el portal Empleos Perú.' },
  { id: 7, idTramite: 2, orden: 3, descripcion: 'Correo electrónico activo para recibir el documento.' },
  { id: 8, idTramite: 3, orden: 1, descripcion: 'Clave SOL habilitada.' },
  { id: 9, idTramite: 3, orden: 2, descripcion: 'No registrar deuda tributaria exigible.' },
  { id: 10, idTramite: 3, orden: 3, descripcion: 'Buzón electrónico afiliado.' },
  { id: 11, idTramite: 4, orden: 1, descripcion: 'Pago de tasa administrativa (S/ 24.00).' },
  { id: 12, idTramite: 4, orden: 2, descripcion: 'Denuncia policial en caso de robo (solo modalidad presencial).' },
  { id: 13, idTramite: 4, orden: 3, descripcion: 'Foto actualizada según especificaciones de RENIEC.' },
  { id: 14, idTramite: 5, orden: 1, descripcion: 'DNI vigente del solicitante.' },
  { id: 15, idTramite: 5, orden: 2, descripcion: 'Pago de tasa administrativa (S/ 17.00).' },
  { id: 16, idTramite: 6, orden: 1, descripcion: 'DNI vigente del solicitante.' },
  { id: 17, idTramite: 6, orden: 2, descripcion: 'Pago de tasa administrativa (S/ 37.40).' },
  { id: 18, idTramite: 7, orden: 1, descripcion: 'Número de RUC, DNI o razón social a consultar.' },
  { id: 19, idTramite: 8, orden: 1, descripcion: 'Ser peruano o peruana de nacimiento.' },
  { id: 20, idTramite: 8, orden: 2, descripcion: 'Haber culminado la secundaria.' },
  { id: 21, idTramite: 8, orden: 3, descripcion: 'Acreditar condición de pobreza según el Sisfoh.' },
  { id: 22, idTramite: 9, orden: 1, descripcion: 'DNI vigente.' },
  { id: 23, idTramite: 9, orden: 2, descripcion: 'Clave SOL o cuenta en el portal SBS.' },
];

export const BUSQUEDAS_POPULARES = ['DNI duplicado', 'RUC consulta', 'Antecedentes Penales', 'Beca 18'];

export const TIPO_LABEL = {
  tramite: 'TRÁMITE',
  servicio: 'SERVICIO',
  reporte: 'REPORTE',
  guia: 'GUÍA',
};

export const MODALIDAD_LABEL = {
  VIRTUAL: 'Virtual',
  PRESENCIAL: 'Presencial',
  SEMIPRESENCIAL: 'Semipresencial',
};

export function entidadPorSiglas(siglas) {
  return ENTIDADES.find((e) => e.siglas === siglas);
}

export function requisitosDe(idTramite) {
  return REQUISITOS.filter((r) => r.idTramite === idTramite).sort((a, b) => a.orden - b.orden);
}

export function formatoCosto(costo) {
  return costo === 0 ? 'Gratuito' : `S/ ${Number(costo).toFixed(2)}`;
}
