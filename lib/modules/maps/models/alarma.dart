import 'enums.dart';

/// Evento de falla en la red eléctrica.
/// Corresponde a la tabla `alarmas` en Supabase (BIGSERIAL PRIMARY KEY).
class Alarma {
  /// ID autoincremental generado por el servidor (BIGSERIAL).
  final int id;

  /// ID de la LMT afectada (BIGINT REFERENCES lmt).
  final int? lmtId;

  /// Descripción textual de la zona afectada.
  final String? zonaDesc;

  /// Estado actual de la alarma.
  final EstadoAlarma estado;

  /// ID del coordinador que creó la alarma.
  final int creadaPor;

  /// Timestamp de creación (tiempo verdadero NTP). Requerimiento 8.8
  final DateTime creadaEn;

  /// Timestamp de cierre (tiempo verdadero NTP), null si aún activa.
  final DateTime? cerradaEn;

  /// Tiempo verdadero calculado por RelojNTPService. Requerimiento 8.8
  final DateTime? tiempoVerdadero;

  /// Tiempo del dispositivo (DateTime.now()) para auditoría. Requerimiento 8.8
  final DateTime? tiempoDispositivo;

  /// Indica posible manipulación del reloj del dispositivo. Requerimiento 8.11
  final bool posibleManipulacionReloj;

  const Alarma({
    required this.id,
    this.lmtId,
    this.zonaDesc,
    required this.estado,
    required this.creadaPor,
    required this.creadaEn,
    this.cerradaEn,
    this.tiempoVerdadero,
    this.tiempoDispositivo,
    this.posibleManipulacionReloj = false,
  });

  @override
  String toString() =>
      'Alarma(id: $id, estado: $estado, lmtId: $lmtId)';
}
