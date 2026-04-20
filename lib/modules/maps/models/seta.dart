import 'package:maplibre_gl/maplibre_gl.dart';

/// Centro de transformación o subestación eléctrica.
/// Corresponde a la tabla `setas` en Supabase (BIGSERIAL PRIMARY KEY).
class Seta {
  /// ID autoincremental generado por el servidor (BIGSERIAL).
  final int id;

  /// Nombre identificador de la seta.
  final String nombre;

  /// Tipo de estructura de la seta.
  final String tipo;

  /// Coordenadas geográficas del punto.
  final LatLng coordenadas;

  const Seta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.coordenadas,
  });

  @override
  String toString() => 'Seta(id: $id, nombre: $nombre, tipo: $tipo)';
}
