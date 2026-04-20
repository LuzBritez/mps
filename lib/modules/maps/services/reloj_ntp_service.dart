import 'package:ntp/ntp.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de tiempo confiable basado en NTP.
///
/// Calcula un offset entre el tiempo del servidor NTP y el reloj del
/// dispositivo, lo persiste en SharedPreferences y lo usa para derivar
/// [tiempoVerdadero] sin depender directamente de [DateTime.now()].
///
/// Requerimientos: 8.1–8.5, 8.11
class RelojNTPService {
  static const _kOffsetKey = 'ntp_offset_ms';
  static const _kUmbralManipulacion = Duration(minutes: 5);

  Duration _offset = Duration.zero;
  bool _estaVerificado = false;

  /// `true` si se sincronizó con NTP al menos una vez en la sesión actual.
  bool get estaVerificado => _estaVerificado;

  /// `true` si nunca hubo sincronización NTP en la sesión actual.
  bool get tiempoNoVerificado => !_estaVerificado;

  /// `true` si la diferencia entre [tiempoVerdadero] y [tiempoDispositivo]
  /// supera los 5 minutos, lo que indica posible manipulación del reloj.
  bool get posibleManipulacionReloj {
    final diferencia = tiempoVerdadero().difference(tiempoDispositivo()).abs();
    return diferencia > _kUmbralManipulacion;
  }

  /// Inicializa el servicio cargando el offset persistido (si existe).
  Future<void> inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final offsetMs = prefs.getInt(_kOffsetKey);
    if (offsetMs != null) {
      _offset = Duration(milliseconds: offsetMs);
      // El offset cargado de sesiones anteriores no cuenta como verificado
      // en la sesión actual (req. 8.5).
    }
  }

  /// Consulta el servidor NTP, calcula el offset y lo persiste.
  ///
  /// offset = tiempoNTP - DateTime.now()
  /// Luego: tiempoVerdadero = DateTime.now() + offset
  ///
  /// Requerimiento 8.1, 8.2
  Future<void> sincronizarConNTP() async {
    final tiempoNTP = await NTP.now();
    _offset = tiempoNTP.difference(DateTime.now());
    _estaVerificado = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOffsetKey, _offset.inMilliseconds);
  }

  /// Tiempo verdadero: DateTime.now() corregido con el offset NTP.
  ///
  /// Equivalente a offset + uptime_actual. El offset absorbe la desviación
  /// del reloj del dispositivo respecto al tiempo NTP.
  ///
  /// Requerimiento 8.3, 8.4
  DateTime tiempoVerdadero() {
    return DateTime.now().add(_offset);
  }

  /// Tiempo del dispositivo sin corrección, para auditoría.
  ///
  /// Requerimiento 8.6
  DateTime tiempoDispositivo() {
    return DateTime.now();
  }
}
