import 'package:maplibre_gl/maplibre_gl.dart';

/// Incidencia almacenada localmente en SQLite antes de sincronizar con Supabase.
/// Corresponde a la tabla `incidencias_pendientes` en SQLite local.
/// Requerimientos: 6.4, 7.1, 8.6, 8.10, 8.11
class IncidenciaLocal {
  /// ID local autoincremental (INTEGER PRIMARY KEY AUTOINCREMENT en SQLite).
  /// Es null hasta que el servidor asigna el BIGSERIAL tras sincronizar.
  final int? localId;

  /// ID de la tarea activa (BIGINT REFERENCES tareas).
  final int tareaId;

  /// ID del operario que registra la incidencia (del UserContext).
  final int operarioId;

  /// ID del elemento afectado: lmt_id o seta_id.
  final int elementoId;

  /// Tipo de elemento: 'lmt' o 'seta'.
  final String tipoElemento;

  /// Categoría de la incidencia (ver CategoriasIncidencia).
  final String categoria;

  /// Descripción textual no vacía de la incidencia.
  final String descripcion;

  /// Coordenadas geográficas del elemento afectado.
  final LatLng coordenadas;

  /// Ruta local de la imagen capturada, null si no se adjuntó imagen.
  final String? imagenPath;

  /// Tiempo verdadero calculado por RelojNTPService. Requerimiento 8.6
  final DateTime tiempoVerdadero;

  /// Tiempo del dispositivo (DateTime.now()) para auditoría. Requerimiento 8.6
  final DateTime tiempoDispositivo;

  /// Indica posible manipulación del reloj del dispositivo. Requerimiento 8.11
  final bool posibleManipulacionReloj;

  /// Indica que no hubo sincronización NTP en la sesión. Requerimiento 8.5
  final bool tiempoNoVerificado;

  /// Indica si la incidencia ya fue sincronizada con Supabase.
  final bool sincronizada;

  const IncidenciaLocal({
    this.localId,
    required this.tareaId,
    required this.operarioId,
    required this.elementoId,
    required this.tipoElemento,
    required this.categoria,
    required this.descripcion,
    required this.coordenadas,
    this.imagenPath,
    required this.tiempoVerdadero,
    required this.tiempoDispositivo,
    this.posibleManipulacionReloj = false,
    this.tiempoNoVerificado = false,
    this.sincronizada = false,
  });

  IncidenciaLocal copyWith({
    int? localId,
    bool? sincronizada,
    bool? posibleManipulacionReloj,
    bool? tiempoNoVerificado,
  }) {
    return IncidenciaLocal(
      localId: localId ?? this.localId,
      tareaId: tareaId,
      operarioId: operarioId,
      elementoId: elementoId,
      tipoElemento: tipoElemento,
      categoria: categoria,
      descripcion: descripcion,
      coordenadas: coordenadas,
      imagenPath: imagenPath,
      tiempoVerdadero: tiempoVerdadero,
      tiempoDispositivo: tiempoDispositivo,
      posibleManipulacionReloj:
          posibleManipulacionReloj ?? this.posibleManipulacionReloj,
      tiempoNoVerificado: tiempoNoVerificado ?? this.tiempoNoVerificado,
      sincronizada: sincronizada ?? this.sincronizada,
    );
  }

  @override
  String toString() =>
      'IncidenciaLocal(localId: $localId, tareaId: $tareaId, categoria: $categoria, sincronizada: $sincronizada)';
}
