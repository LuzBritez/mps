-- RPC functions exposed by PostgREST under /rpc/
-- Called by TareaRepository.validarInterseccionRuta() — Req. 4.3

-- Validates whether a given route geometry intersects any LMT in the network.
-- Returns TRUE if at least one LMT intersects the route, FALSE otherwise.
-- Input: WKT string in EPSG:4326 (e.g. 'LINESTRING(-59.98 -24.89,-59.97 -24.88)')
create or replace function validar_interseccion_ruta(ruta_geom text)
returns boolean
language sql
stable
as $$
  -- Parse WKT with explicit SRID 4326 to match lmt.geometria projection.
  -- ST_Intersects is preferred over other topology predicates for line/line relations.
  select exists (
    select from lmt
    where ST_Intersects(geometria, ST_GeomFromText(ruta_geom, 4326))
  );
$$;

-- Allow the anonymous PostgREST role to call this function.
grant execute on function validar_interseccion_ruta(text) to trazado_anon;

-- Rollback:
-- revoke execute on function validar_interseccion_ruta(text) from trazado_anon;
-- drop function if exists validar_interseccion_ruta(text);
