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
  static const _keySeccionamientos = 'capas_seccionamientos';
  static const _keyCdn = 'capas_cdn';

  final _controller = StreamController<EstadoCapas>.broadcast();
  EstadoCapas _estado = EstadoCapas.inicial;

  Stream<EstadoCapas> get stream => _controller.stream;
  EstadoCapas get estado => _estado;

  Future<void> cargarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    _estado = EstadoCapas(
      lmtVisible: prefs.getBool(_keyLmt) ?? true,
      setasVisible: prefs.getBool(_keySetas) ?? true,
      barriosVisible: prefs.getBool(_keyBarrios) ?? true,
      seccionamientosVisible: prefs.getBool(_keySeccionamientos) ?? true,
      cdnVisible: prefs.getBool(_keyCdn) ?? true,
    );
    _emit();
  }

  Future<void> toggleLmt() async {
    _estado = _estado.copyWith(lmtVisible: !_estado.lmtVisible);
    await _persistir();
    _emit();
  }

  Future<void> toggleSetas() async {
    _estado = _estado.copyWith(setasVisible: !_estado.setasVisible);
    await _persistir();
    _emit();
  }

  Future<void> toggleBarrios() async {
    _estado = _estado.copyWith(barriosVisible: !_estado.barriosVisible);
    await _persistir();
    _emit();
  }

  Future<void> toggleSeccionamientos() async {
    _estado = _estado.copyWith(seccionamientosVisible: !_estado.seccionamientosVisible);
    await _persistir();
    _emit();
  }

  Future<void> toggleCdn() async {
    _estado = _estado.copyWith(cdnVisible: !_estado.cdnVisible);
    await _persistir();
    _emit();
  }

  Future<void> _persistir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLmt, _estado.lmtVisible);
    await prefs.setBool(_keySetas, _estado.setasVisible);
    await prefs.setBool(_keyBarrios, _estado.barriosVisible);
    await prefs.setBool(_keySeccionamientos, _estado.seccionamientosVisible);
    await prefs.setBool(_keyCdn, _estado.cdnVisible);
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_estado);
  }

  void dispose() => _controller.close();
}
