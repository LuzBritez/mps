import 'package:maplibre_gl/maplibre_gl.dart';

/// Línea de Media Tensión.
/// Corresponde a la tabla `lmt` en Supabase (BIGSERIAL PRIMARY KEY).
class LMT {
  /// ID autoincremental generado por el servidor (BIGSERIAL).
  final int id;

  /// Nombre identificador de la línea.
  final String nombre;

  /// Nivel de tensión, e.g. "13.2kV", "33kV".
  final String nivelTension;

  /// Secuencia de coordenadas que forman la polilínea.
  final List<LatLng> coordenadas;

  /// Metadatos adicionales en formato clave-valor.
  final Map<String, dynamic> metadatos;

  const LMT({
    required this.id,
    required this.nombre,
    required this.nivelTension,
    required this.coordenadas,
    this.metadatos = const {},
  });

  @override
  String toString() =>
      'LMT(id: $id, nombre: $nombre, nivelTension: $nivelTension)';
}
