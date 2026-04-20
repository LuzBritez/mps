/// Estado de visibilidad de las capas del mapa.
/// Persiste entre sesiones vía SharedPreferences.
/// Requerimiento 2.5
class EstadoCapas {
  /// Indica si la capa de LMT está visible.
  final bool lmtVisible;

  /// Indica si la capa de Setas está visible.
  final bool setasVisible;

  /// Indica si la capa de Barrios está visible.
  final bool barriosVisible;

  const EstadoCapas({
    this.lmtVisible = true,
    this.setasVisible = true,
    this.barriosVisible = true,
  });

  /// Estado por defecto: todas las capas visibles.
  static const EstadoCapas inicial = EstadoCapas();

  EstadoCapas copyWith({
    bool? lmtVisible,
    bool? setasVisible,
    bool? barriosVisible,
  }) {
    return EstadoCapas(
      lmtVisible: lmtVisible ?? this.lmtVisible,
      setasVisible: setasVisible ?? this.setasVisible,
      barriosVisible: barriosVisible ?? this.barriosVisible,
    );
  }

  @override
  String toString() =>
      'EstadoCapas(lmt: $lmtVisible, setas: $setasVisible, barrios: $barriosVisible)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EstadoCapas &&
          lmtVisible == other.lmtVisible &&
          setasVisible == other.setasVisible &&
          barriosVisible == other.barriosVisible;

  @override
  int get hashCode =>
      lmtVisible.hashCode ^ setasVisible.hashCode ^ barriosVisible.hashCode;
}
