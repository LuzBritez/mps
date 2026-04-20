import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Gestiona la caché de tiles `.pbf` para uso offline.
///
/// - Almacena tiles como archivos en el directorio de caché de la app.
/// - Mantiene un índice LRU en memoria para evictar los tiles más antiguos.
/// - Monitorea la memoria disponible y reduce el límite al 50% si
///   la memoria disponible es inferior a 200 MB (Requerimiento 9.10).
/// - Permite la navegación offline con los tiles del área de trabajo
///   del Operario (Requerimiento 9.11).
class TilesCacheService {
  static const int _defaultMaxTiles = 500;
  static const int _memoriaUmbralMb = 200;

  final int defaultMaxTiles;

  int _maxTilesEnCache;

  /// Índice LRU: clave → orden de acceso (más reciente al final).
  final LinkedHashMap<String, bool> _lruIndex =
      LinkedHashMap<String, bool>();

  TilesCacheService({this.defaultMaxTiles = _defaultMaxTiles})
      : _maxTilesEnCache = defaultMaxTiles;

  /// Límite máximo de tiles en caché.
  /// Se reduce al 50% si la memoria disponible es inferior a 200 MB.
  int get maxTilesEnCache => _maxTilesEnCache;

  // ---------------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------------

  /// Guarda un tile `.pbf` en la caché local.
  ///
  /// [tileKey] es el path relativo con formato `{z}/{x}/{y}.pbf`.
  Future<void> guardarTile(String tileKey, Uint8List data) async {
    final file = await _fileForKey(tileKey);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data, flush: true);
    _actualizarLru(tileKey);
    await evictarSiNecesario();
  }

  /// Obtiene un tile `.pbf` de la caché local.
  /// Devuelve `null` si el tile no existe.
  Future<Uint8List?> obtenerTile(String tileKey) async {
    final file = await _fileForKey(tileKey);
    if (!await file.exists()) return null;
    _actualizarLru(tileKey);
    return file.readAsBytes();
  }

  /// Verifica la memoria disponible del dispositivo y ajusta el límite
  /// de caché si es necesario (Requerimiento 9.10).
  Future<void> verificarMemoriaYAjustar() async {
    final disponibleMb = await _memoriaDisponibleMb();
    if (disponibleMb < _memoriaUmbralMb) {
      _maxTilesEnCache = defaultMaxTiles ~/ 2;
    } else {
      _maxTilesEnCache = defaultMaxTiles;
    }
  }

  /// Elimina los tiles más antiguos del índice LRU cuando se supera el límite.
  Future<void> evictarSiNecesario() async {
    while (_lruIndex.length > _maxTilesEnCache) {
      final oldest = _lruIndex.keys.first;
      _lruIndex.remove(oldest);
      final file = await _fileForKey(oldest);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  /// Devuelve el [File] correspondiente a [tileKey] dentro del directorio
  /// de caché de la aplicación.
  Future<File> _fileForKey(String tileKey) async {
    final cacheDir = await getApplicationCacheDirectory();
    final tilesDir = Directory('${cacheDir.path}/tiles');
    return File('${tilesDir.path}/$tileKey');
  }

  /// Mueve [tileKey] al final del índice LRU (acceso más reciente).
  void _actualizarLru(String tileKey) {
    _lruIndex.remove(tileKey);
    _lruIndex[tileKey] = true;
  }

  /// Devuelve la memoria disponible en MB.
  ///
  /// En Android lee `/proc/meminfo`; en otras plataformas usa
  /// `ProcessInfo.currentRss` como aproximación conservadora.
  Future<int> _memoriaDisponibleMb() async {
    if (Platform.isAndroid) {
      return _leerMemInfoAndroid();
    }
    // En iOS y otras plataformas: aproximación basada en RSS del proceso.
    const int limiteAsumidoBytes = 512 * 1024 * 1024;
    final usadoBytes = ProcessInfo.currentRss;
    final disponibleBytes =
        (limiteAsumidoBytes - usadoBytes).clamp(0, limiteAsumidoBytes);
    return disponibleBytes ~/ (1024 * 1024);
  }

  /// Lee `MemAvailable` de `/proc/meminfo` en Android.
  Future<int> _leerMemInfoAndroid() async {
    try {
      final lines = await File('/proc/meminfo').readAsLines();
      for (final line in lines) {
        if (line.startsWith('MemAvailable:')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final kb = int.tryParse(parts[1]) ?? 0;
            return kb ~/ 1024;
          }
        }
      }
    } catch (_) {
      // Si no se puede leer, asumir memoria suficiente.
    }
    return _memoriaUmbralMb + 1;
  }
}
