// Cliente HTTP de la API REST del backend (Spring Boot).
// La URL se puede sobreescribir con la variable VITE_API_URL (archivo .env).
// El backend solo acepta peticiones CORS desde http://localhost:5173.

const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:8080';

async function pedir(ruta) {
  let res;
  try {
    res = await fetch(`${API_URL}${ruta}`);
  } catch {
    throw new Error(`No se pudo conectar con la API en ${API_URL}. Verifica que el backend esté corriendo.`);
  }
  if (!res.ok) {
    let detalle = '';
    try {
      const cuerpo = await res.json();
      detalle = cuerpo.mensaje ?? '';
    } catch {
      /* la respuesta no trae JSON */
    }
    throw new Error(detalle || `La API respondió con error ${res.status}.`);
  }
  return res.json();
}

export const api = {
  /** Entidades públicas activas. */
  entidades: () => pedir('/api/entidades'),

  /** Tipos de contenido (TRAMITE, SERVICIO, REPORTE, GUIA). */
  tipos: () => pedir('/api/tipos'),

  /** Búsqueda textual en nombre/descripción (el backend ordena A–Z). */
  buscarTramites: (q = '') => {
    const texto = q.trim();
    return pedir(texto ? `/api/tramites?q=${encodeURIComponent(texto)}` : '/api/tramites');
  },

  /** Detalle de un trámite (incluye requisitos y etiquetas). */
  tramite: (id) => pedir(`/api/tramites/${id}`),

  /** Documentos relacionados por etiquetas compartidas. */
  relacionados: (id, limite = 3) => pedir(`/api/tramites/${id}/relacionados?limite=${limite}`),
};
