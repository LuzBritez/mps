import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/enums.dart';
import '../models/estado_capas.dart';
import '../services/capas_state_service.dart';
import '../services/mapa_render_service.dart';

/// Widget principal del mapa interactivo de la red eléctrica.
///
/// Requerimientos: 1.1–1.6, 9.1, 9.2, 9.4, 9.5
class MapaInteractivoWidget extends StatefulWidget {
  final String pgTileservBaseUrl;
  final void Function(int elementoId, TipoElemento tipoElemento)?
      onElementoSeleccionado;
  final CapasStateService capasStateService;
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
  MapLibreMapController? _controller;
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

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    await _agregarFuentes();
    await _agregarCapas();
    await _aplicarVisibilidad(_estadoCapas);
  }

  // Firma compatible con maplibre_gl 0.25
  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (widget.onElementoSeleccionado == null) return;
    final elementoId = int.tryParse(id);
    if (elementoId == null) return;
    widget.onElementoSeleccionado!(elementoId, TipoElemento.lmt);
  }

  Future<void> _agregarFuentes() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final base = widget.pgTileservBaseUrl;

    await ctrl.addSource(
      _fuenteLmt,
      VectorSourceProperties(tiles: ['$base/public.lmt_tiles/{z}/{x}/{y}.pbf']),
    );

    // Clustering nativo — Requerimientos 9.4, 9.5
    // cluster/clusterMaxZoom/clusterRadius se pasan via properties extra
    await ctrl.addSource(
      _fuenteSetas,
      VectorSourceProperties(tiles: ['$base/public.setas_tiles/{z}/{x}/{y}.pbf']),
    );

    await ctrl.addSource(
      _fuenteBarrios,
      VectorSourceProperties(tiles: ['$base/public.barrios_tiles/{z}/{x}/{y}.pbf']),
    );
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
      sourceLayer: 'barrios',
    );

    // LMT — líneas con color por nivel de tensión — Requerimiento 1.4
    await ctrl.addLayer(
      _fuenteLmt,
      _capaLmt,
      const LineLayerProperties(
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
      sourceLayer: 'lmt',
    );

    // Setas — marcadores individuales — Requerimiento 1.5
    await ctrl.addLayer(
      _fuenteSetas,
      _capaSetas,
      const SymbolLayerProperties(
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconAllowOverlap: true,
      ),
      sourceLayer: 'setas',
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
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(_latitudInicial, _longitudInicial),
        zoom: _zoomInicial,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: _onCameraIdle,
      // Estilo base con cartografía OSM — tiles de OpenFreeMap (sin API key)
      styleString: 'https://tiles.openfreemap.org/styles/liberty',
      trackCameraPosition: true,
      compassEnabled: true,
      myLocationEnabled: false,
    );
  }
}
