/// Registro de progreso de inspección de un nodo dentro de una tarea.
/// Corresponde a la tabla `progreso_nodos` en Supabase (PK compuesta: tarea_id + nodo_id).
class ProgresoNodo {
  /// ID de la tarea (BIGINT REFERENCES tareas).
  final int tareaId;

  /// ID del nodo (BIGINT REFERENCES nodos).
  final int nodoId;

  /// Indica si el nodo fue inspeccionado.
  final bool inspeccionado;

  /// Timestamp de inspección, null si aún no inspeccionado.
  final DateTime? inspeccionadoEn;

  /// Tiempo verdadero calculado por RelojNTPService. Requerimiento 8.7
  final DateTime? tiempoVerdadero;

  /// Tiempo del dispositivo (DateTime.now()) para auditoría. Requerimiento 8.7
  final DateTime? tiempoDispositivo;

  const ProgresoNodo({
    required this.tareaId,
    required this.nodoId,
    this.inspeccionado = false,
    this.inspeccionadoEn,
    this.tiempoVerdadero,
    this.tiempoDispositivo,
  });

  ProgresoNodo copyWith({
    bool? inspeccionado,
    DateTime? inspeccionadoEn,
    DateTime? tiempoVerdadero,
    DateTime? tiempoDispositivo,
  }) {
    return ProgresoNodo(
      tareaId: tareaId,
      nodoId: nodoId,
      inspeccionado: inspeccionado ?? this.inspeccionado,
      inspeccionadoEn: inspeccionadoEn ?? this.inspeccionadoEn,
      tiempoVerdadero: tiempoVerdadero ?? this.tiempoVerdadero,
      tiempoDispositivo: tiempoDispositivo ?? this.tiempoDispositivo,
    );
  }

  @override
  String toString() =>
      'ProgresoNodo(tareaId: $tareaId, nodoId: $nodoId, inspeccionado: $inspeccionado)';
}
