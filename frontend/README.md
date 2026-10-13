# Frontend — Portal Único de Trámites

Web responsiva en **React + Vite**, basada en los mockups de Figma
(pantallas: home, resultados, modal de voz, panel de accesibilidad, detalle).

> Conectado a la API REST del backend (`src/api/portalApi.js`). Para desarrollo,
> levanta primero el backend en `http://localhost:8080` (o define `VITE_API_URL`
> en un archivo `frontend/.env`). El backend solo acepta CORS desde
> `http://localhost:5173`.

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
- **Contrastes:** Normal / Alto / Oscuro / Grises (escala de grises)
- **Cursor:** Estándar / Grande (flecha de 40px de alto contraste)

## Estructura

```
src/
├── context/AccessibilityContext.jsx  # preferencias + data-attrs en <html>
├── api/portalApi.js                  # cliente HTTP de la API REST
├── data/catalogo.js                  # metadatos visuales (iconos, colores, etiquetas)
├── pages/                            # Home, Resultados, Detalle
├── components/                       # Navbar, ModalVoz, PanelAccesibilidad,
│                                     # BotonFlotante, iconos
├── App.jsx                           # navegación por estado (sin router)
└── styles.css                        # temas por [data-contraste]
```
