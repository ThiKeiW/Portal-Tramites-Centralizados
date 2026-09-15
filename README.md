# Portal Único de Trámites Peruanos 🏛️

Portal web que **centraliza el acceso** a trámites, servicios, reportes, documentos y guías de las principales **entidades públicas del Perú** (SUNAT, MINEDU, RENIEC, ESSALUD, entre otras). Permite al ciudadano ubicar y acceder a la información oficial sin conocer de antemano a qué entidad ni a qué sitio debería dirigirse, y está orientado a la **accesibilidad para personas con discapacidades visuales**.

> Curso: **Interacción Hombre Máquina** · Sección 32645 · Perú · 2026

---

## 📋 Descripción

La plataforma centraliza la **información (no la ejecución)** de trámites y servicios públicos. Incorpora:

- 🔍 **Búsqueda por voz** mediante la API de **Deepgram**, con reconocimiento de intención y redirección automática al trámite o página oficial correspondiente.
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
| Backend | API REST **Spring Boot** |
| Base de datos | **MySQL** |
| Búsqueda por voz | API **Deepgram** |

## 🧬 Modelo de Base de Datos

El script principal se encuentra en **`bd/portal_tramites.sql`** (MySQL 8.x). Incluye:

- **`entidad`** — entidades públicas (nombre, siglas, sector, descripción, `sitio_web` oficial, estado).
- **`tipo_contenido`** — catálogo: `TRAMITE`, `SERVICIO`, `REPORTE`, `DOCUMENTO`, `GUIA`.
- **`tramite`** — tabla de **detalle** con los **requisitos** (según documento oficial) y la **`url_oficial`** de la página del trámite, más modalidad, costo e índice FULLTEXT.
- **`etiqueta` / `tramite_etiqueta`** — etiquetado N:M para filtrado y búsqueda por voz.
- **`busqueda`** — bitácora de búsquedas textuales y por voz (transcripción, intención, redirección).
- **`preferencia_accesibilidad`** — perfiles del panel (tamaño de texto, contraste, cursor).

## 📂 Estructura del Directorio

```
Portal-Tramites-Centralizados/
├── bd/
│   └── portal_tramites.sql     # Esquema y datos iniciales de MySQL
├── backend/                    # API REST (Spring Boot) — rama feature/backend
├── frontend/                   # Web responsiva + accesibilidad — rama feature/frontend
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

## 👥 Entidades Públicas Incluidas

- **SUNAT** — https://www.sunat.gob.pe
- **MINEDU** — https://www.gob.pe/minedu
- **RENIEC** — https://www.gob.pe/reniec
- **ESSALUD** — https://www.essalud.gob.pe
- **SUNARP** — https://www.gob.pe/sunarp
- **MIGRACIONES** — https://www.gob.pe/migraciones

*(Las fuentes para el contenido de trámites y sus requisitos provienen de los portales oficiales de cada entidad.)*