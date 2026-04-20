/// Estado de una alarma en el sistema.
enum EstadoAlarma {
  activa,
  cerrada,
}

/// Estado de ciclo de vida de una tarea.
enum EstadoTarea {
  pendiente,
  enCurso,
  completada,
}

/// Tipo de asignación de una tarea.
enum TipoAsignacion {
  operario,
  cuadrilla,
}

/// Tipo de elemento de la red eléctrica.
enum TipoElemento {
  lmt,
  seta,
}

/// Categorías de incidencia disponibles para el Operario.
/// Requerimiento 6.2
class CategoriasIncidencia {
  CategoriasIncidencia._();

  static const String arbolCaido = 'arbol_caido';
  static const String ramaTocandoCable = 'rama_tocando_cable';
  static const String posteCaido = 'poste_caido';
  static const String cableCortado = 'cable_cortado';
  static const String cableChispeando = 'cable_chispeando';
  static const String notaMantenimiento = 'nota_mantenimiento';
  static const String danoVisible = 'daño_visible';

  /// Lista completa de categorías válidas.
  static const List<String> todas = [
    arbolCaido,
    ramaTocandoCable,
    posteCaido,
    cableCortado,
    cableChispeando,
    notaMantenimiento,
    danoVisible,
  ];
}
