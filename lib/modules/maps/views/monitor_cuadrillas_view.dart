import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Vista de monitoreo en tiempo real de cuadrillas — exclusiva del Coordinador.
///
/// Se suscribe a Supabase Realtime en las tablas `tareas` e `incidencias`
/// para mostrar el estado actualizado sin polling.
///
/// Requerimientos: (Req. 5.3, Realtime)
class MonitorCuadrillasView extends StatefulWidget {
  final SupabaseClient supabase;

  const MonitorCuadrillasView({super.key, required this.supabase});

  @override
  State<MonitorCuadrillasView> createState() => _MonitorCuadrillasViewState();
}

class _MonitorCuadrillasViewState extends State<MonitorCuadrillasView> {
  final List<Map<String, dynamic>> _tareas = [];
  bool _conectado = false;
  bool _cargando = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _cargarYSuscribir();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _cargarYSuscribir() async {
    setState(() { _cargando = true; });
    try {
      final rows = await widget.supabase
          .from('tareas')
          .select('id, estado, asignada_a, tipo_asignacion, creada_en')
          .order('creada_en', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _tareas
            ..clear()
            ..addAll(List<Map<String, dynamic>>.from(rows));
          _cargando = false;
        });
      }
      _suscribirRealtime();
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _suscribirRealtime() {
    _channel?.unsubscribe();
    _channel = widget.supabase
        .channel('monitor_cuadrillas')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tareas',
          callback: (payload) {
            if (!mounted) return;
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final id = (record['id'] as num?)?.toInt();
            if (id == null) return;
            setState(() {
              final idx = _tareas.indexWhere((t) => (t['id'] as num?)?.toInt() == id);
              if (idx >= 0) {
                _tareas[idx] = Map<String, dynamic>.from(record);
              } else {
                _tareas.insert(0, Map<String, dynamic>.from(record));
              }
            });
          },
        )
        .subscribe((status, [error]) {
          if (!mounted) return;
          setState(() => _conectado = status == RealtimeSubscribeStatus.subscribed);
          // Reintento automático si se desconecta
          if (status == RealtimeSubscribeStatus.closed && error != null) {
            Future.delayed(const Duration(seconds: 3), _suscribirRealtime);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor de Cuadrillas'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_conectado ? Icons.wifi : Icons.wifi_off,
                  size: 18, color: _conectado ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(_conectado ? 'En vivo' : 'Desconectado',
                  style: TextStyle(fontSize: 12, color: _conectado ? Colors.green : Colors.red)),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarYSuscribir),
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
                    final asignadaA = t['asignada_a'];
                    final tipo = t['tipo_asignacion'] as String? ?? '';
                    return Card(
                      child: ListTile(
                        leading: _iconoEstado(estado),
                        title: Text('Tarea #${t['id']}'),
                        subtitle: Text('$tipo: $asignadaA — $estado'),
                        trailing: _chipEstado(estado),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _iconoEstado(String estado) {
    final color = switch (estado) {
      'completada' => Colors.green,
      'en_curso' => Colors.blue,
      _ => Colors.orange,
    };
    return CircleAvatar(backgroundColor: color.withOpacity(0.15),
        child: Icon(Icons.assignment, color: color, size: 20));
  }

  Widget _chipEstado(String estado) {
    final (label, color) = switch (estado) {
      'completada' => ('Completada', Colors.green),
      'en_curso' => ('En curso', Colors.blue),
      _ => ('Pendiente', Colors.orange),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
