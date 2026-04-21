import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../models/incidencia_local.dart';
import '../repositories/incidencia_repository.dart';
import '../services/local_db_schema.dart';

/// Servicio de cola de sincronización offline.
///
/// Detecta cambios de conectividad y, al reconectar, sincroniza
/// automáticamente todas las incidencias pendientes almacenadas en SQLite.
///
/// Lógica de sincronización:
/// 1. Suscribirse a [Connectivity.onConnectivityChanged].
/// 2. Al detectar reconexión (pasa de `none` a cualquier otro estado):
///    - Leer todas las filas de `incidencias_pendientes` en SQLite.
///    - Para cada incidencia, intentar sincronizar con Supabase (máx. 3 intentos).
///    - Backoff exponencial: esperar 2^intento segundos entre reintentos (2s, 4s, 8s).
///    - Si sincroniza exitosamente: eliminar de SQLite y decrementar contador.
///    - Si falla tras 3 intentos: incrementar `intentos` en SQLite y notificar.
/// 3. El [pendientesStream] emite el conteo actualizado tras cada cambio.
///
/// Requerimientos: 7.2, 7.3, 7.4
class ColaSincronizacionService {
  final Connectivity _connectivity;
  final IncidenciaRepository _incidenciaRepo;

  static const String _dbName = 'maps_offline.db';
  static const int _maxIntentos = 3;

  Database? _db;
  StreamSubscription<dynamic>? _connectivitySub;
  bool _estabaDesconectado = false;

  final StreamController<int> _pendientesController =
      StreamController<int>.broadcast();

  final void Function(IncidenciaLocal incidencia)? onFalloPersistente;

  ColaSincronizacionService({
    Connectivity? connectivity,
    IncidenciaRepository? incidenciaRepo,
    this.onFalloPersistente,
  })  : _connectivity = connectivity ?? Connectivity(),
        _incidenciaRepo = incidenciaRepo ?? IncidenciaRepository();

  // ── API pública ───────────────────────────────────────────────────────────

  /// Stream que emite el número de incidencias pendientes de sincronización.
  ///
  /// Requerimiento 7.3
  Stream<int> get pendientesStream => _pendientesController.stream;

  /// Inicia la escucha de cambios de conectividad.
  ///
  /// Emite el conteo inicial de pendientes y se suscribe a
  /// [Connectivity.onConnectivityChanged] para detectar reconexiones.
  ///
  /// Requerimiento 7.2
  void iniciar() {
    _emitirConteoActual();

    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (dynamic result) => _onConnectivityChanged(result),
    );
  }

  /// Detiene la escucha y libera recursos.
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _pendientesController.close();
    _db?.close();
    _db = null;
  }

  // ── Manejo de cambios de conectividad ─────────────────────────────────────

  Future<void> _onConnectivityChanged(dynamic result) async {
    // Soporta connectivity_plus <6 (ConnectivityResult) y >=6 (List<ConnectivityResult>)
    bool hayConexion;
    if (result is List) {
      hayConexion = (result).any((r) => r != ConnectivityResult.none);
    } else {
      hayConexion = result != ConnectivityResult.none;
    }

    if (hayConexion && _estabaDesconectado) {
      // Reconexión detectada: sincronizar pendientes.
      _estabaDesconectado = false;
      await _sincronizarPendientes();
    } else if (!hayConexion) {
      _estabaDesconectado = true;
    }
  }

  // ── Sincronización de pendientes ──────────────────────────────────────────

  /// Lee todas las incidencias pendientes de SQLite y las sincroniza
  /// secuencialmente con Supabase usando backoff exponencial.
  ///
  /// Requerimientos: 7.2, 7.4
  Future<void> _sincronizarPendientes() async {
    final pendientes = await _incidenciaRepo.obtenerIncidenciasPendientes();

    for (final incidencia in pendientes) {
      await _sincronizarIncidencia(incidencia);
    }

    await _emitirConteoActual();
  }

  /// Intenta sincronizar una incidencia individual con backoff exponencial.
  ///
  /// - Máximo [_maxIntentos] intentos.
  /// - Espera 2^intento segundos entre reintentos (2s, 4s, 8s).
  /// - Si tiene éxito: elimina la fila de SQLite.
  /// - Si falla tras todos los intentos: incrementa `intentos` en SQLite
  ///   y llama a [onFalloPersistente]. Requerimiento 7.4
  Future<void> _sincronizarIncidencia(IncidenciaLocal incidencia) async {
    final localId = incidencia.localId;
    if (localId == null) return;

    for (int intento = 1; intento <= _maxIntentos; intento++) {
      try {
        await _incidenciaRepo.persistirIncidencia(
          incidencia.copyWith(sincronizada: false),
        );

        // Éxito: eliminar de SQLite y actualizar contador.
        await _eliminarPendiente(localId);
        await _emitirConteoActual();
        return;
      } catch (_) {
        if (intento < _maxIntentos) {
          // Backoff exponencial: 2^intento segundos (2s, 4s, 8s).
          await Future.delayed(Duration(seconds: 1 << intento));
        }
      }
    }

    // Falló tras todos los intentos: incrementar contador en SQLite.
    await _incrementarIntentos(localId);
    await _emitirConteoActual();

    // Notificar al Operario si el fallo persiste. Requerimiento 7.4
    onFalloPersistente?.call(incidencia);
  }

  // ── Operaciones SQLite ────────────────────────────────────────────────────

  Future<Database> _abrirDb() async {
    _db ??= await openDatabase(
      _dbName,
      version: 1,
      onCreate: (db, _) => db.execute(kCreateIncidenciasPendientes),
    );
    return _db!;
  }

  /// Elimina una incidencia de `incidencias_pendientes` por su `local_id`.
  Future<void> _eliminarPendiente(int localId) async {
    final db = await _abrirDb();
    await db.delete(
      'incidencias_pendientes',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Incrementa el campo `intentos` de una incidencia en SQLite.
  Future<void> _incrementarIntentos(int localId) async {
    final db = await _abrirDb();
    await db.rawUpdate(
      'UPDATE incidencias_pendientes SET intentos = intentos + 1 WHERE local_id = ?',
      [localId],
    );
  }

  /// Lee el conteo actual de pendientes desde SQLite y lo emite en el stream.
  ///
  /// Requerimiento 7.3
  Future<void> _emitirConteoActual() async {
    try {
      final db = await _abrirDb();
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM incidencias_pendientes',
      );
      final total = (result.first['total'] as int?) ?? 0;
      if (!_pendientesController.isClosed) {
        _pendientesController.add(total);
      }
    } catch (_) {
      // Si la DB aún no existe, emitir 0.
      if (!_pendientesController.isClosed) {
        _pendientesController.add(0);
      }
    }
  }
}
