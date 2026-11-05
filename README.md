# Portal Único de Trámites Peruanos 🏛️

Portal web que **centraliza el acceso** a trámites, servicios, reportes, documentos y guías de las principales **entidades públicas del Perú** (SUNAT, MINEDU, RENIEC, ESSALUD, entre otras). Permite al ciudadano ubicar y acceder a la información oficial sin conocer de antemano a qué entidad ni a qué sitio debería dirigirse, y está orientado a la **accesibilidad para personas con discapacidades visuales**.

> Curso: **Interacción Hombre Máquina** · Sección 32645 · Perú · 2026

🌐 **Portal desplegado en línea:** https://happy-glacier-010251d0f.4.azurestaticapps.net

---

## 📋 Descripción

La plataforma centraliza la **información (no la ejecución)** de trámites y servicios públicos. Incorpora:

- 🔍 **Búsqueda por voz** mediante la API de **Deepgram**, con reconocimiento de intención y redirección automática al trámite o página oficial correspondiente.
- 🔎 **Búsqueda textual por palabras clave con orden por relevancia**: acepta consultas en lenguaje natural («quisiera declarar mi información financiera», «entrega de DNI»), descarta muletillas y pondera cada palabra según su selectividad, sin exigir la frase exacta del catálogo.
- ♿ **Panel de accesibilidad** configurable con tres ajustes: tamaño de texto, contraste y cursor.
- 🗂️ Clasificación y filtrado de contenidos por **entidad** y por **tipo** (trámite, servicio, reporte, documento, guía).
- 📱 Versión **web responsiva**.

## 🎯 Objetivos

### Objetivo General
Diseñar y desarrollar un portal web que centralice el acceso a los trámites, servicios, documentos y guías de las principales entidades públicas peruanas, mediante un sistema de búsqueda por voz y un panel de configuraciones de accesibilidad.

### Objetivos Específicos
- Diseñar la arquitectura de información y el **modelo de base de datos en MySQL** para organizar, etiquetar y filtrar trámites según entidad y tipo.
- Integrar la **búsqueda por voz** (API de Deepgram) para transcribir consultas en lenguaje natural y redirigir al trámite correcto.
- Desarrollar una **API REST en Spring Boot** que exponga el catálogo clasificado y sirva de capa de integración entre frontend, base de datos y servicios externos.
- Validar el nivel de **conformidad de accesibilidad** del portal.

## 🚧 Problemática que resuelve

Cada entidad pública mantiene su propio portal, con distinta estructura de navegación, nomenclatura y madurez digital. Aun con plataformas centrales como **GOB.PE**, el ciudadano suele necesitar conocer de antemano el nombre exacto del trámite y la entidad responsable. Además, la búsqueda es eminentemente **textual**, lo que excluye a personas con dificultades de lectoescritura o limitaciones de teclado.

## 🛠️ Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Web responsiva (React) + panel de accesibilidad |
| Backend | API REST **Spring Boot** (contenerizada con **Docker**) |
| Base de datos | **MySQL** administrado en la nube (**Aiven**) |
| Búsqueda por voz | API **Deepgram** |
| Despliegue | **Docker Hub** + **Azure** (Container Apps + Static Web Apps) |

## 🧬 Modelo de Base de Datos

El script canónico se encuentra en **`bd/bd_tramites.sql`** (MySQL 8.x), catálogo consolidado con **275 trámites, 361 requisitos y 286 etiquetas**; el esquema y la semilla original quedan en `bd/portal_tramites.sql`. Incluye:

- **`entidad`** — entidades públicas (nombre, siglas, sector, descripción, `sitio_web` oficial, estado).
- **`tipo_contenido`** — catálogo: `TRAMITE`, `SERVICIO`, `REPORTE`, `DOCUMENTO`, `GUIA`.
- **`tramite`** — tabla de **detalle** con los **requisitos** (según documento oficial) y la **`url_oficial`** de la página del trámite, más modalidad, costo e índice FULLTEXT.
- **`etiqueta` / `tramite_etiqueta`** — etiquetado N:M para filtrado y búsqueda por voz.
- **`busqueda`** — bitácora de búsquedas textuales y por voz (transcripción, intención, redirección).
- **`preferencia_accesibilidad`** — perfiles del panel (tamaño de texto, contraste, cursor).

## ☁️ Arquitectura de Despliegue

El proyecto está desplegado de punta a punta en la nube:

| Componente | Servicio | Detalle |
|---|---|---|
| Backend | **Azure Container Apps** | Spring Boot, región `eastus2`, **siempre activo** (`min-replicas 1`), CPU 0.5 / 1 GiB |
| Imagen backend | **Docker Hub** | `thikeiw/portal-backend:1.0` (multi-etapa: Maven/Temurin 21 → JRE 21 alpine) |
| Frontend | **Azure Static Web Apps** (Free) | Vite + React, desplegado con **GitHub Actions** en cada push a `main`/`develop` |
| Base de datos | **Aiven MySQL** | Conexión cifrada (`sslMode=REQUIRED`) mediante variables de entorno |

