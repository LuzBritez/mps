import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user_context.dart';
import 'repositories/alarma_repository.dart';
import 'repositories/incidencia_repository.dart';
import 'repositories/red_electrica_repository.dart';
import 'repositories/tarea_repository.dart';
import 'services/capas_state_service.dart';
import 'services/cola_sincronizacion_service.dart';
import 'services/mapa_render_service.dart';
import 'services/reloj_ntp_service.dart';
import 'views/despacho_tareas_view.dart';
import 'views/gestion_alarmas_view.dart';
import 'views/monitor_cuadrillas_view.dart';
import 'widgets/control_capas_widget.dart';
import 'widgets/mapa_interactivo_widget.dart';
import 'widgets/navegacion_tarea_widget.dart';

/// URL base de pg_tileserv. Configurable por entorno.
const String _kPgTileservBaseUrl = String.fromEnvironment(
  'PG_TILESERV_URL',
  defaultValue: 'http://localhost:7800',
);

/// Punto de entrada del módulo Maps — Trazabilidad Eléctrica de Campo.
///
/// La Aplicación Principal invoca [MapsModule.create] pasando el contexto
/// del usuario autenticado y, opcionalmente, el ID de una tarea específica
/// para navegación directa.
///
/// Requerimientos: 1.1, 4.6, 5.6
class MapsModule {
  MapsModule._();

  /// Crea y retorna el widget raíz del módulo.
  ///
  /// [userContext] contiene la identidad y rol del usuario autenticado.
  /// Si [userContext.rol] == [UserRole.coordinador], el router interno
  /// habilita las vistas de gestión (alarmas, despacho, monitor).
  ///
  /// [initialTaskId] es opcional: si se provee, el módulo navega
  /// directamente a NavegacionTareaWidget sin pantalla de selección.
  /// Requerimiento 4.6
  static Widget create({
    required UserContext userContext,
    int? initialTaskId,
  }) {
    return _MapsModuleRoot(
      userContext: userContext,
      initialTaskId: initialTaskId,
    );
  }
}

/// Widget raíz interno del módulo con router por rol.
///
/// Requerimientos: 4.6, 5.6, 9.1
class _MapsModuleRoot extends StatefulWidget {
  final UserContext userContext;
  final int? initialTaskId;

  const _MapsModuleRoot({
    required this.userContext,
    this.initialTaskId,
  });

  @override
  State<_MapsModuleRoot> createState() => _MapsModuleRootState();
}

class _MapsModuleRootState extends State<_MapsModuleRoot> {
  // ── Servicios compartidos ─────────────────────────────────────────────────
  late final RelojNTPService _relojNTP;
  late final CapasStateService _capasState;
  late final MapaRenderService _renderService;
  late final ColaSincronizacionService _colaSincronizacion;

  // ── Repositorios ──────────────────────────────────────────────────────────
  late final RedElectricaRepository _redRepo;
  late final AlarmaRepository _alarmaRepo;
  late final TareaRepository _tareaRepo;
  late final IncidenciaRepository _incidenciaRepo;

  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    _relojNTP = RelojNTPService();
    _capasState = CapasStateService();
    _renderService = const MapaRenderService();
    _redRepo = RedElectricaRepository();
    _alarmaRepo = AlarmaRepository();
    _tareaRepo = TareaRepository();
    _incidenciaRepo = IncidenciaRepository();

    _colaSincronizacion = ColaSincronizacionService(
      incidenciaRepo: _incidenciaRepo,
      onFalloPersistente: (_) {
        // Notificación al Operario manejada por el servicio
      },
    );

    // Inicializar servicios en paralelo
    await Future.wait([
      _relojNTP.inicializar(),
      _capasState.cargarEstado(),
    ]);

    // Sincronizar NTP en background (no bloquear la UI)
    _relojNTP.sincronizarConNTP().ignore();

    // Iniciar cola de sincronización offline
    _colaSincronizacion.iniciar();

