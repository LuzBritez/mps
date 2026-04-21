import 'package:flutter/material.dart';

import '../models/models.dart';
import '../repositories/red_electrica_repository.dart';
import '../repositories/tarea_repository.dart';
import '../services/api_client.dart';
import '../services/reloj_ntp_service.dart';

/// Widget de navegación de tarea asignada.
/// Requerimientos: 5.1–5.6, 7.5, 8.7
class NavegacionTareaWidget extends StatefulWidget {
  final int tareaId;
  final RelojNTPService relojNTP;
  final TareaRepository tareaRepo;
  final RedElectricaRepository redRepo;
  final void Function(int lmtId)? onLmtResaltar;

  const NavegacionTareaWidget({
    super.key,
    required this.tareaId,
    required this.relojNTP,
    required this.tareaRepo,
    required this.redRepo,
    this.onLmtResaltar,
  });

  @override
  State<NavegacionTareaWidget> createState() => _NavegacionTareaWidgetState();
}

class _NavegacionTareaWidgetState extends State<NavegacionTareaWidget> {
  Tarea? _tarea;
  List<Nodo> _nodos = [];
  final Map<int, ProgresoNodo> _progreso = {};
  bool _cargando = true;
  String? _error;
  bool _completando = false;

  @override
  void initState() {
    super.initState();
    _cargarTarea();
  }

  Future<void> _cargarTarea() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final tarea = await widget.tareaRepo.obtenerTarea(widget.tareaId);
      List<Nodo> nodos = [];
      if (tarea.lmtId != null) {
        final todos = await widget.redRepo.getNodosByLmtId(tarea.lmtId!);
        final ordenMap = { for (var i = 0; i < tarea.rutaNodoIds.length; i++) tarea.rutaNodoIds[i]: i };
        nodos = todos.where((n) => ordenMap.containsKey(n.id)).toList()
          ..sort((a, b) => ordenMap[a.id]!.compareTo(ordenMap[b.id]!));
      }

      // Cargar progreso desde PostgREST
      final rows = await apiClient.select('progreso_nodos', filters: {
        'tarea_id': 'eq.${widget.tareaId}',
      });
      final progresoMap = <int, ProgresoNodo>{};
      for (final row in rows) {
        final nodoId = (row['nodo_id'] as num).toInt();
        progresoMap[nodoId] = ProgresoNodo(
          tareaId: widget.tareaId,
          nodoId: nodoId,
          inspeccionado: (row['inspeccionado'] as bool?) ?? false,
          inspeccionadoEn: row['inspeccionado_en'] != null ? DateTime.parse(row['inspeccionado_en'] as String) : null,
          tiempoVerdadero: row['tiempo_verdadero'] != null ? DateTime.parse(row['tiempo_verdadero'] as String) : null,
          tiempoDispositivo: row['tiempo_dispositivo'] != null ? DateTime.parse(row['tiempo_dispositivo'] as String) : null,
        );
      }
      if (mounted) {
        setState(() { _tarea = tarea; _nodos = nodos; _progreso..clear()..addAll(progresoMap); _cargando = false; });
        if (tarea.lmtId != null) widget.onLmtResaltar?.call(tarea.lmtId!);
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error al cargar la tarea: $e'; _cargando = false; });
    }
  }

  Future<void> _marcarNodo(int nodoId) async {
    final tv = widget.relojNTP.tiempoVerdadero();
    final td = widget.relojNTP.tiempoDispositivo();
    setState(() {
      _progreso[nodoId] = ProgresoNodo(tareaId: widget.tareaId, nodoId: nodoId, inspeccionado: true, inspeccionadoEn: tv, tiempoVerdadero: tv, tiempoDispositivo: td);
    });
    try {
      await apiClient.upsert('progreso_nodos', {
        'tarea_id': widget.tareaId, 'nodo_id': nodoId, 'inspeccionado': true,
        'inspeccionado_en': tv.toUtc().toIso8601String(),
        'tiempo_verdadero': tv.toUtc().toIso8601String(),
        'tiempo_dispositivo': td.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  bool get _todosInspeccionados => _nodos.isNotEmpty && _nodos.every((n) => _progreso[n.id]?.inspeccionado == true);

  Future<void> _completarTarea() async {
    if (!_todosInspeccionados || _completando) return;
    setState(() => _completando = true);
    try {
      await widget.tareaRepo.actualizarEstadoTarea(widget.tareaId, EstadoTarea.completada);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarea completada exitosamente.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _completando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!), const SizedBox(height: 12),
        OutlinedButton(onPressed: _cargarTarea, child: const Text('Reintentar')),
      ]));
    }
    final tarea = _tarea!;
    final completada = tarea.estado == EstadoTarea.completada;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Tarea #${tarea.id}', style: Theme.of(context).textTheme.titleMedium)),
      const Divider(height: 1),
      Expanded(child: ListView.builder(
        itemCount: _nodos.length,
        itemBuilder: (context, i) {
          final nodo = _nodos[i];
          final inspeccionado = _progreso[nodo.id]?.inspeccionado ?? false;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: inspeccionado ? Colors.green : Colors.grey.shade300,
              child: inspeccionado ? const Icon(Icons.check, color: Colors.white, size: 18) : Text('${nodo.id}', style: const TextStyle(fontSize: 12)),
            ),
            title: Text('Nodo #${nodo.id} — ${nodo.nombre}'),
            subtitle: Text('Lat: ${nodo.coordenadas.latitude.toStringAsFixed(5)}, Lng: ${nodo.coordenadas.longitude.toStringAsFixed(5)}', style: Theme.of(context).textTheme.bodySmall),
            trailing: (!inspeccionado && !completada) ? TextButton(onPressed: () => _marcarNodo(nodo.id), child: const Text('Marcar')) : null,
          );
        },
      )),
      const Divider(height: 1),
      if (!completada)
        Padding(padding: const EdgeInsets.all(16), child: FilledButton.icon(
          onPressed: _todosInspeccionados && !_completando ? _completarTarea : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Completar tarea'),
        ))
      else
        Container(color: Colors.green.shade50, padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text('Tarea completada', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
          ])),
    ]);
  }
}
