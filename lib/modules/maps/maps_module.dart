import 'package:flutter/material.dart';

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

const String _kPgTileservBaseUrl = String.fromEnvironment(
  'PG_TILESERV_URL',
  defaultValue: 'http://localhost:7800',
);

class MapsModule {
  MapsModule._();

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
  late final RelojNTPService _relojNTP;
  late final CapasStateService _capasState;
  late final MapaRenderService _renderService;
  late final ColaSincronizacionService _colaSincronizacion;
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
      onFalloPersistente: (_) {},
    );

    await Future.wait([
      _relojNTP.inicializar(),
      _capasState.cargarEstado(),
    ]);

    _relojNTP.sincronizarConNTP().ignore();
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

    final esCoordinador = widget.userContext.rol == UserRole.coordinador;

    // Req. 4.6: si hay initialTaskId, ir directo a la tarea
    if (widget.initialTaskId != null) {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Trazado Eléctrico')),
          body: NavegacionTareaWidget(
            tareaId: widget.initialTaskId!,
            relojNTP: _relojNTP,
            tareaRepo: _tareaRepo,
            redRepo: _redRepo,
          ),
        ),
        routes: _buildRoutes(esCoordinador),
      );
    }

    return MaterialApp(
      title: 'Trazado Eléctrico',
      home: _PantallaInicio(
        userContext: widget.userContext,
        capasState: _capasState,
        renderService: _renderService,
        colaSincronizacion: _colaSincronizacion,
        esCoordinador: esCoordinador,
      ),
      routes: _buildRoutes(esCoordinador),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes(bool esCoordinador) {
    return {
      '/alarmas': (_) => esCoordinador
          ? GestionAlarmasView(
              coordinadorId: widget.userContext.userId,
              alarmaRepo: _alarmaRepo,
              relojNTP: _relojNTP,
            )
          : const Scaffold(body: Center(child: Text('Acceso no autorizado.'))),
      '/despacho': (_) => esCoordinador
          ? DespachoTareasView(
              coordinadorId: widget.userContext.userId,
              alarmaId: 0,
              tareaRepo: _tareaRepo,
              relojNTP: _relojNTP,
              capasStateService: _capasState,
              renderService: _renderService,
              pgTileservBaseUrl: _kPgTileservBaseUrl,
            )
          : const Scaffold(body: Center(child: Text('Acceso no autorizado.'))),
      '/monitor': (_) => esCoordinador
          ? const MonitorCuadrillasView()
          : const Scaffold(body: Center(child: Text('Acceso no autorizado.'))),
    };
  }
}

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
      body: Stack(
        children: [
          MapaInteractivoWidget(
            pgTileservBaseUrl: _kPgTileservBaseUrl,
            capasStateService: capasState,
            renderService: renderService,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: ControlCapasWidget(capasStateService: capasState),
          ),
        ],
      ),
    );
  }
}
