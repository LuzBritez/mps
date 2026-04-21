import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/enums.dart';
import '../models/estado_capas.dart';
import '../services/capas_state_service.dart';
import '../services/mapa_render_service.dart';

// Constantes a nivel de archivo para que _InfoFeatureSheet pueda referenciarlas.
const _fuenteLmt = 'fuente-lmt';
const _fuenteSetas = 'fuente-setas';
const _fuenteBarrios = 'fuente-barrios';
const _fuenteSeccionamientos = 'fuente-seccionamientos';
const _fuenteCdn = 'fuente-cdn';

const _capaLmt = 'capa-lmt';
const _capaSetas = 'capa-setas';
const _capaSetasCluster = 'capa-setas-cluster';
const _capaSetasClusterCount = 'capa-setas-cluster-count';
const _capaBarrios = 'capa-barrios';
const _capaSeccionamientos = 'capa-seccionamientos';
const _capaCdn = 'capa-cdn';
const _capaCdnContorno = 'capa-cdn-contorno';
const _capaLmtHitArea = 'capa-lmt-hit';

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

  static const _latitudInicial = -26.1833;
  static const _longitudInicial = -58.1731;
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

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    _mostrarInfoFeature(point, layerId);
  }

  Future<void> _mostrarInfoFeature(Point<double> point, String layerId) async {
    final ctrl = _controller;
    if (ctrl == null || !mounted) return;

    const layerToSource = {
      _capaLmt: _fuenteLmt,
      _capaLmtHitArea: _fuenteLmt,
      _capaSetas: _fuenteSetas,
      _capaSeccionamientos: _fuenteSeccionamientos,
      _capaCdn: _fuenteCdn,
      _capaCdnContorno: _fuenteCdn,
    };

    final source = layerToSource[layerId];
    if (source == null) return;

    final rect = Rect.fromCenter(
      center: Offset(point.x, point.y),
      width: 44,
      height: 44,
    );
    final features = await ctrl.queryRenderedFeaturesInRect(rect, [layerId], null);
    if (features.isEmpty || !mounted) return;

    final rawProps = features.first['properties'];
    final props = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : <String, dynamic>{};

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _InfoFeatureSheet(source: source, properties: props),
    );
  }

  Future<void> _agregarFuentes() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    final lmtJson = jsonDecode(await rootBundle.loadString('datos/lmt.geojson'))
        as Map<String, dynamic>;
    await ctrl.addGeoJsonSource(_fuenteLmt, lmtJson);

    final setasJson = jsonDecode(await rootBundle.loadString('datos/setas.geojson'))
        as Map<String, dynamic>;
    await ctrl.addGeoJsonSource(_fuenteSetas, setasJson);

    final barriosJson = jsonDecode(
      await rootBundle.loadString('datos/barrios.geojson'),
    ) as Map<String, dynamic>;
    await ctrl.addGeoJsonSource(_fuenteBarrios, barriosJson);

    final seccJson = jsonDecode(
      await rootBundle.loadString('datos/seccionamientos.geojson'),
    ) as Map<String, dynamic>;
    await ctrl.addGeoJsonSource(_fuenteSeccionamientos, seccJson);

    final cdnJson = jsonDecode(
      await rootBundle.loadString('datos/centro de distribucion.geojson'),
    ) as Map<String, dynamic>;
    await ctrl.addGeoJsonSource(_fuenteCdn, cdnJson);
  }

  Future<void> _agregarCapas() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    // Barrios — polígonos semitransparentes — Requerimiento 1.6
    await ctrl.addFillLayer(
      _fuenteBarrios,
      _capaBarrios,
      const FillLayerProperties(fillColor: '#4488FF', fillOpacity: 0.3),
    );

    // CDN — relleno + contorno para mayor visibilidad
    await ctrl.addFillLayer(
      _fuenteCdn,
      _capaCdn,
      const FillLayerProperties(fillColor: '#E53935', fillOpacity: 0.7),
    );
    await ctrl.addLineLayer(
      _fuenteCdn,
      _capaCdnContorno,
      const LineLayerProperties(lineColor: '#B71C1C', lineWidth: 4.5),
    );

    // LMT — líneas desde GeoJSON asset — Requerimiento 1.4
    await ctrl.addLineLayer(
      _fuenteLmt,
      _capaLmt,
      const LineLayerProperties(lineColor: '#FF9800', lineWidth: 2.0),
    );
    // Hit area invisible para facilitar el tap en líneas delgadas
    await ctrl.addLineLayer(
      _fuenteLmt,
      _capaLmtHitArea,
      const LineLayerProperties(lineOpacity: 0.0, lineWidth: 20.0),
    );

    // Setas — círculos desde GeoJSON asset — Requerimiento 1.5
    await ctrl.addCircleLayer(
      _fuenteSetas,
      _capaSetas,
      const CircleLayerProperties(
        circleColor: '#1E88E5',
        circleRadius: ['interpolate', ['linear'], ['zoom'], 10, 2.0, 13, 5.0, 16, 8.0],
      ),
    );

    // Seccionamientos — círculos desde GeoJSON asset
    await ctrl.addCircleLayer(
      _fuenteSeccionamientos,
      _capaSeccionamientos,
      const CircleLayerProperties(
        circleColor: '#43A047',
        circleRadius: ['interpolate', ['linear'], ['zoom'], 10, 2.0, 13, 5.0, 16, 8.0],
      ),
    );
  }

  Future<void> _aplicarVisibilidad(EstadoCapas estado) async {
    await _setLayerVisibility(_capaLmt, estado.lmtVisible);
    await _setLayerVisibility(_capaLmtHitArea, estado.lmtVisible);
    await _setLayerVisibility(_capaSetas, estado.setasVisible);
    await _setLayerVisibility(_capaSetasCluster, estado.setasVisible);
    await _setLayerVisibility(_capaSetasClusterCount, estado.setasVisible);
    await _setLayerVisibility(_capaBarrios, estado.barriosVisible);
    await _setLayerVisibility(_capaSeccionamientos, estado.seccionamientosVisible);
    await _setLayerVisibility(_capaCdn, estado.cdnVisible);
    await _setLayerVisibility(_capaCdnContorno, estado.cdnVisible);
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

// ---------------------------------------------------------------------------
// Bottom sheet de información de elemento
// ---------------------------------------------------------------------------

class _InfoFeatureSheet extends StatelessWidget {
  final String source;
  final Map<String, dynamic> properties;

  const _InfoFeatureSheet({required this.source, required this.properties});

  String _val(String key) {
    final v = properties[key];
    if (v == null) return '-';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final (titulo, icono, color, filas) = _contenido();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manija
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Encabezado
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20),
          // Filas de datos
          ...filas.map((f) => _FilaDato(label: f.$1, value: f.$2)),
        ],
      ),
    );
  }

  (String, IconData, Color, List<(String, String)>) _contenido() {
    return switch (source) {
      _fuenteSetas => (
          'Transformador',
          Icons.electrical_services,
          const Color(0xFF1E88E5),
          [
            ('N° de seta', _val('seta nº')),
            ('Potencia', '${_val('pot. (kva)')} kVA'),
            ('ID', _val('id')),
          ],
        ),
      _fuenteSeccionamientos => (
          'Seccionamiento',
          Icons.power,
          const Color(0xFF43A047),
          [
            ('Número', _val('numero')),
            ('Tipo', _val('tipo secc.')),
            ('Tensión', '${_val('tension')} kV'),
            ('Localidad', _val('LOCALIDAD')),
            ('Ubicación', _val('ubicacion')),
          ],
        ),
      _fuenteCdn => (
          'Centro de Distribución',
          Icons.account_balance,
          const Color(0xFFE53935),
          [
            ('Centro', _val('CENTRO DE DISTRIBUCION')),
            ('Localidad', _val('LOCALIDAD')),
            ('Potencia instalada', '${_val('POTENCIA INSTALADA (KVA)')} kVA'),
            ('Ubicación', _val('UBICACION')),
          ],
        ),
      _fuenteLmt => (
          'Línea de Media Tensión',
          Icons.cable,
          const Color(0xFFFF9800),
          [
            ('ID', _val('id')),
            ('Localidad', _val('localidad')),
          ],
        ),
      _ => (
          'Elemento',
          Icons.info_outline,
          Colors.grey,
          <(String, String)>[],
        ),
    };
  }
}

class _FilaDato extends StatelessWidget {
  final String label;
  final String value;

  const _FilaDato({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
