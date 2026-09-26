// Placeholders temporales (sin conexión a BD todavía).
// Estructura alineada al modelo MySQL: entidad -> tramite (detalle con requisitos y url_oficial).

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

export const TRAMITES = [
  {
    id: 1,
    nombre: 'Certificado de Antecedentes Penales',
    tipo: 'tramite',
    entidad: 'PNP',
    descripcion:
      'Solicitud y expedición oficial de antecedentes penales de la Policía Nacional del Perú, necesario para fines laborales, de viaje o judiciales.',
    descripcionLarga:
      'El Certificado de Antecedentes Penales es un documento oficial que acredita si una persona registra o no antecedentes penales. Es un requisito fundamental solicitado por diversas entidades para trámites laborales, migratorios, consulares y administrativos en general dentro y fuera del territorio nacional.',
    requisitos: [
      'DNI vigente del solicitante.',
      'Pago de tasa administrativa (S/ 35.00) realizado en el Banco de la Nación o plataforma Págalo.pe.',
      'Formulario de solicitud completado correctamente.',
      'Fotografía tamaño pasaporte con fondo blanco (requerido únicamente para la modalidad presencial).',
    ],
    costo: 'S/ 35.00',
    modalidad: 'Virtual y Presencial',
    urlOficial: 'https://www.gob.pe/pnp',
  },
  {
    id: 2,
    nombre: 'Certificado Único Laboral',
    tipo: 'servicio',
    entidad: 'MTPE',
    descripcion:
      'Documento oficial gratuito que unifica información sobre identidad, antecedentes policiales, judiciales, penales y trayectoria laboral formal.',
    descripcionLarga:
      'El Certificado Único Laboral (CUL) es un documento gratuito emitido por el Ministerio de Trabajo que reúne en un solo archivo la identidad, los antecedentes y la experiencia laboral formal del ciudadano para facilitar su inserción laboral.',
    requisitos: [
      'DNI vigente o carné de extranjería.',
      'Cuenta registrada en el portal Empleos Perú.',
      'Correo electrónico activo para recibir el documento.',
    ],
    costo: 'Gratuito',
    modalidad: 'Virtual',
    urlOficial: 'https://www.gob.pe/mtpe',
  },
  {
    id: 3,
    nombre: 'Constancia de No Adeudo Tributario',
    tipo: 'tramite',
    entidad: 'SUNAT',
    descripcion:
      'Acreditación oficial emitida por el órgano tributario que demuestra que no posees deudas vigentes ni resoluciones fiscales activas.',
    descripcionLarga:
      'Documento que certifica que el contribuyente no mantiene deuda tributaria exigible ante la SUNAT. Suele solicitarse en contrataciones con el Estado y trámites financieros.',
    requisitos: [
      'Clave SOL habilitada.',
      'No registrar deuda tributaria exigible.',
      'Buzón electrónico afiliado.',
    ],
    costo: 'Gratuito',
    modalidad: 'Virtual',
    urlOficial: 'https://www.sunat.gob.pe',
  },
  {
    id: 4,
    nombre: 'Duplicado de DNI',
    tipo: 'tramite',
    entidad: 'RENIEC',
    descripcion:
      'Obtén un duplicado de tu Documento Nacional de Identidad por pérdida, robo o deterioro, de forma presencial o virtual.',
    descripcionLarga:
      'Trámite para reponer el DNI en caso de pérdida, robo o deterioro. El duplicado mantiene los mismos datos del documento anterior.',
    requisitos: [
      'Pago de tasa administrativa (S/ 24.00).',
      'Denuncia policial en caso de robo (solo modalidad presencial).',
      'Foto actualizada según especificaciones de RENIEC.',
    ],
    costo: 'S/ 24.00',
    modalidad: 'Virtual y Presencial',
    urlOficial: 'https://www.gob.pe/reniec',
  },
  {
    id: 5,
    nombre: 'Certificado de Antecedentes Policiales',
    tipo: 'tramite',
    entidad: 'PNP',
    descripcion:
      'Documento que acredita si registras o no antecedentes policiales. Requisito habitual para empleos y viajes.',
    descripcionLarga:
      'Certificado emitido por la Policía Nacional del Perú que informa sobre los antecedentes policiales del solicitante.',
    requisitos: [
      'DNI vigente del solicitante.',
      'Pago de tasa administrativa (S/ 17.00).',
    ],
    costo: 'S/ 17.00',
    modalidad: 'Virtual y Presencial',
    urlOficial: 'https://www.gob.pe/pnp',
  },
  {
    id: 6,
    nombre: 'Certificado de Antecedentes Judiciales',
    tipo: 'tramite',
    entidad: 'INPE',
    descripcion:
      'Acredita si una persona registra o no antecedentes judiciales a nivel nacional.',
    descripcionLarga:
      'Documento emitido por el Instituto Nacional Penitenciario que certifica los antecedentes judiciales del ciudadano.',
    requisitos: [
      'DNI vigente del solicitante.',
      'Pago de tasa administrativa (S/ 37.40).',
    ],
    costo: 'S/ 37.40',
    modalidad: 'Virtual y Presencial',
    urlOficial: 'https://www.gob.pe/inpe',
  },
  {
    id: 7,
    nombre: 'Consulta RUC',
    tipo: 'servicio',
    entidad: 'SUNAT',
    descripcion:
      'Consulta gratuita del estado y condición del RUC de personas y empresas.',
    descripcionLarga:
      'Servicio en línea para verificar el número de RUC, razón social, estado del contribuyente y condición de domicilio fiscal.',
    requisitos: ['Número de RUC, DNI o razón social a consultar.'],
    costo: 'Gratuito',
    modalidad: 'Virtual',
    urlOficial: 'https://www.sunat.gob.pe',
  },
  {
    id: 8,
    nombre: 'Beca 18: guía de postulación',
    tipo: 'guia',
    entidad: 'MINEDU',
    descripcion:
      'Manual paso a paso para postular a Beca 18: requisitos, cronograma y registro.',
    descripcionLarga:
      'Guía oficial del Pronabec con los pasos para la postulación a Beca 18, desde la creación de la casilla electrónica hasta la aceptación de la beca.',
    requisitos: [
      'Ser peruano o peruana de nacimiento.',
      'Haber culminado la secundaria.',
      'Acreditar condición de pobreza según el Sisfoh.',
    ],
    costo: 'Gratuito',
    modalidad: 'Virtual',
    urlOficial: 'https://www.gob.pe/minedu',
  },
  {
    id: 9,
    nombre: 'Reporte de deudas SBS',
    tipo: 'reporte',
    entidad: 'SUNAT',
    descripcion:
      'Reporte de tu historial crediticio y deudas registradas en el sistema financiero.',
    descripcionLarga:
      'Reporte que consolida las deudas del ciudadano en el sistema financiero nacional, útil antes de solicitar créditos.',
    requisitos: ['DNI vigente.', 'Clave SOL o cuenta en el portal SBS.'],
    costo: 'Gratuito',
    modalidad: 'Virtual',
    urlOficial: 'https://www.sunat.gob.pe',
  },
];

export const BUSQUEDAS_POPULARES = ['DNI duplicado', 'RUC consulta', 'Antecedentes Penales', 'Beca 18'];

export const TIPO_LABEL = {
  tramite: 'TRÁMITE',
  servicio: 'SERVICIO',
  reporte: 'REPORTE',
  guia: 'GUÍA',
};

export function entidadPorSiglas(siglas) {
  return ENTIDADES.find((e) => e.siglas === siglas);
}
