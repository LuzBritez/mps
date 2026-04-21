-- Esquema completo: Trazabilidad Eléctrica de Campo — Formosa, Argentina

CREATE EXTENSION IF NOT EXISTS postgis;

-- ── distribuidores ────────────────────────────────────────────────────────
CREATE TABLE distribuidores (
  id          BIGSERIAL PRIMARY KEY,
  nombre      TEXT NOT NULL,
  estacion_id BIGINT
);

-- ── lmt (Líneas de Media Tensión) ─────────────────────────────────────────
CREATE TABLE lmt (
  id              BIGSERIAL PRIMARY KEY,
  nombre          TEXT NOT NULL,
  nivel_tension   TEXT NOT NULL,
  distribuidor_id BIGINT REFERENCES distribuidores(id),
  geometria       GEOMETRY(LINESTRING, 4326) NOT NULL,
  metadatos       JSONB DEFAULT '{}'
);
CREATE INDEX lmt_geometria_idx ON lmt USING GIST(geometria);

-- ── setas ─────────────────────────────────────────────────────────────────
CREATE TABLE setas (
  id        BIGSERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL,
  tipo      TEXT NOT NULL,
  lmt_id    BIGINT REFERENCES lmt(id),
  geometria GEOMETRY(POINT, 4326) NOT NULL,
  metadatos JSONB DEFAULT '{}'
);
CREATE INDEX setas_geometria_idx ON setas USING GIST(geometria);

-- ── barrios ───────────────────────────────────────────────────────────────
CREATE TABLE barrios (
  id        BIGSERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL,
  geometria GEOMETRY(POLYGON, 4326) NOT NULL
);
CREATE INDEX barrios_geometria_idx ON barrios USING GIST(geometria);

-- ── nodos ─────────────────────────────────────────────────────────────────
CREATE TABLE nodos (
  id        BIGSERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL,
  lmt_id    BIGINT REFERENCES lmt(id),
  geometria GEOMETRY(POINT, 4326) NOT NULL,
  orden     INTEGER NOT NULL
);
CREATE INDEX nodos_geometria_idx ON nodos USING GIST(geometria);

-- ── alarmas ───────────────────────────────────────────────────────────────
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

-- ── tareas ────────────────────────────────────────────────────────────────
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

-- ── progreso_nodos ────────────────────────────────────────────────────────
CREATE TABLE progreso_nodos (
  tarea_id           BIGINT NOT NULL REFERENCES tareas(id),
  nodo_id            BIGINT NOT NULL REFERENCES nodos(id),
  inspeccionado      BOOLEAN NOT NULL DEFAULT FALSE,
  inspeccionado_en   TIMESTAMPTZ,
  tiempo_verdadero   TIMESTAMPTZ,
  tiempo_dispositivo TIMESTAMPTZ,
  PRIMARY KEY (tarea_id, nodo_id)
);

-- ── incidencias ───────────────────────────────────────────────────────────
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
