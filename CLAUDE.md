# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run app (Android emulator — API defaults to 10.0.2.2:3000)
flutter run -d ZY32LHM97M

# Run on physical device with custom backend URLs
flutter run --dart-define=API_URL=http://192.168.x.x:3000 \
            --dart-define=PG_TILESERV_URL=http://192.168.x.x:7800

# Lint / static analysis
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build release APK
flutter build apk

# Start backend (PostgreSQL + PostgREST + pg_tileserv)
cd docker && docker-compose up -d
```

Backend ports: PostgreSQL `5432`, PostgREST API `3000`, pg_tileserv `7800`.

## Architecture

**trazado_electrico** is an offline-first Flutter mobile app for field electrical network traceability in Formosa, Argentina. Two roles: **Coordinador** (dispatcher) and **Operario** (field worker).

### Layers

```
main.dart → MapsModule (DI root)
  ├── Views (full screens — coordinator-only: DespachoTareas, GestionAlarmas, MonitorCuadrillas)
  ├── Widgets (MapaInteractivo, NavegacionTarea, RegistroIncidencia, ControlCapas, CanvasEdicion)
  ├── Repositories (TareaRepository, AlarmaRepository, IncidenciaRepository, RedElectricaRepository)
  └── Services (ApiClient, RelojNTPService, ColaSincronizacionService, CapasStateService, MapaRenderService, ...)
```

All entry points flow through `MapsModule`, which performs constructor injection of all services and repositories.

### Key Services

| Service | Responsibility |
|---|---|
| `ApiClient` | PostgREST HTTP wrapper; all backend calls go here |
| `RelojNTPService` | Syncs with NTP pool; persists offset to SharedPreferences; flags clock manipulation if drift > 5 min |
| `ColaSincronizacionService` | Offline incident queue; exponential backoff sync (2 s → 4 s → 8 s, max 3 retries) on reconnect |
| `CapasStateService` | Map layer visibility state, persisted via SharedPreferences |
| `MapaRenderService` | Renders LMT, SETA, barrios, clusters on the MapLibre map |
| `TilesCacheService` | Caches vector tiles from pg_tileserv locally |
| `GeometriaService` | Distance and bounds calculations |

### Offline-First Incident Flow

1. Operario captures incident → form (`RegistroIncidenciaWidget`) → saved to SQLite (`incidencias_pendientes` table via `LocalDbSchema`)
2. `ColaSincronizacionService` listens for connectivity; on reconnect syncs all pending rows via `IncidenciaRepository` → `ApiClient`
3. Success: row deleted from SQLite; failure: retry with backoff; persistent failure: operator notified

### Time Validation

Every task/incident creation records three fields:
- `tiempoVerdadero` — NTP-derived timestamp
- `tiempoDispositivo` — `DateTime.now()`
- `posibleManipulacionReloj` — `true` if |verdadero − dispositivo| > 5 min

### Backend

Docker stack in `docker/`. PostgreSQL 16 + PostGIS 3.4, PostgREST v12, pg_tileserv. SQL init scripts in `docker/init/`. The `supabase/` directory is unused (replaced by PostgREST).

### Models

All data classes and enums are in `lib/modules/maps/models/` and re-exported via `models.dart`. Key enums: `EstadoTarea`, `EstadoAlarma`, `TipoElemento`, `UserRole`, `CategoriasIncidencia`. `UserContext` is injected from `main.dart`, not self-managed by the module.

### In-code requirement references

Source files reference numbered requirements (e.g. `// Req. 7.2`, `// Req. 8.1`). These correspond to the project's functional specification — preserve them when editing related logic.
