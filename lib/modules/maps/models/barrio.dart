import 'package:maplibre_gl/maplibre_gl.dart';

/// Barrio o zona urbana de referencia.
/// Corresponde a la tabla `barrios` en Supabase (BIGSERIAL PRIMARY KEY).
class Barrio {
  /// ID autoincremental generado por el servidor (BIGSERIAL).
  final int id;

  /// Nombre del barrio.
  final String nombre;

  /// Lista de coordenadas que forman el polígono del barrio.
  final List<LatLng> poligono;

  const Barrio({
    required this.id,
    required this.nombre,
    required this.poligono,
  });

  @override
  String toString() => 'Barrio(id: $id, nombre: $nombre)';
}
