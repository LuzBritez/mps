import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Repositorio de gestión de alarmas contra Supabase.
///
/// Implementa creación, cierre y listado de alarmas con:
/// - Validación de `lmtId` existente antes de persistir (Req. 3.2, 3.3)
/// - Campos NTP: `tiempo_verdadero` y `tiempo_dispositivo` (Req. 8.8)
/// - Detección de `posible_manipulacion_reloj` si la diferencia entre
///   `tiempoVerdadero` y `tiempoDispositivo` supera los 5 minutos (Req. 8.11)
/// - Ordenamiento descendente por `creada_en` en listado (Req. 3.5)
///
/// Requerimientos: 3.1–3.5, 8.8
class AlarmaRepository {
  final SupabaseClient _client;

  /// Umbral para detectar posible manipulación del reloj del dispositivo.
  static const Duration _umbralManipulacion = Duration(minutes: 5);

  AlarmaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── Crear alarma ──────────────────────────────────────────────────────────

  /// Crea una nueva alarma en estado `activa`.
  ///
  /// Parámetros:
  /// - [lmtId]: ID de la LMT afectada. Puede ser null si la alarma es por zona.
  /// - [zonaDesc]: Descripción textual de la zona afectada.
  /// - [creadaPor]: ID del coordinador que crea la alarma.
  /// - [tiempoVerdadero]: Tiempo NTP calculado por `RelojNTPService`.
  /// - [tiempoDispositivo]: Tiempo del dispositivo (`DateTime.now()`) para auditoría.
  ///
  /// Lanza [AlarmaLmtInexistenteException] si [lmtId] no existe en la tabla `lmt`.
  ///
  /// Requerimientos: 3.1, 3.2, 3.3, 8.8, 8.11
  Future<Alarma> crearAlarma({
    required int? lmtId,
    required String? zonaDesc,
    required int creadaPor,
    required DateTime tiempoVerdadero,
    required DateTime tiempoDispositivo,
  }) async {
    // Req. 3.2, 3.3: validar que lmtId exista antes de persistir.
    if (lmtId != null) {
      await _validarLmtExistente(lmtId);
    }

    // Req. 8.11: detectar posible manipulación del reloj.
    final diferencia = tiempoVerdadero.difference(tiempoDispositivo).abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    final payload = {
      if (lmtId != null) 'lmt_id': lmtId,
      if (zonaDesc != null) 'zona_desc': zonaDesc,
      'estado': 'activa',
      'creada_por': creadaPor,
      'creada_en': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_verdadero': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_dispositivo': tiempoDispositivo.toUtc().toIso8601String(),
      'posible_manipulacion_reloj': posibleManipulacion,
    };

    final rows = await _client
        .from('alarmas')
        .insert(payload)
        .select();

    return _mapRow(rows.first);
  }

  // ── Cerrar alarma ─────────────────────────────────────────────────────────

  /// Cierra una alarma existente actualizando su estado a `cerrada`.
  ///
  /// Parámetros:
  /// - [alarmaId]: ID de la alarma a cerrar.
  /// - [tiempoVerdadero]: Tiempo NTP calculado por `RelojNTPService`.
  /// - [tiempoDispositivo]: Tiempo del dispositivo (`DateTime.now()`) para auditoría.
  ///
  /// Lanza [AlarmaNoEncontradaException] si la alarma no existe.
  ///
  /// Requerimientos: 3.4, 8.8, 8.11
  Future<Alarma> cerrarAlarma({
    required int alarmaId,
    required DateTime tiempoVerdadero,
    required DateTime tiempoDispositivo,
  }) async {
    // Req. 8.11: detectar posible manipulación del reloj.
    final diferencia = tiempoVerdadero.difference(tiempoDispositivo).abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    final rows = await _client
        .from('alarmas')
        .update({
          'estado': 'cerrada',
          'cerrada_en': tiempoVerdadero.toUtc().toIso8601String(),
          'tiempo_verdadero': tiempoVerdadero.toUtc().toIso8601String(),
          'tiempo_dispositivo': tiempoDispositivo.toUtc().toIso8601String(),
          'posible_manipulacion_reloj': posibleManipulacion,
        })
        .eq('id', alarmaId)
        .select();

    if (rows.isEmpty) {
      throw AlarmaNoEncontradaException(alarmaId);
    }

    return _mapRow(rows.first);
  }

  // ── Listar alarmas activas ────────────────────────────────────────────────

  /// Devuelve todas las alarmas con estado `activa`, ordenadas por
  /// `creada_en` descendente (más reciente primero).
  ///
  /// Requerimiento: 3.5
  Future<List<Alarma>> listarAlarmasActivas() async {
    final rows = await _client
        .from('alarmas')
        .select()
        .eq('estado', 'activa')
        .order('creada_en', ascending: false);

    return rows.map<Alarma>(_mapRow).toList();
  }

  // ── Validación ────────────────────────────────────────────────────────────

  /// Verifica que el [lmtId] exista en la tabla `lmt`.
  ///
  /// Lanza [AlarmaLmtInexistenteException] si no se encuentra ningún registro.
  ///
  /// Requerimientos: 3.2, 3.3
  Future<void> _validarLmtExistente(int lmtId) async {
    final rows = await _client
        .from('lmt')
        .select('id')
        .eq('id', lmtId)
        .limit(1);

    if (rows.isEmpty) {
      throw AlarmaLmtInexistenteException(lmtId);
    }
  }

  // ── Mapeo de filas ────────────────────────────────────────────────────────

  /// Convierte una fila de Supabase al modelo [Alarma].
  Alarma _mapRow(Map<String, dynamic> row) {
    return Alarma(
      id: (row['id'] as num).toInt(),
      lmtId: row['lmt_id'] != null ? (row['lmt_id'] as num).toInt() : null,
      zonaDesc: row['zona_desc'] as String?,
      estado: _parseEstado(row['estado'] as String),
      creadaPor: (row['creada_por'] as num).toInt(),
      creadaEn: DateTime.parse(row['creada_en'] as String),
      cerradaEn: row['cerrada_en'] != null
          ? DateTime.parse(row['cerrada_en'] as String)
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

  /// Convierte el string de estado de la BD al enum [EstadoAlarma].
  EstadoAlarma _parseEstado(String estado) {
    switch (estado) {
      case 'activa':
        return EstadoAlarma.activa;
      case 'cerrada':
        return EstadoAlarma.cerrada;
      default:
        throw StateError('Estado de alarma desconocido: $estado');
    }
  }
}

// ── Excepciones ───────────────────────────────────────────────────────────────

/// Excepción lanzada cuando se intenta vincular una alarma a una LMT
/// que no existe en la base de datos.
///
/// Requerimiento: 3.3
class AlarmaLmtInexistenteException implements Exception {
  final int lmtId;

  const AlarmaLmtInexistenteException(this.lmtId);

  @override
  String toString() =>
      'AlarmaLmtInexistenteException: No existe ninguna LMT con id=$lmtId. '
      'Verifique el identificador antes de crear la alarma.';
}

/// Excepción lanzada cuando se intenta cerrar una alarma que no existe.
class AlarmaNoEncontradaException implements Exception {
  final int alarmaId;

  const AlarmaNoEncontradaException(this.alarmaId);

  @override
  String toString() =>
      'AlarmaNoEncontradaException: No existe ninguna alarma con id=$alarmaId.';
}
