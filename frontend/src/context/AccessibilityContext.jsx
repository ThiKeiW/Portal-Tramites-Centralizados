import { createContext, useContext, useEffect, useState } from 'react';

// Opciones: 4 contrastes, 3 tamaños de texto, 2 tamaños de cursor.
export const CONTRASTES = [
  { id: 'normal', label: 'Normal' },
  { id: 'alto', label: 'Alto' },
  { id: 'oscuro', label: 'Oscuro' },
  { id: 'gris', label: 'Grises' },
];

export const TAMANOS_TEXTO = [
  { id: 'normal', label: 'Normal' },
  { id: 'grande', label: 'Grande' },
  { id: 'extra', label: 'Extra grande' },
];

export const CURSORES = [
  { id: 'estandar', label: 'Estándar' },
  { id: 'grande', label: 'Grande' },
];

const STORAGE_KEY = 'portal-a11y-prefs';

const DEFAULTS = { contraste: 'normal', tamanoTexto: 'normal', cursor: 'estandar' };

function leerPreferencias() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULTS;
    const p = JSON.parse(raw);
    return {
      contraste: CONTRASTES.some((c) => c.id === p.contraste) ? p.contraste : 'normal',
      tamanoTexto: TAMANOS_TEXTO.some((t) => t.id === p.tamanoTexto) ? p.tamanoTexto : 'normal',
      cursor: CURSORES.some((c) => c.id === p.cursor) ? p.cursor : 'estandar',
    };
  } catch {
    return DEFAULTS;
  }
}

const AccessibilityContext = createContext(null);

export function AccessibilityProvider({ children }) {
  const [prefs, setPrefs] = useState(leerPreferencias);

  useEffect(() => {
    const root = document.documentElement;
    root.dataset.contraste = prefs.contraste;
    root.dataset.texto = prefs.tamanoTexto;
    root.dataset.cursor = prefs.cursor;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
    } catch {
      /* sin almacenamiento disponible */
    }
  }, [prefs]);

  const set = (patch) => setPrefs((prev) => ({ ...prev, ...patch }));
  const restablecer = () => setPrefs(DEFAULTS);

  return (
    <AccessibilityContext.Provider value={{ ...prefs, set, restablecer }}>
      {children}
    </AccessibilityContext.Provider>
  );
}

export function useAccessibility() {
  const ctx = useContext(AccessibilityContext);
  if (!ctx) throw new Error('useAccessibility debe usarse dentro de AccessibilityProvider');
  return ctx;
}

export function labelDe(lista, id) {
  return lista.find((o) => o.id === id)?.label ?? '';
}
