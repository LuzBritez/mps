import 'package:flutter/material.dart';

import '../models/models.dart';
import '../repositories/alarma_repository.dart';
import '../services/reloj_ntp_service.dart';

/// Vista de gestión de alarmas — exclusiva del Coordinador.
///
/// Requerimientos: 3.1–3.5, 8.8
class GestionAlarmasView extends StatefulWidget {
  final int coordinadorId;
  final AlarmaRepository alarmaRepo;
  final RelojNTPService relojNTP;

  const GestionAlarmasView({
    super.key,
    required this.coordinadorId,
    required this.alarmaRepo,
    required this.relojNTP,
  });

  @override
  State<GestionAlarmasView> createState() => _GestionAlarmasViewState();
}

class _GestionAlarmasViewState extends State<GestionAlarmasView> {
  List<Alarma> _alarmas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarAlarmas();
  }

  Future<void> _cargarAlarmas() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final alarmas = await widget.alarmaRepo.listarAlarmasActivas();
      if (mounted) setState(() { _alarmas = alarmas; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error al cargar alarmas: $e'; _cargando = false; });
    }
  }

  Future<void> _crearAlarma() async {
    final result = await showDialog<_DatosAlarma>(
      context: context,
      builder: (_) => const _DialogCrearAlarma(),
    );
    if (result == null) return;

    try {
      await widget.alarmaRepo.crearAlarma(
        lmtId: result.lmtId,
        zonaDesc: result.zonaDesc,
        creadaPor: widget.coordinadorId,
        tiempoVerdadero: widget.relojNTP.tiempoVerdadero(),
        tiempoDispositivo: widget.relojNTP.tiempoDispositivo(),
      );
      await _cargarAlarmas();
    } on AlarmaLmtInexistenteException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear alarma: $e')));
      }
    }
  }

  Future<void> _cerrarAlarma(int alarmaId) async {
    try {
      await widget.alarmaRepo.cerrarAlarma(
        alarmaId: alarmaId,
        tiempoVerdadero: widget.relojNTP.tiempoVerdadero(),
        tiempoDispositivo: widget.relojNTP.tiempoDispositivo(),
      );
      await _cargarAlarmas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cerrar alarma: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Alarmas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarAlarmas),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearAlarma,
        icon: const Icon(Icons.add_alert),
        label: const Text('Nueva alarma'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!), const SizedBox(height: 12),
        OutlinedButton(onPressed: _cargarAlarmas, child: const Text('Reintentar')),
      ]));
    }
    if (_alarmas.isEmpty) {
      return const Center(child: Text('No hay alarmas activas.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _alarmas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final alarma = _alarmas[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            title: Text('Alarma #${alarma.id}'),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (alarma.lmtId != null) Text('LMT: ${alarma.lmtId}'),
              if (alarma.zonaDesc != null) Text(alarma.zonaDesc!),
              Text('Creada: ${_formatFecha(alarma.creadaEn)}', style: Theme.of(context).textTheme.bodySmall),
            ]),
            trailing: TextButton(
              onPressed: () => _cerrarAlarma(alarma.id),
              child: const Text('Cerrar'),
            ),
          ),
        );
      },
    );
  }

  String _formatFecha(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _DatosAlarma {
  final int? lmtId;
  final String? zonaDesc;
  const _DatosAlarma({this.lmtId, this.zonaDesc});
}

class _DialogCrearAlarma extends StatefulWidget {
  const _DialogCrearAlarma();

  @override
  State<_DialogCrearAlarma> createState() => _DialogCrearAlarmaState();
}

class _DialogCrearAlarmaState extends State<_DialogCrearAlarma> {
  final _lmtController = TextEditingController();
  final _zonaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _lmtController.dispose();
    _zonaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Alarma'),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _lmtController,
            decoration: const InputDecoration(labelText: 'ID de LMT (opcional)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _zonaController,
            decoration: const InputDecoration(labelText: 'Descripción de zona', border: OutlineInputBorder()),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final lmtId = int.tryParse(_lmtController.text.trim());
            final zonaDesc = _zonaController.text.trim().isEmpty ? null : _zonaController.text.trim();
            Navigator.pop(context, _DatosAlarma(lmtId: lmtId, zonaDesc: zonaDesc));
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
