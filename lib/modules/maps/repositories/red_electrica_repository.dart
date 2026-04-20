import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Repositorio de lectura de la red eléctrica desde Supabase.
///
/// Implementa caché en memoria para soportar modo offline (Req. 2.4, 7.5):
/// una vez cargados los datos, permanecen disponibles aunque se pierda
/// la conectividad.
///
/// Las geometrías se almacenan en PostGIS como WKT (Well-Known Text).
/// Este repositorio las parsea a [LatLng] para uso con MapLibre GL.
///
/// Requerimientos: 1.4, 1.5, 1.6, 5.2
class RedElectricaRepository {
  final SupabaseClient _client;

  // ── Caché en memoria ──────────────────────────────────────────────────────
  List<LMT>? _lmtsCache;
  List<Seta>? _setasCache;
  List<Barrio>? _barriosCache;

  /// Mapa de nodos por lmtId para evitar consultas repetidas.
  final Map<int, List<Nodo>> _nodosCache = {};

  RedElectricaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── LMTs ──────────────────────────────────────────────────────────────────

  /// Devuelve todas las LMT. Usa caché en memoria si ya fueron cargadas.
  ///
  /// Las geometrías vienen de PostGIS como WKT LINESTRING, p.ej.:
  /// `LINESTRING(-59.98 -24.89, -59.97 -24.88)`
  Future<List<LMT>> getLMTs() async {
    if (_lmtsCache != null) return _lmtsCache!;

    final rows = await _client
        .from('lmt')
        .select('id, nombre, nivel_tension, geometria, metadatos');

    _lmtsCache = rows.map<LMT>((row) {
      return LMT(
        id: (row['id'] as num).toInt(),
        nombre: row['nombre'] as String,
        nivelTension: row['nivel_tension'] as String,
        coordenadas: _parseLineString(row['geometria'] as String),
        metadatos: (row['metadatos'] as Map<String, dynamic>?) ?? {},
      );
    }).toList();

    return _lmtsCache!;
  }

  // ── Setas ─────────────────────────────────────────────────────────────────

  /// Devuelve todas las Setas. Usa caché en memoria si ya fueron cargadas.
  ///
  /// Las geometrías vienen de PostGIS como WKT POINT, p.ej.:
  /// `POINT(-59.98 -24.89)`
  Future<List<Seta>> getSetas() async {
    if (_setasCache != null) return _setasCache!;

    final rows = await _client
        .from('setas')
        .select('id, nombre, tipo, geometria');

    _setasCache = rows.map<Seta>((row) {
      return Seta(
        id: (row['id'] as num).toInt(),
        nombre: row['nombre'] as String,
        tipo: row['tipo'] as String,
        coordenadas: _parsePoint(row['geometria'] as String),
      );
    }).toList();

    return _setasCache!;
  }

  // ── Barrios ───────────────────────────────────────────────────────────────

  /// Devuelve todos los Barrios. Usa caché en memoria si ya fueron cargados.
  ///
  /// Las geometrías vienen de PostGIS como WKT POLYGON, p.ej.:
  /// `POLYGON((-59.98 -24.89, -59.97 -24.89, -59.97 -24.88, -59.98 -24.89))`
  Future<List<Barrio>> getBarrios() async {
    if (_barriosCache != null) return _barriosCache!;

    final rows = await _client
        .from('barrios')
        .select('id, nombre, geometria');

    _barriosCache = rows.map<Barrio>((row) {
      return Barrio(
        id: (row['id'] as num).toInt(),
        nombre: row['nombre'] as String,
        poligono: _parsePolygon(row['geometria'] as String),
      );
    }).toList();

    return _barriosCache!;
  }

  // ── Nodos ─────────────────────────────────────────────────────────────────

  /// Devuelve los nodos de una LMT específica, ordenados por [Nodo.orden].
  /// Usa caché en memoria por lmtId.
  ///
  /// Las geometrías vienen de PostGIS como WKT POINT.
  Future<List<Nodo>> getNodosByLmtId(int lmtId) async {
    if (_nodosCache.containsKey(lmtId)) return _nodosCache[lmtId]!;

    final rows = await _client
        .from('nodos')
        .select('id, nombre, lmt_id, geometria, orden')
        .eq('lmt_id', lmtId)
        .order('orden');

    final nodos = rows.map<Nodo>((row) {
      return Nodo(
        id: (row['id'] as num).toInt(),
        nombre: row['nombre'] as String,
        lmtId: (row['lmt_id'] as num).toInt(),
        coordenadas: _parsePoint(row['geometria'] as String),
        orden: (row['orden'] as num).toInt(),
      );
    }).toList();

    _nodosCache[lmtId] = nodos;
    return nodos;
  }

  // ── Invalidación de caché ─────────────────────────────────────────────────

  /// Limpia toda la caché en memoria, forzando recarga desde Supabase
  /// en la próxima llamada.
  void invalidarCache() {
    _lmtsCache = null;
    _setasCache = null;
    _barriosCache = null;
    _nodosCache.clear();
  }

  // ── Parsers WKT → LatLng ──────────────────────────────────────────────────

  /// Parsea un WKT POINT a [LatLng].
  /// Formato esperado: `POINT(lng lat)` o `POINT (lng lat)`
  LatLng _parsePoint(String wkt) {
    final clean = wkt.replaceFirst(RegExp(r'POINT\s*\('), '').replaceAll(')', '').trim();
    final parts = clean.trim().split(RegExp(r'\s+'));
    final lng = double.parse(parts[0]);
    final lat = double.parse(parts[1]);
    return LatLng(lat, lng);
  }

  /// Parsea un WKT LINESTRING a lista de [LatLng].
  /// Formato esperado: `LINESTRING(lng1 lat1, lng2 lat2, ...)`
  List<LatLng> _parseLineString(String wkt) {
    final inner = wkt
        .replaceFirst(RegExp(r'LINESTRING\s*\('), '')
        .replaceAll(')', '')
        .trim();
    return _parsePairList(inner);
  }

  /// Parsea un WKT POLYGON al anillo exterior como lista de [LatLng].
  /// Formato esperado: `POLYGON((lng1 lat1, lng2 lat2, ...))`
  List<LatLng> _parsePolygon(String wkt) {
    // Extrae el primer anillo (exterior) ignorando huecos.
    final match = RegExp(r'POLYGON\s*\(\(([^)]+)\)').firstMatch(wkt);
    if (match == null) return [];
    return _parsePairList(match.group(1)!);
  }

  /// Convierte una cadena de pares `lng lat` separados por comas a [LatLng].
  List<LatLng> _parsePairList(String pairs) {
    return pairs.split(',').map((pair) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      final lng = double.parse(parts[0]);
      final lat = double.parse(parts[1]);
      return LatLng(lat, lng);
    }).toList();
  }
}