```
Navegador ──HTTPS──▶ Azure Static Web Apps (frontend)
                          │  fetch (VITE_API_URL)
                          ▼
              Azure Container Apps (backend)
                  │  JDBC + TLS          │  HTTPS
                  ▼                      ▼
            Aiven MySQL             Deepgram (voz)
```

- **Backend:** https://ca-portal-backend.yellowpond-8e7d345d.eastus2.azurecontainerapps.io
- **Frontend:** https://happy-glacier-010251d0f.4.azurestaticapps.net
- **Recursos Azure:** grupo `rg-portal-tramites`, entorno `cae-portal-tramites`, app `ca-portal-backend`, SWA `swa-portal-frontend-tk`.

Configuración clave del backend (todas vía **variables de entorno**, nunca en el repositorio):

| Variable | Uso |
|---|---|
| `DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASSWORD` | Conexión a Aiven MySQL |
| `DB_SSL_PARAMS` | `sslMode=REQUIRED` (TLS hacia la BD) |
| `DEEPGRAM_API_KEY` | Transcripción de la búsqueda por voz |
| `CORS_ORIGINS` | Orígenes web permitidos, separados por coma (URL del frontend en Azure + `http://localhost:5173` para desarrollo) |
| `PORT` | Puerto del contenedor (por defecto 8080) |

> ⚠️ Tras cambiar `CORS_ORIGINS` hay que forzar una réplica nueva (ciclo de escala o reinicio); una `update` con el mismo valor no reemplaza la réplica que ya quedó con el CORS anterior. Verificar con `curl` y el header `Origin`.

## 🚀 Proceso de Despliegue

### Prerequisitos
- Docker Desktop, Azure CLI y GitHub CLI (`gh`) instalados y con sesión (`docker login`, `az login`, `gh auth login`).
- **Cuenta Azure for Students:** solo permite las regiones `eastus2`, `southcentralus`, `northcentralus`, `mexicocentral` y `chilecentral` (Central US queda bloqueado por la política `sys.regionrestriction`). Se usa **`eastus2`**.
- Provider registrado: `az provider register --namespace Microsoft.Web` (además de `Microsoft.App`, `Microsoft.OperationalInsights` e `Microsoft.Insights`).

### 1. Backend — imagen Docker
El `backend/Dockerfile` es **multi-etapa** (no lleva credenciales; las variables llegan en runtime):

```powershell
docker build -t thikeiw/portal-backend:1.0 backend/
docker push thikeiw/portal-backend:1.0
```

Prueba local del contenedor antes de subirlo (credenciales desde `backend/.env.local`, que no se versiona):

```powershell
docker run --rm -d -p 18081:8080 --env-file backend/.env.local `
  -e CORS_ORIGINS=http://localhost:5173 portal-backend:local
```

### 2. Backend — Azure Container Apps (script automatizado)

```powershell
az provider register --namespace Microsoft.Web
az group create -n rg-portal-tramites -l eastus2
az containerapp env create -n cae-portal-tramites -g rg-portal-tramites -l eastus2

# Despliegue + variables de entorno (lee backend/.env.local; nunca imprime secretos)
.\deploy\az-backend.ps1 -DockerUser thikeiw
```

El script crea la app con `--min-replicas 1 --max-replicas 1` (siempre activa, sin cold start), `--ingress external` en el puerto 8080 e inyecta todas las variables (`DB_*`, `DEEPGRAM_API_KEY`, `CORS_ORIGINS`).

Verificaciones útiles:

```powershell
curl.exe -s https://$fqdn/api/tipos
az containerapp logs show -n ca-portal-backend -g rg-portal-tramites --tail 100   # buscar el precargado del catálogo
curl.exe -s -D - -o NUL -H "Origin: https://happy-glacier-010251d0f.4.azurestaticapps.net" https://$fqdn/api/entidades
```

### 3. Frontend — Azure Static Web Apps + GitHub Actions

```powershell
az staticwebapp create -n swa-portal-frontend-tk -g rg-portal-tramites -l eastus2 --sku Free
az staticwebapp secrets list -n swa-portal-frontend-tk -g rg-portal-tramites --query properties.apiKey -o tsv
gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN --body $token
```

El workflow **`.github/workflows/static-web-apps-ci.yml`** (acción `Azure/static-web-apps-deploy@v1`) compila `frontend/` con `VITE_API_URL` apuntando al backend y publica `dist/`. Cada push a `main` o `develop` redespliega el frontend automáticamente.

### Lecciones del proceso
- Si `az` no se reconoce, anteponer `C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin` al `$env:PATH`.
- No recrear un resource group con `--no-wait` y desplegar de inmediato: esperar el borrado completo; validar el entorno con la imagen `mcr.microsoft.com/k8se/quickstart:latest` antes de usar la propia.
- `Select-Object -Last 1` puede ocultar el mensaje de error real de `az`; correr sin filtros al diagnosticar.
- Un 503 sin réplica suele ser `minReplicas` nulo (escalado a cero) o una revisión zombi: borrar la app y crearla limpia con todo en una sola operación.


## 📂 Estructura del Directorio

```
Portal-Tramites-Centralizados/
├── bd/
│   ├── bd_tramites.sql              # Catálogo consolidado (275 trámites) — canónico
│   └── portal_tramites.sql          # Esquema y semilla original
├── backend/                         # API REST (Spring Boot)
│   ├── Dockerfile                   # Imagen multi-etapa (Maven 21 → JRE 21 alpine)
│   ├── .dockerignore                # Excluye target/, .env*, cert/, logs
│   ├── .env                         # Molde de variables (local vs Aiven)
│   ├── .env.local                   # Credenciales reales — NO versionado
│   └── src/main/java/com/portaltramites/
│       ├── config/                  # SecurityConfig (CORS desde CORS_ORIGINS)
│       ├── controller/              # REST: trámites, entidades, tipos, voz
│       ├── model/                   # Entidades JPA + DTOs planos
│       ├── repository/              # Queries JPQL de proyección
│       └── service/                 # Catálogo en memoria, búsqueda, voz
├── frontend/                        # Web responsiva + accesibilidad (Vite + React)
│   └── src/pages/                   # Inicio, Resultados (paginación), Detalle
├── deploy/
│   └── az-backend.ps1               # Despliegue backend: RG + Container Apps + env vars
├── .github/workflows/
│   └── static-web-apps-ci.yml       # CI/CD del frontend a Azure Static Web Apps
└── README.md
```

> ℹ️ El documento de proyecto (`Avance1_Proy.docx`) se mantiene **fuera** del repositorio; su contenido se refleja en este README.

## 🌿 Flujo de Trabajo con Git (Ramas)

Se usan ramas por **responsabilidad** para evitar conflictos y mantener `main` estable.

```
main                          # 🟢 Producción / estable
└── develop                   # Integración de todas las features
    ├── feature/base-datos    # Esquema MySQL (bd/)
    ├── feature/backend       # API REST Spring Boot (backend/)
    ├── feature/frontend      # UI responsiva + accesibilidad (frontend/)
    └── feature/busqueda-voz  # Integración Deepgram (voz)
