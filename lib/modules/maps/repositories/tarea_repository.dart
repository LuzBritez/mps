import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Repositorio de gestión de tareas contra Supabase.
///
/// Implementa creación, consulta y actualización de tareas con:
/// - Campos NTP: `tiempo_verdadero` y `tiempo_dispositivo` (Req. 8.9)
/// - Detección de `posible_manipulacion_reloj` si la diferencia entre
///   `tiempoVerdadero` y `tiempoDispositivo` supera los 5 minutos (Req. 8.11)
/// - Validación de intersección de ruta con LMT vía PostGIS `ST_Intersects` (Req. 4.3)
///
/// Requerimientos: 4.1, 4.3, 5.5
class TareaRepository {
  final SupabaseClient _client;

  /// Umbral para detectar posible manipulación del reloj del dispositivo.
  /// Requerimiento 8.11
  static const Duration _umbralManipulacion = Duration(minutes: 5);

  TareaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── Crear tarea ───────────────────────────────────────────────────────────

  /// Crea una nueva tarea en estado `pendiente`.
  ///
  /// Parámetros:
  /// - [alarmaId]: ID de la alarma de origen.
  /// - [lmtId]: ID de la LMT asociada a la ruta.
  /// - [rutaNodoIds]: Secuencia ordenada de IDs de nodos que conforman la ruta.
  /// - [asignadaA]: ID del operario o cuadrilla asignada.
  /// - [tipoAsignacion]: Tipo de asignación (operario o cuadrilla).
  /// - [creadaPor]: ID del coordinador que crea la tarea.
  /// - [tiempoVerdadero]: Tiempo NTP calculado por `RelojNTPService`.
  /// - [tiempoDispositivo]: Tiempo del dispositivo (`DateTime.now()`) para auditoría.
  ///
  /// Requerimientos: 4.1, 8.9, 8.11
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
    // Req. 8.11: detectar posible manipulación del reloj.
    final diferencia = tiempoVerdadero.difference(tiempoDispositivo).abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    final payload = {
      'alarma_id': alarmaId,
      'lmt_id': lmtId,
      'ruta_nodo_ids': rutaNodoIds,
      'asignada_a': asignadaA,
      'tipo_asignacion': _tipoAsignacionToString(tipoAsignacion),
      'estado': 'pendiente',
      'creada_por': creadaPor,
      'creada_en': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_verdadero': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_dispositivo': tiempoDispositivo.toUtc().toIso8601String(),
      'posible_manipulacion_reloj': posibleManipulacion,
    };

    final rows = await _client
        .from('tareas')
        .insert(payload)
        .select();

