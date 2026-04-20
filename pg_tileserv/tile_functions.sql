-- Funciones SQL para tiles vectoriales via pg_tileserv
-- Capas: lmt, setas, barrios
-- Simplificación Douglas-Peucker (ST_Simplify) con tolerancia variable por zoom level
-- Requerimientos: 9.2, 9.6

-- ─────────────────────────────────────────────────────────────────────────────
-- Función auxiliar: tolerancia de simplificación según zoom
-- Mayor tolerancia en zoom bajo (vista general), menor en zoom alto (detalle)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.simplify_tolerance(z integer)
RETURNS float AS $$
BEGIN
  RETURN CASE
    WHEN z <= 8  THEN 0.01
    WHEN z <= 10 THEN 0.005
    WHEN z <= 12 THEN 0.001
    WHEN z <= 14 THEN 0.0005
    ELSE              0.0001
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Capa LMT (Líneas de Media Tensión)
-- Geometría: LINESTRING — simplificada con Douglas-Peucker por zoom
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.lmt_tiles(z integer, x integer, y integer)
RETURNS bytea AS $$
DECLARE
  tolerance float;
  bounds    geometry;
  mvt       bytea;
BEGIN
  tolerance := public.simplify_tolerance(z);
  bounds    := ST_TileEnvelope(z, x, y);

  SELECT ST_AsMVT(q, 'lmt', 4096, 'geom') INTO mvt
  FROM (
    SELECT
      id,
      nombre,
      nivel_tension,
      ST_AsMVTGeom(
        ST_Simplify(geometria, tolerance),
        bounds, 4096, 64, true
      ) AS geom
    FROM lmt
    WHERE geometria && bounds
      AND ST_Simplify(geometria, tolerance) IS NOT NULL
  ) q;

  RETURN COALESCE(mvt, ''::bytea);
END;
$$ LANGUAGE plpgsql STABLE PARALLEL SAFE;

COMMENT ON FUNCTION public.lmt_tiles(integer, integer, integer) IS
  'Tiles MVT para Líneas de Media Tensión con simplificación Douglas-Peucker variable por zoom. Requerimientos 9.2, 9.6.';

-- ─────────────────────────────────────────────────────────────────────────────
-- Capa Setas (Centros de transformación)
-- Geometría: POINT — sin simplificación (puntos no se simplifican)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.setas_tiles(z integer, x integer, y integer)
RETURNS bytea AS $$
DECLARE
  bounds geometry;
  mvt    bytea;
BEGIN
  bounds := ST_TileEnvelope(z, x, y);

  SELECT ST_AsMVT(q, 'setas', 4096, 'geom') INTO mvt
  FROM (
    SELECT
      id,
      nombre,
      tipo,
      lmt_id,
      ST_AsMVTGeom(
        geometria,
        bounds, 4096, 64, true
      ) AS geom
    FROM setas
    WHERE geometria && bounds
  ) q;

  RETURN COALESCE(mvt, ''::bytea);
END;
$$ LANGUAGE plpgsql STABLE PARALLEL SAFE;

COMMENT ON FUNCTION public.setas_tiles(integer, integer, integer) IS
  'Tiles MVT para Setas (centros de transformación). Requerimientos 9.2, 9.6.';

-- ─────────────────────────────────────────────────────────────────────────────
-- Capa Barrios
-- Geometría: POLYGON — simplificada con Douglas-Peucker por zoom
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.barrios_tiles(z integer, x integer, y integer)
RETURNS bytea AS $$
DECLARE
  tolerance float;
  bounds    geometry;
  mvt       bytea;
BEGIN
  tolerance := public.simplify_tolerance(z);
  bounds    := ST_TileEnvelope(z, x, y);

  SELECT ST_AsMVT(q, 'barrios', 4096, 'geom') INTO mvt
  FROM (
    SELECT
      id,
      nombre,
      ST_AsMVTGeom(
        ST_Simplify(geometria, tolerance),
        bounds, 4096, 64, true
      ) AS geom
    FROM barrios
    WHERE geometria && bounds
      AND ST_Simplify(geometria, tolerance) IS NOT NULL
  ) q;

  RETURN COALESCE(mvt, ''::bytea);
END;
$$ LANGUAGE plpgsql STABLE PARALLEL SAFE;

COMMENT ON FUNCTION public.barrios_tiles(integer, integer, integer) IS
  'Tiles MVT para Barrios con simplificación Douglas-Peucker variable por zoom. Requerimientos 9.2, 9.6.';
