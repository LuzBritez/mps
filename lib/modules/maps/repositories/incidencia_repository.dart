import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/incidencia_local.dart';
import '../services/local_db_schema.dart';

/// Repositorio de incidencias con soporte online (Supabase) y offline (SQLite).
///
/// Lógica de [persistirIncidencia]:
/// 1. Si hay conectividad: sube la imagen (si existe) y persiste en Supabase.
///    Retorna el ID asignado por el servidor (BIGSERIAL).
/// 2. Sin conectividad: persiste en SQLite local (`incidencias_pendientes`).
///    Retorna el `local_id` asignado por SQLite (AUTOINCREMENT).
///
/// Requerimientos: 6.4, 6.5, 6.9, 6.10, 7.1, 8.6, 8.10, 8.11
class IncidenciaRepository {
  final SupabaseClient _client;
  final Connectivity _connectivity;

  /// Nombre del bucket de Supabase Storage para imágenes de incidencias.
  static const String _bucketIncidencias = 'incidencias';

  /// Umbral para detectar posible manipulación del reloj del dispositivo.
  /// Requerimiento 8.11
  static const Duration _umbralManipulacion = Duration(minutes: 5);

  /// Nombre del archivo de base de datos SQLite local.
  static const String _dbName = 'maps_offline.db';

  Database? _db;

  IncidenciaRepository({
    SupabaseClient? client,
    Connectivity? connectivity,
  })  : _client = client ?? Supabase.instance.client,
        _connectivity = connectivity ?? Connectivity();

  // ── Base de datos local ───────────────────────────────────────────────────

  /// Abre (o crea) la base de datos SQLite local con el esquema definido
  /// en [kCreateIncidenciasPendientes].
  Future<Database> _abrirDb() async {
    _db ??= await openDatabase(
      _dbName,
      version: 1,
      onCreate: (db, _) => db.execute(kCreateIncidenciasPendientes),
    );
    return _db!;
  }

  // ── Verificar conectividad ────────────────────────────────────────────────

  /// Retorna `true` si hay al menos una interfaz de red activa.
  Future<bool> _hayConectividad() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ── persistirIncidencia ───────────────────────────────────────────────────

  /// Persiste una incidencia online o offline según la conectividad disponible.
  ///
  /// - Con conectividad: sube la imagen (si existe) y guarda en Supabase.
  ///   Retorna el ID asignado por el servidor (BIGSERIAL).
  /// - Sin conectividad: guarda en SQLite `incidencias_pendientes`.
  ///   Retorna el `local_id` asignado por SQLite (AUTOINCREMENT).
  ///
  /// Requerimientos: 6.4, 6.5, 6.9, 6.10, 7.1, 8.6, 8.10, 8.11
  Future<int> persistirIncidencia(IncidenciaLocal incidencia) async {
    if (await _hayConectividad()) {
      return _persistirOnline(incidencia);
    } else {
      return _persistirOffline(incidencia);
    }
  }

  // ── Persistencia online ───────────────────────────────────────────────────

  /// Inserta la incidencia en la tabla `incidencias` de Supabase.
  ///
  /// Si la incidencia tiene imagen, la sube primero a Storage y usa la URL
  /// pública resultante como `imagen_url`.
  ///
  /// Requerimientos: 6.4, 6.5, 6.9, 6.10, 8.6, 8.10, 8.11
  Future<int> _persistirOnline(IncidenciaLocal incidencia) async {
    // Req. 6.9, 6.10: subir imagen si existe y obtener URL pública.
    String? imagenUrl;
    if (incidencia.imagenPath != null) {
      imagenUrl = await uploadImagen(incidencia.imagenPath!);
    }

    // Req. 8.11: detectar posible manipulación del reloj.
    final diferencia = incidencia.tiempoVerdadero
        .difference(incidencia.tiempoDispositivo)
        .abs();
    final posibleManipulacion = diferencia > _umbralManipulacion;

    // Req. 6.4, 8.6, 8.10: construir payload con todos los campos requeridos.
    final payload = <String, dynamic>{
      'tarea_id': incidencia.tareaId,
      'operario_id': incidencia.operarioId,
      'elemento_id': incidencia.elementoId,
      'tipo_elemento': incidencia.tipoElemento,
      'categoria': incidencia.categoria,
      'descripcion': incidencia.descripcion,
      // PostGIS POINT en formato WKT: POINT(lng lat)
      'coordenadas':
          'POINT(${incidencia.coordenadas.longitude} ${incidencia.coordenadas.latitude})',
      if (imagenUrl != null) 'imagen_url': imagenUrl,
      'tiempo_verdadero':
          incidencia.tiempoVerdadero.toUtc().toIso8601String(),
      'tiempo_dispositivo':
          incidencia.tiempoDispositivo.toUtc().toIso8601String(),
      'posible_manipulacion_reloj': posibleManipulacion,
      'tiempo_no_verificado': incidencia.tiempoNoVerificado,
      'sincronizada': true,
    };

    final rows =
        await _client.from('incidencias').insert(payload).select('id');

    return (rows.first['id'] as num).toInt();
  }

