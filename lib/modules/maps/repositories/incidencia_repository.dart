import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:sqflite/sqflite.dart';

import '../models/incidencia_local.dart';
import '../services/api_client.dart';
import '../services/local_db_schema.dart';

/// Repositorio de incidencias con soporte online (PostgREST) y offline (SQLite).
/// Requerimientos: 6.4, 6.5, 6.9, 6.10, 7.1, 8.6, 8.10, 8.11
class IncidenciaRepository {
  final ApiClient _client;
  final Connectivity _connectivity;

  static const Duration _umbralManipulacion = Duration(minutes: 5);
  static const String _dbName = 'maps_offline.db';

  Database? _db;

  IncidenciaRepository({
    ApiClient? client,
    Connectivity? connectivity,
  })  : _client = client ?? apiClient,
        _connectivity = connectivity ?? Connectivity();

  Future<Database> _abrirDb() async {
    _db ??= await openDatabase(
      _dbName,
      version: 1,
      onCreate: (db, _) => db.execute(kCreateIncidenciasPendientes),
    );
    return _db!;
  }

  Future<bool> _hayConectividad() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<int> persistirIncidencia(IncidenciaLocal incidencia) async {
    if (await _hayConectividad()) {
      return _persistirOnline(incidencia);
    } else {
      return _persistirOffline(incidencia);
    }
  }

  Future<int> _persistirOnline(IncidenciaLocal incidencia) async {
    String? imagenUrl;
    if (incidencia.imagenPath != null) {
      imagenUrl = await uploadImagen(incidencia.imagenPath!);
    }

    final diferencia = incidencia.tiempoVerdadero.difference(incidencia.tiempoDispositivo).abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    final row = await _client.insert('incidencias', {
      'tarea_id': incidencia.tareaId,
      'operario_id': incidencia.operarioId,
      'elemento_id': incidencia.elementoId,
      'tipo_elemento': incidencia.tipoElemento,
      'categoria': incidencia.categoria,
      'descripcion': incidencia.descripcion,
      'coordenadas': 'POINT(${incidencia.coordenadas.longitude} ${incidencia.coordenadas.latitude})',
      if (imagenUrl != null) 'imagen_url': imagenUrl,
      'tiempo_verdadero': incidencia.tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_dispositivo': incidencia.tiempoDispositivo.toUtc().toIso8601String(),
      'posible_manipulacion_reloj': posibleManipulacion,
      'tiempo_no_verificado': incidencia.tiempoNoVerificado,
      'sincronizada': true,
    });
    return (row['id'] as num).toInt();
  }

  Future<int> _persistirOffline(IncidenciaLocal incidencia) async {
    final db = await _abrirDb();
    return db.insert('incidencias_pendientes', {
      'tarea_id': incidencia.tareaId,
      'operario_id': incidencia.operarioId,
      'elemento_id': incidencia.elementoId,
      'tipo_elemento': incidencia.tipoElemento,
      'categoria': incidencia.categoria,
      'descripcion': incidencia.descripcion,
      'lat': incidencia.coordenadas.latitude,
      'lng': incidencia.coordenadas.longitude,
      'imagen_path': incidencia.imagenPath,
      'tiempo_verdadero': incidencia.tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_dispositivo': incidencia.tiempoDispositivo.toUtc().toIso8601String(),
      'posible_manipulacion_reloj': incidencia.posibleManipulacionReloj ? 1 : 0,
      'tiempo_no_verificado': incidencia.tiempoNoVerificado ? 1 : 0,
      'intentos': 0,
    });
  }

  // Req. 6.9, 6.10 — encodes image as base64 data URI stored in imagen_url TEXT.
  Future<String> uploadImagen(String imagenPath) async {
    final bytes = await File(imagenPath).readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<List<IncidenciaLocal>> obtenerIncidenciasPendientes() async {
    final db = await _abrirDb();
    final rows = await db.query('incidencias_pendientes');
    return rows.map(_mapRowSqlite).toList();
  }

  IncidenciaLocal _mapRowSqlite(Map<String, dynamic> row) {
    return IncidenciaLocal(
      localId: row['local_id'] as int?,
      tareaId: row['tarea_id'] as int,
      operarioId: row['operario_id'] as int,
      elementoId: row['elemento_id'] as int,
      tipoElemento: row['tipo_elemento'] as String,
      categoria: row['categoria'] as String,
      descripcion: row['descripcion'] as String,
      coordenadas: LatLng(
        (row['lat'] as num).toDouble(),
        (row['lng'] as num).toDouble(),
      ),
      imagenPath: row['imagen_path'] as String?,
      tiempoVerdadero: DateTime.parse(row['tiempo_verdadero'] as String),
      tiempoDispositivo: DateTime.parse(row['tiempo_dispositivo'] as String),
      posibleManipulacionReloj: (row['posible_manipulacion_reloj'] as int) == 1,
      tiempoNoVerificado: (row['tiempo_no_verificado'] as int) == 1,
      sincronizada: false,
    );
  }
}
