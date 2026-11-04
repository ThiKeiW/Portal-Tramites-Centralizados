// Cliente HTTP de la API REST del backend (Spring Boot).
// La URL se puede sobreescribir con la variable VITE_API_URL (archivo .env).
// El backend solo acepta peticiones CORS desde http://localhost:5173.

const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:8080';

// Cache de respuestas estables (catálogos): un solo fetch por recurso, se
// comparte entre Home y Resultados y sobrevive a la navegación dentro de la
// sesión (evita re-consultar a la BD en la nube en cada montaje de página).
const cache = new Map();

function pedir(ruta) {
  const enCache = cache.get(ruta);
  if (enCache) return enCache;
  const promesa = (async () => {
    let res;
    try {
      res = await fetch(`${API_URL}${ruta}`);
    } catch {
      throw new Error(`No se pudo conectar con la API en ${API_URL}. Verifica que el backend esté corriendo.`);
    }
    if (!res.ok) {
      throw new Error((await extraerMensaje(res)) || `La API respondió con error ${res.status}.`);
    }
    return res.json();
  })();
  cache.set(ruta, promesa);
  // Al fallar, descartar la promesa en cache para poder reintentar.
  promesa.catch(() => cache.delete(ruta));
  return promesa;
}

async function extraerMensaje(res) {
  try {
    const cuerpo = await res.json();
    return cuerpo.mensaje ?? '';
  } catch {
    return '';
  }
}

export const api = {
  /** Entidades públicas activas. */
  entidades: () => pedir('/api/entidades'),

  /** Tipos de contenido (TRAMITE, SERVICIO, REPORTE, GUIA). */
  tipos: () => pedir('/api/tipos'),

  /** Búsqueda textual: el backend ordena por relevancia con q, A–Z sin q. */
  buscarTramites: (q = '') => {
    const texto = q.trim();
    return pedir(texto ? `/api/tramites?q=${encodeURIComponent(texto)}` : '/api/tramites');
  },

  /** Detalle de un trámite (incluye requisitos y etiquetas). */
  tramite: (id) => pedir(`/api/tramites/${id}`),

  /** Documentos relacionados por etiquetas compartidas. */
  relacionados: (id, limite = 3) => pedir(`/api/tramites/${id}/relacionados?limite=${limite}`),

  /**
   * Búsqueda por voz: envía el audio al backend, que lo transcribe con
   * DeepGram (es-419 + keyterms) y resuelve la intención contra el catálogo.
   * Responde { transcripcion, confianza, tramites }.
   */
  transcribirVoz: async (audioBlob) => {
    let res;
    try {
      res = await fetch(`${API_URL}/api/voz/transcribir`, {
        method: 'POST',
        headers: { 'Content-Type': audioBlob.type || 'audio/wav' },
        body: audioBlob,
      });
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
  },
};