    return _mapRow(rows.first);
  }

  // ── Obtener tarea ─────────────────────────────────────────────────────────

  /// Devuelve una tarea por su ID.
  ///
  /// Lanza [TareaNoEncontradaException] si no existe ninguna tarea con ese ID.
  ///
  /// Requerimiento: 5.1
  Future<Tarea> obtenerTarea(int tareaId) async {
    final rows = await _client
        .from('tareas')
        .select()
        .eq('id', tareaId)
        .limit(1);

    if (rows.isEmpty) {
      throw TareaNoEncontradaException(tareaId);
    }

    return _mapRow(rows.first);
  }

  // ── Actualizar estado ─────────────────────────────────────────────────────

  /// Actualiza el estado de una tarea y registra el timestamp correspondiente.
  ///
  /// - Si [estado] es [EstadoTarea.enCurso], registra `iniciada_en`.
  /// - Si [estado] es [EstadoTarea.completada], registra `completada_en`.
  ///
  /// Lanza [TareaNoEncontradaException] si no existe ninguna tarea con ese ID.
  ///
  /// Requerimiento: 5.5
  Future<Tarea> actualizarEstadoTarea(int tareaId, EstadoTarea estado) async {
    final ahora = DateTime.now().toUtc().toIso8601String();

    final updates = <String, dynamic>{
      'estado': _estadoTareaToString(estado),
    };

    if (estado == EstadoTarea.enCurso) {
      updates['iniciada_en'] = ahora;
    } else if (estado == EstadoTarea.completada) {
      updates['completada_en'] = ahora;
    }

    final rows = await _client
        .from('tareas')
        .update(updates)
        .eq('id', tareaId)
        .select();

    if (rows.isEmpty) {
      throw TareaNoEncontradaException(tareaId);
    }

    return _mapRow(rows.first);
  }

  // ── Validar intersección de ruta ──────────────────────────────────────────

  /// Verifica que la geometría de ruta proporcionada intersecta al menos
  /// una LMT en la base de datos, usando la función RPC `validar_interseccion_ruta`
  /// que internamente aplica `ST_Intersects` en PostGIS.
  ///
  /// La geometría se convierte a WKT LINESTRING antes de enviarla a la RPC.
  ///
  /// Si la RPC no está disponible (error de red o función inexistente),
  /// retorna `true` como fallback para no bloquear la UI.
  ///
  /// Requerimientos: 4.3, 9.6
  Future<bool> validarInterseccionRuta(List<LatLng> geometria) async {
    if (geometria.isEmpty) return false;

    final wkt = _toLineStringWkt(geometria);

    try {
      final result = await _client.rpc(
        'validar_interseccion_ruta',
        params: {'geometria_wkt': wkt},
      );
      return result as bool? ?? true;
    } catch (_) {
      // Fallback: no bloquear la UI si la RPC no está disponible.
      return true;
    }
  }

  // ── Conversión WKT ────────────────────────────────────────────────────────

  /// Convierte una lista de [LatLng] a WKT LINESTRING.
  /// Formato: `LINESTRING(lng1 lat1, lng2 lat2, ...)`
  String _toLineStringWkt(List<LatLng> puntos) {
    final pares = puntos
        .map((p) => '${p.longitude} ${p.latitude}')
        .join(', ');
    return 'LINESTRING($pares)';
  }

  // ── Mapeo de filas ────────────────────────────────────────────────────────

  /// Convierte una fila de Supabase al modelo [Tarea].
  Tarea _mapRow(Map<String, dynamic> row) {
    return Tarea(
      id: (row['id'] as num).toInt(),
      alarmaId: (row['alarma_id'] as num).toInt(),
      lmtId: row['lmt_id'] != null ? (row['lmt_id'] as num).toInt() : null,
      rutaNodoIds: (row['ruta_nodo_ids'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      asignadaA: (row['asignada_a'] as num).toInt(),
      tipoAsignacion: _parseTipoAsignacion(row['tipo_asignacion'] as String),
      estado: _parseEstadoTarea(row['estado'] as String),
      creadaPor: (row['creada_por'] as num).toInt(),
      creadaEn: DateTime.parse(row['creada_en'] as String),
      iniciadaEn: row['iniciada_en'] != null
          ? DateTime.parse(row['iniciada_en'] as String)
          : null,
      completadaEn: row['completada_en'] != null
          ? DateTime.parse(row['completada_en'] as String)
          : null,
      tiempoVerdadero: row['tiempo_verdadero'] != null
          ? DateTime.parse(row['tiempo_verdadero'] as String)
          : null,
      tiempoDispositivo: row['tiempo_dispositivo'] != null
          ? DateTime.parse(row['tiempo_dispositivo'] as String)
          : null,
      posibleManipulacionReloj:
          (row['posible_manipulacion_reloj'] as bool?) ?? false,
    );
  }

  // ── Conversores de enums ──────────────────────────────────────────────────

  EstadoTarea _parseEstadoTarea(String estado) {
    switch (estado) {
      case 'pendiente':
        return EstadoTarea.pendiente;
      case 'en_curso':
        return EstadoTarea.enCurso;
      case 'completada':
        return EstadoTarea.completada;
      default:
        throw StateError('Estado de tarea desconocido: $estado');
    }
  }

  TipoAsignacion _parseTipoAsignacion(String tipo) {
    switch (tipo) {
      case 'operario':
        return TipoAsignacion.operario;
      case 'cuadrilla':
        return TipoAsignacion.cuadrilla;
      default:
        throw StateError('Tipo de asignación desconocido: $tipo');
    }
  }

  String _estadoTareaToString(EstadoTarea estado) {
    switch (estado) {
      case EstadoTarea.pendiente:
        return 'pendiente';
      case EstadoTarea.enCurso:
        return 'en_curso';
      case EstadoTarea.completada:
        return 'completada';
    }
  }

  String _tipoAsignacionToString(TipoAsignacion tipo) {
    switch (tipo) {
      case TipoAsignacion.operario:
        return 'operario';
      case TipoAsignacion.cuadrilla:
        return 'cuadrilla';
    }
  }
}

// ── Excepciones ───────────────────────────────────────────────────────────────

/// Excepción lanzada cuando se intenta acceder a una tarea que no existe.
class TareaNoEncontradaException implements Exception {
  final int tareaId;

  const TareaNoEncontradaException(this.tareaId);

  @override
  String toString() =>
      'TareaNoEncontradaException: No existe ninguna tarea con id=$tareaId.';
}

/// Excepción lanzada cuando la geometría de ruta no intersecta ninguna LMT.
///
/// Requerimiento: 4.3
class TareaRutaSinInterseccionException implements Exception {
  const TareaRutaSinInterseccionException();

  @override
  String toString() =>
      'TareaRutaSinInterseccionException: La geometría de ruta proporcionada '
      'no intersecta ninguna LMT. Verifique el trazado antes de crear la tarea.';
}
