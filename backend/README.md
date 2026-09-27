# Backend — Portal Único de Trámites

API REST en **Spring Boot 3.5** que expone el catálogo de trámites de
`portal_tramites_db` (MySQL, esquema gestionado por `bd/bd_tramites.sql`).

## Ejecutar

```bash
cd backend
mvn spring-boot:run
```

Requisitos: JDK 17+, MySQL 8 con `portal_tramites_db` cargada.

La contraseña de MySQL **no se commitea**: defínela como variable de entorno
(Windows: `set DB_PASSWORD=tu_clave`, PowerShell: `$env:DB_PASSWORD="tu_clave"`).
Opcionalmente `DB_USER` (por defecto `root`).

## Dependencias

- `spring-boot-starter-web` — API REST
- `spring-boot-starter-data-jpa` — acceso a datos
- `spring-boot-starter-security` — habilita **CORS solo para el frontend** (`http://localhost:5173`, servidor dev de Vite)
- `spring-boot-starter-validation` — validación de parámetros
- `mysql-connector-j` — driver MySQL
- `lombok` — reduce boilerplate

## Estructura

```
src/main/java/com/portaltramites/
├── PortalTramitesApplication.java   # arranque
├── model/       # Entidades JPA: Entidad, TipoContenido, Tramite, Requisito, Etiqueta, Modalidad
├── repository/  # Spring Data JPA (TramiteRepository incluye el query de relacionados)
├── service/     # Lógica de negocio (búsqueda con filtros, relacionados, etc.)
├── controller/  # Endpoints REST
├── config/      # SecurityConfig (CORS restringido al frontend)
└── error/       # Manejo de errores HTTP (400/401/403/404/409/500) en JSON
```

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/entidades` | Entidades activas |
| GET | `/api/entidades/{id}` | Entidad por id (404 si no existe) |
| GET | `/api/tipos` | Tipos de contenido (TRAMITE, SERVICIO, REPORTE, GUIA) |
| GET | `/api/tramites` | Búsqueda con filtros opcionales: `q`, `entidad` (siglas), `tipo`, `modalidad` |
| GET | `/api/tramites/{id}` | Detalle con requisitos y etiquetas |
| GET | `/api/tramites/{id}/requisitos` | Requisitos ordenados |
| GET | `/api/tramites/{id}/relacionados?limite=3` | **Documentos relacionados por etiquetas compartidas**, ordenados por cantidad en común |

Ejemplos:

```
GET /api/tramites?q=dni&entidad=RENIEC
GET /api/tramites?tipo=GUIA
GET /api/tramites/8/relacionados?limite=3
```

## Manejo de errores

Todas las respuestas de error usan el mismo JSON:

```json
{
  "timestamp": "2026-09-27T18:20:11",
  "status": 404,
  "error": "Not Found",
  "mensaje": "Trámite no encontrado con id: 999",
  "ruta": "/api/tramites/999"
}
```

400 (parámetros inválidos), 401/403 (seguridad), 404 (recurso no encontrado),
409 (integridad de datos) y 500 (inesperados, registrados en el log).
