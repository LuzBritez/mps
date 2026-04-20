import 'package:maplibre_gl/maplibre_gl.dart';

/// Punto de inspección sobre una ruta asignada.
/// Corresponde a la tabla `nodos` en Supabase (BIGSERIAL PRIMARY KEY).
class Nodo {
  /// ID autoincremental generado por el servidor (BIGSERIAL).
  final int id;

  /// Nombre o etiqueta del nodo.
  final String nombre;

  /// ID de la LMT a la que pertenece este nodo.
  final int lmtId;

  /// Coordenadas geográficas del nodo.
  final LatLng coordenadas;

  /// Orden del nodo dentro de la ruta asignada.
  final int orden;

  const Nodo({
    required this.id,
    required this.nombre,
    required this.lmtId,
    required this.coordenadas,
    required this.orden,
  });

  @override
  String toString() =>
      'Nodo(id: $id, nombre: $nombre, lmtId: $lmtId, orden: $orden)';
}
