import 'dart:math';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Operaciones geométricas en cliente: simplificación Douglas-Peucker
/// e intersección de polilíneas.
/// Requerimientos: 9.6, 4.3
class GeometriaService {
  const GeometriaService();

  // ---------------------------------------------------------------------------
  // Douglas-Peucker
  // ---------------------------------------------------------------------------

  /// Simplifica una polilínea usando el algoritmo Douglas-Peucker.
  ///
  /// [puntos] lista de coordenadas originales.
  /// [tolerancia] distancia máxima permitida (en grados) entre un punto
  /// intermedio y la línea que une sus extremos.
  ///
  /// Requerimiento 9.6
  List<LatLng> simplificar(List<LatLng> puntos, double tolerancia) {
    if (puntos.length < 3) return List.of(puntos);
    return _douglasPeucker(puntos, tolerancia);
  }

  List<LatLng> _douglasPeucker(List<LatLng> puntos, double tolerancia) {
    double maxDist = 0;
    int indiceMax = 0;

    for (int i = 1; i < puntos.length - 1; i++) {
      final d = _distanciaPuntoASegmento(
        puntos[i],
        puntos.first,
        puntos.last,
      );
      if (d > maxDist) {
        maxDist = d;
        indiceMax = i;
      }
    }

    if (maxDist > tolerancia) {
      final izq = _douglasPeucker(puntos.sublist(0, indiceMax + 1), tolerancia);
      final der = _douglasPeucker(puntos.sublist(indiceMax), tolerancia);
      // Evitar duplicar el punto de unión
      return [...izq.sublist(0, izq.length - 1), ...der];
    }

    return [puntos.first, puntos.last];
  }

  /// Distancia perpendicular de [p] al segmento [a]–[b] (en grados).
  double _distanciaPuntoASegmento(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      // a y b son el mismo punto
      return _distancia(p, a);
    }

    final t = ((p.longitude - a.longitude) * dx +
            (p.latitude - a.latitude) * dy) /
        lenSq;
    final tc = t.clamp(0.0, 1.0);

    final px = a.longitude + tc * dx;
    final py = a.latitude + tc * dy;
    return sqrt(pow(p.longitude - px, 2) + pow(p.latitude - py, 2));
  }

  double _distancia(LatLng a, LatLng b) {
    return sqrt(
      pow(a.longitude - b.longitude, 2) + pow(a.latitude - b.latitude, 2),
    );
  }

  // ---------------------------------------------------------------------------
  // Intersección de polilíneas
  // ---------------------------------------------------------------------------

  /// Devuelve `true` si algún segmento de [lineaA] intersecta algún segmento
  /// de [lineaB].
  ///
  /// Requerimiento 4.3
  bool intersectan(List<LatLng> lineaA, List<LatLng> lineaB) {
    for (int i = 0; i < lineaA.length - 1; i++) {
      for (int j = 0; j < lineaB.length - 1; j++) {
        if (_segmentosIntersectan(
          lineaA[i], lineaA[i + 1],
          lineaB[j], lineaB[j + 1],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Comprueba si el segmento [p1]–[p2] intersecta el segmento [p3]–[p4]
  /// usando el método de orientación cruzada.
  bool _segmentosIntersectan(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    final d1 = _orientacion(p3, p4, p1);
    final d2 = _orientacion(p3, p4, p2);
    final d3 = _orientacion(p1, p2, p3);
    final d4 = _orientacion(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    // Casos colineales
    if (d1 == 0 && _enSegmento(p3, p4, p1)) return true;
    if (d2 == 0 && _enSegmento(p3, p4, p2)) return true;
    if (d3 == 0 && _enSegmento(p1, p2, p3)) return true;
    if (d4 == 0 && _enSegmento(p1, p2, p4)) return true;

    return false;
  }

  /// Producto vectorial (cross product) para determinar orientación.
  double _orientacion(LatLng a, LatLng b, LatLng c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  /// Verifica si el punto [p] está sobre el segmento [a]–[b] (caso colineal).
  bool _enSegmento(LatLng a, LatLng b, LatLng p) {
    return p.longitude <= max(a.longitude, b.longitude) &&
        p.longitude >= min(a.longitude, b.longitude) &&
        p.latitude <= max(a.latitude, b.latitude) &&
        p.latitude >= min(a.latitude, b.latitude);
  }
}
