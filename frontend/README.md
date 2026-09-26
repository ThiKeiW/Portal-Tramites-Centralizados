# Frontend — Portal Único de Trámites

Web responsiva en **React + Vite**, basada en los mockups de Figma
(pantallas: home, resultados, modal de voz, panel de accesibilidad, detalle).

> Sin conexión a BD todavía: entidades, categorías y trámites son
> **placeholders** en `src/data/placeholders.js` (estructura alineada
> al modelo MySQL de `bd/portal_tramites.sql`).

## Ejecutar

```bash
cd frontend
npm install
npm run dev
```

## Accesibilidad (foco del avance)

Panel flotante (botón inferior derecho) con aplicación instantánea y
persistencia en `localStorage`:

- **Tamaño de texto:** Normal / Grande / Extra grande
- **Contrastes:** Normal / Alto / Oscuro
- **Cursor:** Estándar / Grande (flecha de 40px de alto contraste)

## Estructura

```
src/
├── a11y/AccessibilityContext.jsx  # preferencias + data-attrs en <html>
├── data/placeholders.js           # entidades, categorías, trámites
├── components/                    # Navbar, Home, Resultados, Detalle,
│                                  # ModalVoz, PanelAccesibilidad, ...
├── App.jsx                        # navegación por estado (sin router)
└── styles.css                     # temas por [data-contraste]
```
