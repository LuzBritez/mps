import '../models/models.dart';
import '../services/api_client.dart';

/// Repositorio de alarmas contra PostgREST (Docker).
/// Requerimientos: 3.1–3.5, 8.8
class AlarmaRepository {
  final ApiClient _client;
  static const Duration _umbralManipulacion = Duration(minutes: 5);

  AlarmaRepository({ApiClient? client}) : _client = client ?? apiClient;

  Future<Alarma> crearAlarma({
    required int? lmtId,
    required String? zonaDesc,
    required int creadaPor,
    required DateTime tiempoVerdadero,
    required DateTime tiempoDispositivo,
  }) async {
    if (lmtId != null) await _validarLmtExistente(lmtId);

    final diferencia = tiempoVerdadero.difference(tiempoDispositivo).abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    final row = await _client.insert('alarmas', {
      if (lmtId != null) 'lmt_id': lmtId,
      if (zonaDesc != null) 'zona_desc': zonaDesc,
      'estado': 'activa',
      'creada_por': creadaPor,
      'creada_en': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_verdadero': tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_dispositivo': tiempoDispositivo.toUtc().toIso8601String(),
      'posible_manipulacion_reloj': posibleManipulacion,
    });
    return _mapRow(row);
  }

  Future<Alarma> cerrarAlarma({
    required int alarmaId,
    required DateTime tiempoVerdadero,
    required DateTime tiempoDispositivo,
  }) async {
    final diferencia = tiempoVerdadero.difference(tiempoDispositivo).abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    final row = await _client.update(
      'alarmas',
      {
        'estado': 'cerrada',
        'cerrada_en': tiempoVerdadero.toUtc().toIso8601String(),
        'tiempo_verdadero': tiempoVerdadero.toUtc().toIso8601String(),
        'tiempo_dispositivo': tiempoDispositivo.toUtc().toIso8601String(),
        'posible_manipulacion_reloj': posibleManipulacion,
      },
      filters: {'id': 'eq.$alarmaId'},
    );
    return _mapRow(row);
  }

  Future<List<Alarma>> listarAlarmasActivas() async {
    final rows = await _client.select('alarmas', filters: {
      'estado': 'eq.activa',
      'order': 'creada_en.desc',
    });
    return rows.map<Alarma>(_mapRow).toList();
  }

  Future<void> _validarLmtExistente(int lmtId) async {
    final rows = await _client.select('lmt', filters: {
      'id': 'eq.$lmtId',
      'select': 'id',
      'limit': '1',
    });
    if (rows.isEmpty) throw AlarmaLmtInexistenteException(lmtId);
  }

  Alarma _mapRow(Map<String, dynamic> row) {
    return Alarma(
      id: (row['id'] as num).toInt(),
      lmtId: row['lmt_id'] != null ? (row['lmt_id'] as num).toInt() : null,
      zonaDesc: row['zona_desc'] as String?,
      estado: row['estado'] == 'activa' ? EstadoAlarma.activa : EstadoAlarma.cerrada,
      creadaPor: (row['creada_por'] as num).toInt(),
      creadaEn: DateTime.parse(row['creada_en'] as String),
      cerradaEn: row['cerrada_en'] != null ? DateTime.parse(row['cerrada_en'] as String) : null,
      tiempoVerdadero: row['tiempo_verdadero'] != null ? DateTime.parse(row['tiempo_verdadero'] as String) : null,
      tiempoDispositivo: row['tiempo_dispositivo'] != null ? DateTime.parse(row['tiempo_dispositivo'] as String) : null,
      posibleManipulacionReloj: (row['posible_manipulacion_reloj'] as bool?) ?? false,
    );
  }
}

class AlarmaLmtInexistenteException implements Exception {
  final int lmtId;
  const AlarmaLmtInexistenteException(this.lmtId);
  @override
  String toString() => 'AlarmaLmtInexistenteException: No existe LMT con id=$lmtId.';
}

class AlarmaNoEncontradaException implements Exception {
  final int alarmaId;
  const AlarmaNoEncontradaException(this.alarmaId);
  @override
  String toString() => 'AlarmaNoEncontradaException: No existe alarma con id=$alarmaId.';
}