  // ── Persistencia offline ──────────────────────────────────────────────────

  /// Inserta la incidencia en la tabla SQLite `incidencias_pendientes`.
  ///
  /// Requerimientos: 7.1, 8.6
  Future<int> _persistirOffline(IncidenciaLocal incidencia) async {
    final db = await _abrirDb();

    final localId = await db.insert(
      'incidencias_pendientes',
      {
        'tarea_id': incidencia.tareaId,
        'operario_id': incidencia.operarioId,
        'elemento_id': incidencia.elementoId,
        'tipo_elemento': incidencia.tipoElemento,
        'categoria': incidencia.categoria,
        'descripcion': incidencia.descripcion,
        'lat': incidencia.coordenadas.latitude,
        'lng': incidencia.coordenadas.longitude,
        'imagen_path': incidencia.imagenPath,
        'tiempo_verdadero':
            incidencia.tiempoVerdadero.toUtc().toIso8601String(),
        'tiempo_dispositivo':
            incidencia.tiempoDispositivo.toUtc().toIso8601String(),
        'posible_manipulacion_reloj':
            incidencia.posibleManipulacionReloj ? 1 : 0,
        'tiempo_no_verificado': incidencia.tiempoNoVerificado ? 1 : 0,
        'intentos': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.fail,
    );

    return localId;
  }

  // ── uploadImagen ──────────────────────────────────────────────────────────

  /// Sube una imagen al bucket `incidencias` de Supabase Storage y retorna
  /// la URL pública del archivo subido.
  ///
  /// El nombre del archivo en Storage se genera a partir del timestamp UTC
  /// actual para evitar colisiones.
  ///
  /// Requerimientos: 6.9, 6.10, 8.10
  Future<String> uploadImagen(String imagenPath) async {
    final archivo = File(imagenPath);
    final nombreArchivo =
        '${DateTime.now().toUtc().millisecondsSinceEpoch}_${archivo.uri.pathSegments.last}';

    await _client.storage.from(_bucketIncidencias).upload(
          nombreArchivo,
          archivo,
          fileOptions: const FileOptions(upsert: false),
        );

    return _client.storage
        .from(_bucketIncidencias)
        .getPublicUrl(nombreArchivo);
  }

  // ── obtenerIncidenciasPendientes ──────────────────────────────────────────

  /// Lee de SQLite todas las incidencias pendientes de sincronización.
  ///
  /// Todas las filas en `incidencias_pendientes` son por definición
  /// no sincronizadas (`sincronizada = false` en el modelo).
  ///
  /// Requerimiento: 7.1
  Future<List<IncidenciaLocal>> obtenerIncidenciasPendientes() async {
    final db = await _abrirDb();
    final rows = await db.query('incidencias_pendientes');
    return rows.map(_mapRowSqlite).toList();
  }

  // ── Mapeo de filas SQLite ─────────────────────────────────────────────────

  /// Convierte una fila de SQLite al modelo [IncidenciaLocal].
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

// ── Excepciones ───────────────────────────────────────────────────────────────

/// Excepción lanzada cuando falla el upload de una imagen a Supabase Storage.
///
/// Requerimiento: 6.10
class IncidenciaImagenUploadException implements Exception {
  final String imagenPath;
  final Object causa;

  const IncidenciaImagenUploadException(this.imagenPath, this.causa);

  @override
  String toString() =>
      'IncidenciaImagenUploadException: No se pudo subir la imagen '
      '"$imagenPath". Causa: $causa';
}
