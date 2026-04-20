// Esquema SQLite local para el módulo Maps — modo offline
// Requerimientos: 7.1, 8.6

/// DDL para la tabla de incidencias pendientes de sincronización.
///
/// Campos NTP:
///   - [tiempo_verdadero]: ISO 8601 UTC calculado por RelojNTPService.
///   - [tiempo_dispositivo]: ISO 8601 UTC de DateTime.now() para auditoría.
///   - [posible_manipulacion_reloj]: 1 si |verdadero - dispositivo| > 5 min.
///   - [tiempo_no_verificado]: 1 si nunca hubo sincronización NTP en la sesión.
const String kCreateIncidenciasPendientes = '''
CREATE TABLE IF NOT EXISTS incidencias_pendientes (
  local_id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  tarea_id                   INTEGER NOT NULL,
  operario_id                INTEGER NOT NULL,
  elemento_id                INTEGER NOT NULL,
  tipo_elemento              TEXT NOT NULL,
  categoria                  TEXT NOT NULL,
  descripcion                TEXT NOT NULL,
  lat                        REAL NOT NULL,
  lng                        REAL NOT NULL,
  imagen_path                TEXT,
  tiempo_verdadero           TEXT NOT NULL,
  tiempo_dispositivo         TEXT NOT NULL,
  posible_manipulacion_reloj INTEGER NOT NULL DEFAULT 0,
  tiempo_no_verificado       INTEGER NOT NULL DEFAULT 0,
  intentos                   INTEGER NOT NULL DEFAULT 0
)
''';