    if (mounted) setState(() => _inicializado = true);
  }

  @override
  void dispose() {
    _capasState.dispose();
    _colaSincronizacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_inicializado) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Req. 4.6: si hay initialTaskId, navegar directamente a NavegacionTareaWidget
    if (widget.initialTaskId != null) {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Trazado Eléctrico')),
          body: NavegacionTareaWidget(
            tareaId: widget.initialTaskId!,
            relojNTP: _relojNTP,
            tareaRepo: _tareaRepo,
            redRepo: _redRepo,
            supabase: Supabase.instance.client,
          ),
        ),
      );
    }

    // Router por rol
    return MaterialApp(
      title: 'Trazado Eléctrico',
      initialRoute: '/',
      onGenerateRoute: (settings) => _generarRuta(settings),
    );
  }

  Route<dynamic>? _generarRuta(RouteSettings settings) {
    final esCoordinador = widget.userContext.rol == UserRole.coordinador;

    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => _PantallaInicio(
          userContext: widget.userContext,
          capasState: _capasState,
          renderService: _renderService,
          colaSincronizacion: _colaSincronizacion,
          esCoordinador: esCoordinador,
        ));

      case '/alarmas':
        if (!esCoordinador) return _rutaBloqueada();
        return MaterialPageRoute(builder: (_) => GestionAlarmasView(
          coordinadorId: widget.userContext.userId,
          alarmaRepo: _alarmaRepo,
          relojNTP: _relojNTP,
        ));

      case '/despacho':
        if (!esCoordinador) return _rutaBloqueada();
        final alarmaId = settings.arguments as int? ?? 0;
        return MaterialPageRoute(builder: (_) => DespachoTareasView(
          coordinadorId: widget.userContext.userId,
          alarmaId: alarmaId,
          tareaRepo: _tareaRepo,
          relojNTP: _relojNTP,
          capasStateService: _capasState,
          renderService: _renderService,
          pgTileservBaseUrl: _kPgTileservBaseUrl,
        ));

      case '/monitor':
        if (!esCoordinador) return _rutaBloqueada();
        return MaterialPageRoute(builder: (_) => MonitorCuadrillasView(
          supabase: Supabase.instance.client,
        ));

      default:
        return MaterialPageRoute(builder: (_) => const Scaffold(
          body: Center(child: Text('Ruta no encontrada')),
        ));
    }
  }

  /// Ruta bloqueada para operarios que intentan acceder a vistas de Coordinador.
  /// Requerimiento: router interno bloquea rutas no autorizadas.
  Route<dynamic> _rutaBloqueada() {
    return MaterialPageRoute(builder: (_) => const Scaffold(
      body: Center(child: Text('Acceso no autorizado.')),
    ));
  }
}

/// Pantalla de inicio del módulo con mapa y controles.
class _PantallaInicio extends StatelessWidget {
  final UserContext userContext;
  final CapasStateService capasState;
  final MapaRenderService renderService;
  final ColaSincronizacionService colaSincronizacion;
  final bool esCoordinador;

  const _PantallaInicio({
    required this.userContext,
    required this.capasState,
    required this.renderService,
    required this.colaSincronizacion,
    required this.esCoordinador,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trazado Eléctrico — ${userContext.nombre}'),
        actions: [
          // Contador de incidencias pendientes — Req. 7.3
          StreamBuilder<int>(
            stream: colaSincronizacion.pendientesStream,
            builder: (context, snap) {
              final pendientes = snap.data ?? 0;
              if (pendientes == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Badge(
                  label: Text('$pendientes'),
                  child: const Icon(Icons.cloud_upload_outlined),
                ),
              );
            },
          ),
          // Menú del Coordinador
          if (esCoordinador)
            PopupMenuButton<String>(
              onSelected: (route) => Navigator.pushNamed(context, route),
              itemBuilder: (_) => const [
                PopupMenuItem(value: '/alarmas', child: Text('Gestión de Alarmas')),
                PopupMenuItem(value: '/despacho', child: Text('Despacho de Tareas')),
                PopupMenuItem(value: '/monitor', child: Text('Monitor de Cuadrillas')),
              ],
            ),
        ],
      ),
      body: Stack(children: [
        MapaInteractivoWidget(
          pgTileservBaseUrl: _kPgTileservBaseUrl,
          capasStateService: capasState,
          renderService: renderService,
        ),
        Positioned(
          top: 8, right: 8,
          child: ControlCapasWidget(capasStateService: capasState),
        ),
      ]),
    );
  }
}
