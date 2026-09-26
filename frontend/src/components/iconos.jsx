export function Icono({ d, size = 22, ...props }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>
      {d}
    </svg>
  );
}

export const Lupa = (p) => (
  <Icono {...p} d={<><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></>} />
);
export const Mic = (p) => (
  <Icono {...p} d={<><rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5 11a7 7 0 0 0 14 0M12 18v3" /></>} />
);
export const X = (p) => (
  <Icono {...p} d={<><circle cx="12" cy="12" r="9" /><path d="m9 9 6 6M15 9l-6 6" /></>} />
);
export const Doc = (p) => (
  <Icono {...p} d={<><path d="M6 2h8l4 4v16H6z" /><path d="M14 2v4h4" /></>} />
);
export const Engranaje = (p) => (
  <Icono {...p} d={<><circle cx="12" cy="12" r="3" /><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9 17 7M7 17l-2.1 2.1" /></>} />
);
export const Grafico = (p) => (
  <Icono {...p} d={<><path d="M4 20V4M4 20h16" /><path d="M8 16v-5M12 16V8M16 16v-3" /></>} />
);
export const Libro = (p) => (
  <Icono {...p} d={<><path d="M12 6c-2-1.5-5-2-8-2v14c3 0 6 .5 8 2 2-1.5 5-2 8-2V4c-3 0-6 .5-8 2z" /><path d="M12 6v14" /></>} />
);
export const Externo = (p) => (
  <Icono {...p} d={<><path d="M14 4h6v6M20 4 10 14" /><path d="M20 14v6H4V4h6" /></>} />
);
export const Check = (p) => (
  <Icono {...p} d={<><circle cx="12" cy="12" r="9" /><path d="m8 12.5 2.5 2.5L16 9.5" /></>} />
);
export const Info = (p) => (
  <Icono {...p} d={<><circle cx="12" cy="12" r="9" /><path d="M12 11v5M12 8v.1" /></>} />
);
export const Acceso = (p) => (
  <Icono {...p} d={<><circle cx="13" cy="4" r="1.6" /><path d="M4 8.5c2.7.5 5.3.8 8 .8s5.3-.3 8-.8M13 9.3v5l-2.5 6M13 14.3l3 3 1.5 3.5" /></>} />
);
export const ChevronDer = (p) => (
  <Icono {...p} d={<path d="m9 6 6 6-6 6" />} />
);
export const Escudo = (p) => (
  <Icono {...p} d={<><path d="M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z" /></>} />
);
export const Globo = (p) => (
  <Icono {...p} d={<><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c3 3.5 3 14 0 18M12 3c-3 3.5-3 14 0 18" /></>} />
);
export const Tarjeta = (p) => (
  <Icono {...p} d={<><rect x="3" y="6" width="18" height="13" rx="2" /><path d="M3 10h18" /></>} />
);
export const TextoAa = (p) => (
  <svg width={22} height={22} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="1.8" strokeLinecap="round" aria-hidden="true" {...p}>
    <text x="4" y="17" fontSize="13" fontWeight="800" fill="currentColor" stroke="none">Aa</text>
  </svg>
);
export const CursorFlecha = (p) => (
  <Icono {...p} d={<path d="M5 3l14 7-6.6 1.6L9 18z" />} />
);
