import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/enums.dart';
import '../models/estado_capas.dart';
import '../services/capas_state_service.dart';
import '../services/mapa_render_service.dart';

/// Widget principal del mapa interactivo de la red eléctrica.
///
/// Renderiza LMT (líneas), Setas (símbolos con clustering) y Barrios
/// (polígonos semitransparentes) usando MapLibre GL con tiles vectoriales
/// servidos por pg_tileserv.
///
/// Requerimientos: 1.1–1.6, 9.1, 9.2, 9.4, 9.5
class MapaInteractivoWidget extends StatefulWidget {
  /// URL base de pg_tileserv, e.g. "http://localhost:7800"
  final String pgTileservBaseUrl;

  /// Callback invocado al tocar un elemento de la red.
  final void Function(int elementoId, TipoElemento tipoElemento)?
      onElementoSeleccionado;

  /// Servicio de estado de capas (visibilidad LMT / Setas / Barrios).
  final CapasStateService capasStateService;

  /// Servicio de renderizado (colores, iconos, clamping de zoom).
  final MapaRenderService renderService;

  const MapaInteractivoWidget({
    super.key,
    required this.pgTileservBaseUrl,
    required this.capasStateService,
    required this.renderService,
    this.onElementoSeleccionado,
  });

  @override
  State<MapaInteractivoWidget> createState() => _MapaInteractivoWidgetState();
}

class _MapaInteractivoWidgetState extends State<MapaInteractivoWidget> {
  MaplibreMapController? _controller;
  StreamSubscription<EstadoCapas>? _capasSub;
  EstadoCapas _estadoCapas = EstadoCapas.inicial;

  static const _fuenteLmt = 'fuente-lmt';
  static const _fuenteSetas = 'fuente-setas';
  static const _fuenteBarrios = 'fuente-barrios';

  static const _capaLmt = 'capa-lmt';
  static const _capaSetas = 'capa-setas';
  static const _capaSetasCluster = 'capa-setas-cluster';
  static const _capaSetasClusterCount = 'capa-setas-cluster-count';
  static const _capaBarrios = 'capa-barrios';

  // Posición inicial: Formosa, Argentina — Requerimiento 1.1
  static const _latitudInicial = -24.89;
  static const _longitudInicial = -59.98;
  static const _zoomInicial = 10.0;

  @override
  void initState() {
    super.initState();
    _estadoCapas = widget.capasStateService.estado;
    _capasSub = widget.capasStateService.stream.listen(_onEstadoCapasChanged);
  }

  @override
  void dispose() {
    _capasSub?.cancel();
    super.dispose();
  }

  void _onMapCreated(MaplibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    await _agregarFuentes();
    await _agregarCapas();
    await _aplicarVisibilidad(_estadoCapas);
  }

  void _onFeatureTapped(
    dynamic rawId,
    Point<double> point,
    LatLng coordinates,
  ) {
    if (widget.onElementoSeleccionado == null) return;
    final id = rawId is int ? rawId : int.tryParse(rawId.toString());
    if (id == null) return;
    widget.onElementoSeleccionado!(id, TipoElemento.lmt);
  }

  Future<void> _agregarFuentes() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final base = widget.pgTileservBaseUrl;

    await ctrl.addSource(_fuenteLmt, {
      'type': 'vector',
      'tiles': ['$base/public.lmt_tiles/{z}/{x}/{y}.pbf'],
    });

    // Clustering nativo — Requerimientos 9.4, 9.5
    await ctrl.addSource(_fuenteSetas, {
      'type': 'vector',
      'tiles': ['$base/public.setas_tiles/{z}/{x}/{y}.pbf'],
      'cluster': true,
      'clusterMaxZoom': 13,
      'clusterRadius': 50,
    });

    await ctrl.addSource(_fuenteBarrios, {
      'type': 'vector',
      'tiles': ['$base/public.barrios_tiles/{z}/{x}/{y}.pbf'],
    });
  }

  Future<void> _agregarCapas() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    // Barrios — polígonos semitransparentes — Requerimiento 1.6
    await ctrl.addLayer(
      _fuenteBarrios,
      _capaBarrios,
      const FillLayerProperties(
        fillColor: '#4488FF',
        fillOpacity: 0.3,
      ),
      sourceLayer: 'public.barrios_tiles',
    );

    // LMT — líneas con color por nivel de tensión — Requerimiento 1.4
    await ctrl.addLayer(
      _fuenteLmt,
      _capaLmt,
      LineLayerProperties(
        lineColor: [
          'match',
          ['get', 'nivel_tension'],
          '13.2kV', '#FF9800',
          '33kV', '#F44336',
          '66kV', '#2196F3',
          '#9E9E9E',
        ],
        lineWidth: 2.0,
      ),
      sourceLayer: 'public.lmt_tiles',
    );

    // Clusters de Setas — Requerimiento 9.4
    await ctrl.addLayer(
      _fuenteSetas,
      _capaSetasCluster,
      const CircleLayerProperties(
        circleColor: '#FF6F00',
        circleRadius: 18.0,
      ),
      sourceLayer: 'public.setas_tiles',
      filter: ['has', 'point_count'],
    );

    await ctrl.addLayer(
      _fuenteSetas,
      _capaSetasClusterCount,
      const SymbolLayerProperties(
        textField: ['{point_count_abbreviated}'],
        textSize: 12.0,
        textColor: '#FFFFFF',
      ),
      sourceLayer: 'public.setas_tiles',
      filter: ['has', 'point_count'],
    );

    // Setas individuales (zoom ≥ 14) — Requerimientos 1.5, 9.5
    await ctrl.addLayer(
      _fuenteSetas,
      _capaSetas,
      const SymbolLayerProperties(
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconAllowOverlap: true,
      ),
      sourceLayer: 'public.setas_tiles',
      filter: ['!', ['has', 'point_count']],
    );
  }

  Future<void> _aplicarVisibilidad(EstadoCapas estado) async {
    await _setLayerVisibility(_capaLmt, estado.lmtVisible);
    await _setLayerVisibility(_capaSetas, estado.setasVisible);
    await _setLayerVisibility(_capaSetasCluster, estado.setasVisible);
    await _setLayerVisibility(_capaSetasClusterCount, estado.setasVisible);
    await _setLayerVisibility(_capaBarrios, estado.barriosVisible);
  }

  Future<void> _setLayerVisibility(String layerId, bool visible) async {
    try {
      await _controller?.setLayerVisibility(layerId, visible);
    } catch (_) {}
  }

  void _onEstadoCapasChanged(EstadoCapas nuevoEstado) {
    _estadoCapas = nuevoEstado;
    _aplicarVisibilidad(nuevoEstado);
  }

  void _onCameraIdle() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final zoom = ctrl.cameraPosition?.zoom ?? _zoomInicial;
    final clamped = widget.renderService.clampZoom(zoom);
    if ((clamped - zoom).abs() > 0.01) {
      ctrl.animateCamera(CameraUpdate.zoomTo(clamped));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaplibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(_latitudInicial, _longitudInicial),
        zoom: _zoomInicial,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: _onCameraIdle,
      styleString: MaplibreStyles.empty,
      trackCameraPosition: true,
      compassEnabled: true,
      myLocationEnabled: false,
    );
  }
}
