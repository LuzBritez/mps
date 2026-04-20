import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/models.dart';
import '../repositories/tarea_repository.dart';
import '../services/capas_state_service.dart';
import '../services/mapa_render_service.dart';
import '../services/reloj_ntp_service.dart';
import '../widgets/mapa_interactivo_widget.dart';

/// Vista de despacho de tareas — exclusiva del Coordinador.
///
/// Permite seleccionar operario/cuadrilla, trazar una ruta sobre el mapa,
/// validar intersección con LMT y despachar la tarea.
///
/// Requerimientos: 4.1–4.5, 8.9
class DespachoTareasView extends StatefulWidget {
  final int coordinadorId;
  final int alarmaId;
  final TareaRepository tareaRepo;
  final RelojNTPService relojNTP;
  final CapasStateService capasStateService;
  final MapaRenderService renderService;
  final String pgTileservBaseUrl;

  const DespachoTareasView({
    super.key,
    required this.coordinadorId,
    required this.alarmaId,
    required this.tareaRepo,
    required this.relojNTP,
    required this.capasStateService,
    required this.renderService,
    required this.pgTileservBaseUrl,
  });

  @override
  State<DespachoTareasView> createState() => _DespachoTareasViewState();
}

class _DespachoTareasViewState extends State<DespachoTareasView> {
  final _asignadoAController = TextEditingController();
  TipoAsignacion _tipoAsignacion = TipoAsignacion.operario;
  final List<LatLng> _rutaPuntos = [];
  bool _despachando = false;
  String? _errorValidacion;

  @override
  void dispose() {
    _asignadoAController.dispose();
    super.dispose();
  }

  bool get _puedeDespachar =>
      _asignadoAController.text.trim().isNotEmpty &&
      _rutaPuntos.length >= 2 &&
      !_despachando;

  Future<void> _despachar() async {
    final asignadoA = int.tryParse(_asignadoAController.text.trim());
    if (asignadoA == null) {
      setState(() => _errorValidacion = 'Ingresá un ID de operario/cuadrilla válido.');
      return;
    }

    setState(() { _despachando = true; _errorValidacion = null; });

    try {
      // Req. 4.3: validar intersección con LMT
      final intersecta = await widget.tareaRepo.validarInterseccionRuta(_rutaPuntos);
      if (!intersecta) {
        setState(() {
          _errorValidacion = 'La ruta trazada no intersecta ninguna LMT. Ajustá el trazado.';
          _despachando = false;
        });
        return;
      }

      // Req. 4.1, 8.9: crear tarea con timestamps NTP
      await widget.tareaRepo.crearTarea(
        alarmaId: widget.alarmaId,
        lmtId: 0, // Se determina por la intersección en el servidor
        rutaNodoIds: const [],
        asignadaA: asignadoA,
        tipoAsignacion: _tipoAsignacion,
        creadaPor: widget.coordinadorId,
        tiempoVerdadero: widget.relojNTP.tiempoVerdadero(),
        tiempoDispositivo: widget.relojNTP.tiempoDispositivo(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarea despachada exitosamente.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() { _errorValidacion = 'Error al despachar: $e'; _despachando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Despacho de Tarea')),
      body: Column(children: [
        // Formulario de asignación
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _asignadoAController,
                  decoration: const InputDecoration(labelText: 'ID Operario / Cuadrilla', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<TipoAsignacion>(
                value: _tipoAsignacion,
                items: TipoAsignacion.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _tipoAsignacion = v!),
              ),
            ]),
            if (_rutaPuntos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ruta: ${_rutaPuntos.length} puntos trazados', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_errorValidacion != null) ...[
              const SizedBox(height: 8),
              Text(_errorValidacion!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ]),
        ),
        // Mapa para trazar ruta — Req. 4.4
        Expanded(
          child: Stack(children: [
            MapaInteractivoWidget(
              pgTileservBaseUrl: widget.pgTileservBaseUrl,
              capasStateService: widget.capasStateService,
              renderService: widget.renderService,
            ),
            Positioned(
              bottom: 16, right: 16,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FloatingActionButton.small(
                  heroTag: 'limpiar_ruta',
                  onPressed: () => setState(() => _rutaPuntos.clear()),
                  tooltip: 'Limpiar ruta',
                  child: const Icon(Icons.clear),
                ),
              ]),
            ),
          ]),
        ),
        // Botón de despacho
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _puedeDespachar ? _despachar : null,
            icon: _despachando
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: const Text('Despachar tarea'),
          ),
        ),
      ]),
    );
  }
}
