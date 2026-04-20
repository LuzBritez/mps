import 'package:flutter/material.dart';
import '../services/capas_state_service.dart';
import '../models/estado_capas.dart';

/// Widget con tres toggles independientes para controlar la visibilidad
/// de las capas del mapa: LMT, Setas y Barrios.
///
/// Conectado a [CapasStateService] para persistir el estado entre sesiones.
///
/// Requerimientos: 2.1–2.5
class ControlCapasWidget extends StatefulWidget {
  final CapasStateService capasStateService;

  const ControlCapasWidget({
    super.key,
    required this.capasStateService,
  });

  @override
  State<ControlCapasWidget> createState() => _ControlCapasWidgetState();
}

class _ControlCapasWidgetState extends State<ControlCapasWidget> {
  late EstadoCapas _estado;

  @override
  void initState() {
    super.initState();
    _estado = widget.capasStateService.estado;
    widget.capasStateService.stream.listen((nuevoEstado) {
      if (mounted) setState(() => _estado = nuevoEstado);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CapaToggle(
              label: 'LMT',
              value: _estado.lmtVisible,
              onChanged: (_) => widget.capasStateService.toggleLmt(),
            ),
            _CapaToggle(
              label: 'Setas',
              value: _estado.setasVisible,
              onChanged: (_) => widget.capasStateService.toggleSetas(),
            ),
            _CapaToggle(
              label: 'Barrios',
              value: _estado.barriosVisible,
              onChanged: (_) => widget.capasStateService.toggleBarrios(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapaToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CapaToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
