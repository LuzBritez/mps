-- Migración inicial: esquema completo del módulo Maps
-- Trazabilidad Eléctrica de Campo — Formosa, Argentina
-- Requerimientos: 3.1, 4.1, 5.3, 6.4, 7.1, 8.6–8.9

-- Extensión PostGIS (debe estar habilitada en Supabase)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ─────────────────────────────────────────────
-- distribuidores
-- ─────────────────────────────────────────────
CREATE TABLE distribuidores (
  id          BIGSERIAL PRIMARY KEY,
  nombre      TEXT NOT NULL,
  estacion_id BIGINT
);

-- ─────────────────────────────────────────────
-- lmt (Líneas de Media Tensión)
-- ─────────────────────────────────────────────
CREATE TABLE lmt (
  id              BIGSERIAL PRIMARY KEY,
  nombre          TEXT NOT NULL,
  nivel_tension   TEXT NOT NULL,
  distribuidor_id BIGINT REFERENCES distribuidores(id),
  geometria       GEOMETRY(LINESTRING, 4326) NOT NULL,
  metadatos       JSONB DEFAULT '{}'
);

CREATE INDEX lmt_geometria_idx ON lmt USING GIST(geometria);

-- ─────────────────────────────────────────────
-- setas (Centros de transformación)
-- ─────────────────────────────────────────────
CREATE TABLE setas (
  id        BIGSERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL,
  tipo      TEXT NOT NULL,
  lmt_id    BIGINT REFERENCES lmt(id),
  geometria GEOMETRY(POINT, 4326) NOT NULL,
  metadatos JSONB DEFAULT '{}'
);

CREATE INDEX setas_geometria_idx ON setas USING GIST(geometria);

-- ─────────────────────────────────────────────
-- barrios
-- ─────────────────────────────────────────────
CREATE TABLE barrios (
  id        BIGSERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL,
  geometria GEOMETRY(POLYGON, 4326) NOT NULL
);

CREATE INDEX barrios_geometria_idx ON barrios USING GIST(geometria);

-- ─────────────────────────────────────────────
-- nodos (Puntos de inspección sobre LMT)
-- ─────────────────────────────────────────────
CREATE TABLE nodos (
  id        BIGSERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL,
  lmt_id    BIGINT REFERENCES lmt(id),
  geometria GEOMETRY(POINT, 4326) NOT NULL,
  orden     INTEGER NOT NULL
);

CREATE INDEX nodos_geometria_idx ON nodos USING GIST(geometria);

-- ─────────────────────────────────────────────
-- alarmas
-- Campos NTP: tiempo_verdadero, tiempo_dispositivo, posible_manipulacion_reloj
-- Requerimiento 8.8
-- ─────────────────────────────────────────────
CREATE TABLE alarmas (
  id                         BIGSERIAL PRIMARY KEY,
  lmt_id                     BIGINT REFERENCES lmt(id),
  zona_desc                  TEXT,
  estado                     TEXT NOT NULL DEFAULT 'activa',
  creada_por                 BIGINT NOT NULL,
  creada_en                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cerrada_en                 TIMESTAMPTZ,
  tiempo_verdadero           TIMESTAMPTZ,
  tiempo_dispositivo         TIMESTAMPTZ,
  posible_manipulacion_reloj BOOLEAN DEFAULT FALSE
);

-- ─────────────────────────────────────────────
-- tareas
-- Campos NTP: tiempo_verdadero, tiempo_dispositivo, posible_manipulacion_reloj
-- Requerimiento 8.9
-- ─────────────────────────────────────────────
CREATE TABLE tareas (
  id                         BIGSERIAL PRIMARY KEY,
  alarma_id                  BIGINT NOT NULL REFERENCES alarmas(id),
  lmt_id                     BIGINT REFERENCES lmt(id),
  ruta_nodo_ids              BIGINT[] NOT NULL,
  asignada_a                 BIGINT NOT NULL,
  tipo_asignacion            TEXT NOT NULL,
  estado                     TEXT NOT NULL DEFAULT 'pendiente',
  creada_por                 BIGINT NOT NULL,
  creada_en                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  iniciada_en                TIMESTAMPTZ,
  completada_en              TIMESTAMPTZ,
  tiempo_verdadero           TIMESTAMPTZ,
  tiempo_dispositivo         TIMESTAMPTZ,
  posible_manipulacion_reloj BOOLEAN DEFAULT FALSE
);

-- ─────────────────────────────────────────────
-- progreso_nodos
-- Campos NTP: tiempo_verdadero, tiempo_dispositivo
-- Requerimiento 8.7
-- ─────────────────────────────────────────────
CREATE TABLE progreso_nodos (
  tarea_id           BIGINT NOT NULL REFERENCES tareas(id),
  nodo_id            BIGINT NOT NULL REFERENCES nodos(id),
  inspeccionado      BOOLEAN NOT NULL DEFAULT FALSE,
  inspeccionado_en   TIMESTAMPTZ,
  tiempo_verdadero   TIMESTAMPTZ,
  tiempo_dispositivo TIMESTAMPTZ,
  PRIMARY KEY (tarea_id, nodo_id)
);

-- ─────────────────────────────────────────────
-- incidencias
-- Campos NTP: tiempo_verdadero NOT NULL, tiempo_dispositivo NOT NULL,
--             posible_manipulacion_reloj, tiempo_no_verificado
-- Requerimientos 6.4, 7.1, 8.6
-- ─────────────────────────────────────────────
CREATE TABLE incidencias (
  id                         BIGSERIAL PRIMARY KEY,
  tarea_id                   BIGINT NOT NULL REFERENCES tareas(id),
  operario_id                BIGINT NOT NULL,
  elemento_id                BIGINT NOT NULL,
  tipo_elemento              TEXT NOT NULL,
  categoria                  TEXT NOT NULL,
  descripcion                TEXT NOT NULL,
  coordenadas                GEOMETRY(POINT, 4326) NOT NULL,
  imagen_url                 TEXT,
  tiempo_verdadero           TIMESTAMPTZ NOT NULL,
  tiempo_dispositivo         TIMESTAMPTZ NOT NULL,
  posible_manipulacion_reloj BOOLEAN DEFAULT FALSE,
  tiempo_no_verificado       BOOLEAN DEFAULT FALSE,
  sincronizada               BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX incidencias_coordenadas_idx ON incidencias USING GIST(coordenadas);
