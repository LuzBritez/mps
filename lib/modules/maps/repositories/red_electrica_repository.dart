import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/models.dart';
import '../services/api_client.dart';

/// Repositorio de lectura de la red eléctrica desde PostgREST (Docker).
/// Requerimientos: 1.4, 1.5, 1.6, 5.2
class RedElectricaRepository {
  final ApiClient _client;

  List<LMT>? _lmtsCache;
  List<Seta>? _setasCache;
  List<Barrio>? _barriosCache;
  final Map<int, List<Nodo>> _nodosCache = {};

  RedElectricaRepository({ApiClient? client}) : _client = client ?? apiClient;

  Future<List<LMT>> getLMTs() async {
    if (_lmtsCache != null) return _lmtsCache!;
    final rows = await _client.select('lmt',
        filters: {'select': 'id,nombre,nivel_tension,geometria,metadatos'});
    _lmtsCache = rows.map<LMT>((row) => LMT(
          id: (row['id'] as num).toInt(),
          nombre: row['nombre'] as String,
          nivelTension: row['nivel_tension'] as String,
          coordenadas: _parseLineString(row['geometria'] as String),
          metadatos: (row['metadatos'] as Map<String, dynamic>?) ?? {},
        )).toList();
    return _lmtsCache!;
  }

  Future<List<Seta>> getSetas() async {
    if (_setasCache != null) return _setasCache!;
    final rows = await _client
        .select('setas', filters: {'select': 'id,nombre,tipo,geometria'});
    _setasCache = rows.map<Seta>((row) => Seta(
          id: (row['id'] as num).toInt(),
          nombre: row['nombre'] as String,
          tipo: row['tipo'] as String,
          coordenadas: _parsePoint(row['geometria'] as String),
        )).toList();
    return _setasCache!;
  }

  Future<List<Barrio>> getBarrios() async {
    if (_barriosCache != null) return _barriosCache!;
    final rows = await _client
        .select('barrios', filters: {'select': 'id,nombre,geometria'});
    _barriosCache = rows.map<Barrio>((row) => Barrio(
          id: (row['id'] as num).toInt(),
          nombre: row['nombre'] as String,
          poligono: _parsePolygon(row['geometria'] as String),
        )).toList();
    return _barriosCache!;
  }

  Future<List<Nodo>> getNodosByLmtId(int lmtId) async {
    if (_nodosCache.containsKey(lmtId)) return _nodosCache[lmtId]!;
    final rows = await _client.select('nodos', filters: {
      'select': 'id,nombre,lmt_id,geometria,orden',
      'lmt_id': 'eq.$lmtId',
      'order': 'orden.asc',
    });
    final nodos = rows.map<Nodo>((row) => Nodo(
          id: (row['id'] as num).toInt(),
          nombre: row['nombre'] as String,
          lmtId: (row['lmt_id'] as num).toInt(),
          coordenadas: _parsePoint(row['geometria'] as String),
          orden: (row['orden'] as num).toInt(),
        )).toList();
    _nodosCache[lmtId] = nodos;
    return nodos;
  }

  void invalidarCache() {
    _lmtsCache = null;
    _setasCache = null;
    _barriosCache = null;
    _nodosCache.clear();
  }

  LatLng _parsePoint(String wkt) {
    final clean = wkt.replaceFirst(RegExp(r'POINT\s*\('), '').replaceAll(')', '').trim();
    final parts = clean.split(RegExp(r'\s+'));
    return LatLng(double.parse(parts[1]), double.parse(parts[0]));
  }

  List<LatLng> _parseLineString(String wkt) {
    final inner = wkt.replaceFirst(RegExp(r'LINESTRING\s*\('), '').replaceAll(')', '').trim();
    return _parsePairList(inner);
  }

  List<LatLng> _parsePolygon(String wkt) {
    final match = RegExp(r'POLYGON\s*\(\(([^)]+)\)').firstMatch(wkt);
    if (match == null) return [];
    return _parsePairList(match.group(1)!);
  }

  List<LatLng> _parsePairList(String pairs) {
    return pairs.split(',').map((pair) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      return LatLng(double.parse(parts[1]), double.parse(parts[0]));
    }).toList();
  }
}
