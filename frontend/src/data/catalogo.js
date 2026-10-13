// Metadatos de presentación que NO viven en la BD:
// descripciones e iconos de categorías, colores de entidades y etiquetas.

export const CATEGORIA_META = {
  tramite: {
    nombre: 'Trámites',
    descripcion: 'DNI, pasaportes, licencias, antecedentes, etc.',
    icono: 'doc',
  },
  servicio: {
    nombre: 'Servicios',
    descripcion: 'Consulta de SIS, AFP, RUC, ofertas de empleo',
    icono: 'gear',
  },
  reporte: {
    nombre: 'Reportes',
    descripcion: 'Historial crediticio, multas, aportes, deudas',
    icono: 'chart',
  },
  guia: {
    nombre: 'Guías',
    descripcion: 'Manuales explicativos paso a paso para trámites complejos',
    icono: 'book',
  },
};

const COLORES_ENTIDAD = {
  SUNAT: '#1e3a8a',
  RENIEC: '#0284c7',
  SUNARP: '#059669',
  ESSALUD: '#dc2626',
  MINEDU: '#7c3aed',
  MIGRACIONES: '#0e7490',
  MTC: '#ea580c',
  MININTER: '#1d4ed8',
  PJ: '#44403c',
  MINJUS: '#6d28d9',
  SIS: '#65a30d',
  MINSA: '#0891b2',
  ONP: '#4d7c0f',
  MIDIS: '#db2777',
  SUNAFIL: '#c2410c',
  MTPE: '#a16207',
  INDECOPI: '#7c2d12',
  SBS: '#0f766e',
  JNE: '#be123c',
  ONPE: '#4338ca',
};

export const ENTIDADES_DESTACADAS = ['SUNAT', 'RENIEC', 'SUNARP', 'ESSALUD'];

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

export function colorEntidad(siglas) {
  return COLORES_ENTIDAD[siglas] ?? '#475569';
}

/** 'SERVICIO' -> 'servicio' (id usado en filtros, insignias y navegación). */
export function tipoId(tipoNombre) {
  return (tipoNombre ?? '').toLowerCase();
}

export function categoriaDe(tipoNombre) {
  const id = tipoId(tipoNombre);
  return {
    id,
    ...(CATEGORIA_META[id] ?? { nombre: tipoNombre || 'Trámites', descripcion: '', icono: 'doc' }),
  };
}

export function formatoCosto(costo) {
  return Number(costo) === 0 ? 'Gratuito' : `S/ ${Number(costo).toFixed(2)}`;
}
