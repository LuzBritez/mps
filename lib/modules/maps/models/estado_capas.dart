/// Estado de visibilidad de las capas del mapa.
/// Persiste entre sesiones vía SharedPreferences.
/// Requerimiento 2.5
class EstadoCapas {
  final bool lmtVisible;
  final bool setasVisible;
  final bool barriosVisible;
  final bool seccionamientosVisible;
  final bool cdnVisible;

  const EstadoCapas({
    this.lmtVisible = true,
    this.setasVisible = true,
    this.barriosVisible = true,
    this.seccionamientosVisible = true,
    this.cdnVisible = true,
  });

  static const EstadoCapas inicial = EstadoCapas();

  EstadoCapas copyWith({
    bool? lmtVisible,
    bool? setasVisible,
    bool? barriosVisible,
    bool? seccionamientosVisible,
    bool? cdnVisible,
  }) {
    return EstadoCapas(
      lmtVisible: lmtVisible ?? this.lmtVisible,
      setasVisible: setasVisible ?? this.setasVisible,
      barriosVisible: barriosVisible ?? this.barriosVisible,
      seccionamientosVisible: seccionamientosVisible ?? this.seccionamientosVisible,
      cdnVisible: cdnVisible ?? this.cdnVisible,
    );
  }

  @override
  String toString() =>
      'EstadoCapas(lmt: $lmtVisible, setas: $setasVisible, barrios: $barriosVisible, '
      'secc: $seccionamientosVisible, cdn: $cdnVisible)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EstadoCapas &&
          lmtVisible == other.lmtVisible &&
          setasVisible == other.setasVisible &&
          barriosVisible == other.barriosVisible &&
          seccionamientosVisible == other.seccionamientosVisible &&
          cdnVisible == other.cdnVisible;

  @override
  int get hashCode =>
      lmtVisible.hashCode ^
      setasVisible.hashCode ^
      barriosVisible.hashCode ^
      seccionamientosVisible.hashCode ^
      cdnVisible.hashCode;
}