```

**Convención:**
- Cada rama toca **solo sus archivos** (evita colisiones).
- `develop` integra las features.
- `main` solo recibe `develop` tras validación.
- Para requerimientos de accesibilidad u otras funcionalidades, usar `feature/` dedicadas.

## 📝 Registro de cambios

### 2026-11 — Despliegue en Azure
- **Backend contenerizado y en la nube**: `backend/Dockerfile` multi-etapa (build con Maven/Temurin 21, runtime JRE 21 alpine) publicado en **Docker Hub** (`thikeiw/portal-backend:1.0`) y desplegado en **Azure Container Apps** (región `eastus2`, **siempre activo** con `min-replicas 1`, HTTPS público). Script reutilizable `deploy/az-backend.ps1`, que inyecta las credenciales desde `backend/.env.local` sin imprimirlas.
- **Frontend en Azure Static Web Apps**: workflow **`static-web-apps-ci.yml`** (acción `Azure/static-web-apps-deploy@v1`) integra CI/CD: cada push a `main`/`develop` compila el frontend con `VITE_API_URL` apuntando al backend y lo publica.
- **Backend preparado para despliegue**: puerto configurable (`server.port=${PORT:8080}`) y **CORS por variable** (`CORS_ORIGINS` separado por comas; por defecto `http://localhost:5173`), de modo que el mismo binario sirve a local y a Azure solo cambiando variables de entorno.
- **BD remota (Aiven MySQL)** con TLS (`sslMode=REQUIRED`); conexión 100 % vía variables de entorno.
- Aprendizajes documentados en «Lecciones del proceso»: política de regiones de Azure for Students, revisión zombi / réplica tras cambiar CORS, registro de providers, etc.

### 2026-11 — Búsqueda y voz
- **Búsqueda por relevancia** (backend + UI): el buscador ya no exige la frase exacta. Extrae palabras clave de la consulta en lenguaje natural, descarta muletillas («quisiera», «dónde», «quiero ver»…) y puntúa cada trámite por dónde coinciden (nombre > etiquetas > entidad > descripción), ponderando la **rareza de cada palabra** en el catálogo (IDF). Los resultados se muestran ordenados por relevancia en lugar de alfabéticamente.
- **Búsqueda por voz robusta**: captura de audio **PCM → WAV en el cliente** (Web Audio API), porque los streams `webm` de `MediaRecorder` eran rechazados por Deepgram como corruptos. Se añadió registro de diagnóstico en logs (primeros bytes del audio), mínimo de 1 s de grabación y mensaje claro ante errores de audio.
- **Catálogo consolidado** integrado en `develop`: 275 trámites, 361 requisitos y 286 etiquetas (`bd/bd_tramites.sql`).

## 👥 Entidades Públicas Incluidas

- **SUNAT** — https://www.sunat.gob.pe
- **MINEDU** — https://www.gob.pe/minedu
- **RENIEC** — https://www.gob.pe/reniec
- **ESSALUD** — https://www.essalud.gob.pe
- **SUNARP** — https://www.gob.pe/sunarp
- **MIGRACIONES** — https://www.gob.pe/migraciones

*(Las fuentes para el contenido de trámites y sus requisitos provienen de los portales oficiales de cada entidad.)*