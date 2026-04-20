import 'enums.dart';

/// Unidad de trabajo asignada a un Operario o Cuadrilla.
/// Corresponde a la tabla `tareas` en Supabase (BIGSERIAL PRIMARY KEY).
class Tarea {
  /// ID autoincremental generado por el servidor (BIGSERIAL).
  final int id;

  /// ID de la alarma de origen (BIGINT REFERENCES alarmas).
  final int alarmaId;

  /// ID de la LMT asociada (BIGINT REFERENCES lmt).
  final int? lmtId;

  /// Secuencia ordenada de IDs de nodos que conforman la ruta.
  final List<int> rutaNodoIds;

  /// ID del operario o cuadrilla asignada.
  final int asignadaA;

  /// Tipo de asignación: operario o cuadrilla.
  final TipoAsignacion tipoAsignacion;

  /// Estado actual del ciclo de vida de la tarea.
  final EstadoTarea estado;

  /// ID del coordinador que creó la tarea.
  final int creadaPor;

  /// Timestamp de creación.
  final DateTime creadaEn;

  /// Timestamp de inicio del recorrido, null si aún pendiente.
  final DateTime? iniciadaEn;

  /// Timestamp de finalización, null si no completada.
  final DateTime? completadaEn;

  /// Tiempo verdadero calculado por RelojNTPService. Requerimiento 8.9
  final DateTime? tiempoVerdadero;

  /// Tiempo del dispositivo (DateTime.now()) para auditoría. Requerimiento 8.9
  final DateTime? tiempoDispositivo;

  /// Indica posible manipulación del reloj del dispositivo. Requerimiento 8.11
  final bool posibleManipulacionReloj;

  const Tarea({
    required this.id,
    required this.alarmaId,
    this.lmtId,
    required this.rutaNodoIds,
    required this.asignadaA,
    required this.tipoAsignacion,
    required this.estado,
    required this.creadaPor,
    required this.creadaEn,
    this.iniciadaEn,
    this.completadaEn,
    this.tiempoVerdadero,
    this.tiempoDispositivo,
    this.posibleManipulacionReloj = false,
  });

  @override
  String toString() =>
      'Tarea(id: $id, estado: $estado, alarmaId: $alarmaId)';
}
