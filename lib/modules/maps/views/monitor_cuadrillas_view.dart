import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Vista de monitoreo de cuadrillas — exclusiva del Coordinador.
/// Polling cada 10 segundos (sin Realtime en Docker MVP).
class MonitorCuadrillasView extends StatefulWidget {
  const MonitorCuadrillasView({super.key});

  @override
  State<MonitorCuadrillasView> createState() => _MonitorCuadrillasViewState();
}

class _MonitorCuadrillasViewState extends State<MonitorCuadrillasView> {
  List<Map<String, dynamic>> _tareas = [];
  bool _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final rows = await apiClient.select('tareas', filters: {
        'select': 'id,estado,asignada_a,tipo_asignacion,creada_en',
        'order': 'creada_en.desc',
        'limit': '50',
      });
      if (mounted) setState(() { _tareas = rows; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor de Cuadrillas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _tareas.isEmpty
              ? const Center(child: Text('No hay tareas activas.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tareas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = _tareas[i];
                    final estado = t['estado'] as String? ?? 'pendiente';
                    final color = switch (estado) {
                      'completada' => Colors.green,
                      'en_curso' => Colors.blue,
                      _ => Colors.orange,
                    };
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(Icons.assignment, color: color, size: 20),
                        ),
                        title: Text('Tarea #${t['id']}'),
                        subtitle: Text('${t['tipo_asignacion']}: ${t['asignada_a']} — $estado'),
                        trailing: Chip(
                          label: Text(estado, style: const TextStyle(fontSize: 11)),
                          backgroundColor: color.withValues(alpha: 0.12),
                          side: BorderSide(color: color),
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
