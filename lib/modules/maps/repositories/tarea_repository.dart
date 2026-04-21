import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/models.dart';
import '../services/api_client.dart';

/// Repositorio de tareas contra PostgREST (Docker).
/// Requerimientos: 4.1, 4.3, 5.5
class TareaRepository {
  final ApiClient _client;
  static const Duration _umbralManipulacion = Duration(minutes: 5);

  TareaRepository({ApiClient? client}) : _client = client ?? apiClient;

  Future<Tarea> crearTarea({
    required int alarmaId,
    required int lmtId,
    required List<int> rutaNodoIds,
    required int asignadaA,
    required TipoAsignacion tipoAsignacion,
    required int creadaPor,
    required DateTime tiempoVerdadero,
    required DateTime tiempoDispositivo,
  }) async {
    final diferencia = tiempoVerdadero.difference(tiempoDispositivo).abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    final row = await _client.insert('tareas', {
      'alarma_id': alarmaId,
      'lmt_id': lmtId,
      'ruta_nodo_ids': '{${rutaNodoIds.join(',')}}',
      'asignada_a': asignadaA,
      'tipo_asignacion': tipoAsignacion.name,
      'estado': 'pendiente',
      'creada_por': creadaPor,
      'creada_en': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_verdadero': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_dispositivo': tiempoDispositivo.toUtc().toIso8601String(),
      'posible_manipulacion_reloj': posibleManipulacion,
    });
    return _mapRow(row);
  }

  Future<Tarea> obtenerTarea(int tareaId) async {
    final rows = await _client.select('tareas', filters: {
      'id': 'eq.$tareaId',
      'limit': '1',
    });
    if (rows.isEmpty) throw TareaNoEncontradaException(tareaId);
    return _mapRow(rows.first);
  }

  Future<Tarea> actualizarEstadoTarea(int tareaId, EstadoTarea estado) async {
    final ahora = DateTime.now().toUtc().toIso8601String();
    final updates = <String, dynamic>{'estado': _estadoToString(estado)};
    if (estado == EstadoTarea.enCurso) updates['iniciada_en'] = ahora;
    if (estado == EstadoTarea.completada) updates['completada_en'] = ahora;

    final row = await _client.update('tareas', updates,
        filters: {'id': 'eq.$tareaId'});
    return _mapRow(row);
  }

  Future<bool> validarInterseccionRuta(List<LatLng> geometria) async {
    if (geometria.isEmpty) return false;
    final wkt = 'LINESTRING(${geometria.map((p) => '${p.longitude} ${p.latitude}').join(', ')})';
    try {
      final result = await _client.rpc('validar_interseccion_ruta',
          params: {'geometria_wkt': wkt});
      return result as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  Tarea _mapRow(Map<String, dynamic> row) {
    final rutaRaw = row['ruta_nodo_ids'];
    List<int> rutaNodoIds = [];
    if (rutaRaw is List) {
      rutaNodoIds = rutaRaw.map((e) => (e as num).toInt()).toList();
    } else if (rutaRaw is String) {
      rutaNodoIds = rutaRaw
          .replaceAll('{', '').replaceAll('}', '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toList();
    }

    return Tarea(
      id: (row['id'] as num).toInt(),
      alarmaId: (row['alarma_id'] as num).toInt(),
      lmtId: row['lmt_id'] != null ? (row['lmt_id'] as num).toInt() : null,
      rutaNodoIds: rutaNodoIds,
      asignadaA: (row['asignada_a'] as num).toInt(),
      tipoAsignacion: row['tipo_asignacion'] == 'cuadrilla'
          ? TipoAsignacion.cuadrilla
          : TipoAsignacion.operario,
      estado: _parseEstado(row['estado'] as String),
      creadaPor: (row['creada_por'] as num).toInt(),
      creadaEn: DateTime.parse(row['creada_en'] as String),
      iniciadaEn: row['iniciada_en'] != null ? DateTime.parse(row['iniciada_en'] as String) : null,
      completadaEn: row['completada_en'] != null ? DateTime.parse(row['completada_en'] as String) : null,
      tiempoVerdadero: row['tiempo_verdadero'] != null ? DateTime.parse(row['tiempo_verdadero'] as String) : null,
      tiempoDispositivo: row['tiempo_dispositivo'] != null ? DateTime.parse(row['tiempo_dispositivo'] as String) : null,
      posibleManipulacionReloj: (row['posible_manipulacion_reloj'] as bool?) ?? false,
    );
  }

  EstadoTarea _parseEstado(String s) {
    switch (s) {
      case 'en_curso': return EstadoTarea.enCurso;
      case 'completada': return EstadoTarea.completada;
      default: return EstadoTarea.pendiente;
    }
  }

  String _estadoToString(EstadoTarea e) {
    switch (e) {
      case EstadoTarea.enCurso: return 'en_curso';
      case EstadoTarea.completada: return 'completada';
      default: return 'pendiente';
    }
  }
}

class TareaNoEncontradaException implements Exception {
  final int tareaId;
  const TareaNoEncontradaException(this.tareaId);
  @override
  String toString() => 'TareaNoEncontradaException: No existe tarea con id=$tareaId.';
}

class TareaRutaSinInterseccionException implements Exception {
  const TareaRutaSinInterseccionException();
  @override
  String toString() => 'TareaRutaSinInterseccionException: La ruta no intersecta ninguna LMT.';
}
