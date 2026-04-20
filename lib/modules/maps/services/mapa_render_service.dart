import 'package:flutter/material.dart';

/// Lógica pura de renderizado: colores para LMT e iconos para Setas.
/// Requerimientos: 1.3, 1.4, 1.5
class MapaRenderService {
  const MapaRenderService();

  /// Devuelve el color de polilínea según el nivel de tensión de la LMT.
  ///
  /// - "13.2kV" → naranja
  /// - "33kV"   → rojo
  /// - "66kV"   → azul
  /// - default  → gris
  Color colorParaLMT(String nivelTension) {
    switch (nivelTension) {
      case '13.2kV':
        return Colors.orange;
      case '33kV':
        return Colors.red;
      case '66kV':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Devuelve el icono de marcador según el tipo de Seta.
  ///
  /// - "transformador"  → Icons.electric_bolt
  /// - "subestacion"    → Icons.electrical_services
  /// - default          → Icons.location_on
  IconData iconoParaSeta(String tipo) {
    switch (tipo) {
      case 'transformador':
        return Icons.electric_bolt;
      case 'subestacion':
        return Icons.electrical_services;
      default:
        return Icons.location_on;
    }
  }

  /// Limita el nivel de zoom al rango válido [5, 18].
  /// Requerimiento 1.3
  double clampZoom(double valor) => valor.clamp(5.0, 18.0);
}
