import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/estado_capas.dart';

/// Gestiona el estado de visibilidad de las capas del mapa con persistencia
/// entre sesiones y reactividad mediante un [Stream].
/// Requerimientos: 2.1–2.5
class CapasStateService {
  static const _keyLmt = 'capas_lmt';
  static const _keySetas = 'capas_setas';
  static const _keyBarrios = 'capas_barrios';

  final _controller = StreamController<EstadoCapas>.broadcast();
  EstadoCapas _estado = EstadoCapas.inicial;

  /// Stream que emite el [EstadoCapas] cada vez que cambia la visibilidad
  /// de alguna capa.
  Stream<EstadoCapas> get stream => _controller.stream;

  /// Estado actual de las capas.
  EstadoCapas get estado => _estado;

  /// Carga el estado persistido desde [SharedPreferences].
  /// Si no hay datos previos, usa [EstadoCapas.inicial] (todas visibles).
  Future<void> cargarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    _estado = EstadoCapas(
      lmtVisible: prefs.getBool(_keyLmt) ?? true,
      setasVisible: prefs.getBool(_keySetas) ?? true,
      barriosVisible: prefs.getBool(_keyBarrios) ?? true,
    );
    _emit();
  }

  /// Alterna la visibilidad de la capa LMT y persiste el nuevo estado.
  Future<void> toggleLmt() async {
    _estado = _estado.copyWith(lmtVisible: !_estado.lmtVisible);
    await _persistir();
    _emit();
  }

  /// Alterna la visibilidad de la capa Setas y persiste el nuevo estado.
  Future<void> toggleSetas() async {
    _estado = _estado.copyWith(setasVisible: !_estado.setasVisible);
    await _persistir();
    _emit();
  }

  /// Alterna la visibilidad de la capa Barrios y persiste el nuevo estado.
  Future<void> toggleBarrios() async {
    _estado = _estado.copyWith(barriosVisible: !_estado.barriosVisible);
    await _persistir();
    _emit();
  }

  Future<void> _persistir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLmt, _estado.lmtVisible);
    await prefs.setBool(_keySetas, _estado.setasVisible);
    await prefs.setBool(_keyBarrios, _estado.barriosVisible);
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_estado);
  }

  /// Libera los recursos del stream.
  void dispose() => _controller.close();
}
