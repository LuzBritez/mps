import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/enums.dart';
import '../models/incidencia_local.dart';
import '../repositories/incidencia_repository.dart';
import '../services/reloj_ntp_service.dart';

/// Widget de formulario para registrar una incidencia sobre un elemento
/// de la red eléctrica (LMT o Seta).
///
/// Requerimientos: 6.1–6.10, 8.6, 8.10, 8.11
class RegistroIncidenciaWidget extends StatefulWidget {
  /// ID de la tarea activa en curso.
  final int tareaId;

  /// ID del operario que registra la incidencia (del UserContext).
  final int operarioId;

  /// ID del elemento afectado: lmt_id o seta_id.
  final int elementoId;

  /// Tipo de elemento seleccionado en el mapa.
  final TipoElemento tipoElemento;

  /// Coordenadas geográficas del elemento afectado.
  final LatLng coordenadas;

  /// Servicio de tiempo NTP para timestamps confiables. Req. 8.6
  final RelojNTPService relojNTP;

  /// Repositorio de incidencias para persistencia offline/online. Req. 7.1
  final IncidenciaRepository incidenciaRepo;

  /// Callback invocado tras registrar la incidencia exitosamente.
  final VoidCallback? onIncidenciaRegistrada;

  const RegistroIncidenciaWidget({
    super.key,
    required this.tareaId,
    required this.operarioId,
    required this.elementoId,
    required this.tipoElemento,
    required this.coordenadas,
    required this.relojNTP,
    required this.incidenciaRepo,
    this.onIncidenciaRegistrada,
  });

  @override
  State<RegistroIncidenciaWidget> createState() =>
      _RegistroIncidenciaWidgetState();
}

class _RegistroIncidenciaWidgetState extends State<RegistroIncidenciaWidget> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();

  String? _categoriaSeleccionada;
  String? _imagenPath;
  bool _enviando = false;
  bool _camaraDenegada = false;

  /// El botón de envío está habilitado solo cuando categoría y descripción
  /// son válidas. Req. 6.2, 6.3
  bool get _puedeEnviar {
    final descripcion = _descripcionController.text;
    return _categoriaSeleccionada != null &&
        descripcion.trim().isNotEmpty &&
        !_enviando;
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  // ── Captura de imagen ─────────────────────────────────────────────────────

  /// Solicita permiso de cámara y captura una imagen. Req. 6.6, 6.7
  Future<void> _capturarImagen() async {
    final picker = ImagePicker();

    try {
      final imagen = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (imagen != null) {
        setState(() {
          _imagenPath = imagen.path;
          _camaraDenegada = false;
        });
      }
    } on Exception catch (e) {
      // image_picker lanza una excepción cuando el permiso es denegado
      // o cuando el usuario cancela. Distinguimos por mensaje.
      final mensaje = e.toString().toLowerCase();
      final esDenegado = mensaje.contains('denied') ||
          mensaje.contains('permission') ||
          mensaje.contains('access');

      if (esDenegado) {
        setState(() => _camaraDenegada = true);
        if (mounted) {
          _mostrarMensajeCamaraDenegada();
        }
      }
      // Si el usuario simplemente canceló, no hacemos nada.
    }
  }

  /// Muestra un SnackBar informativo cuando el permiso de cámara es denegado.
  /// Req. 6.7: informar pero permitir continuar sin imagen.
  void _mostrarMensajeCamaraDenegada() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Permiso de cámara denegado. '
          'Podés continuar el registro sin imagen.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ── Envío del formulario ──────────────────────────────────────────────────

  /// Construye y persiste la incidencia usando timestamps de RelojNTPService.
  /// Req. 6.4, 8.6, 8.10, 8.11
  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate() || !_puedeEnviar) return;

    setState(() => _enviando = true);

    try {
      // Req. 8.6: usar RelojNTPService, nunca DateTime.now() directo.
      final tiempoVerdadero = widget.relojNTP.tiempoVerdadero();
      final tiempoDispositivo = widget.relojNTP.tiempoDispositivo();

      // Req. 8.11: detectar posible manipulación del reloj.
      final posibleManipulacion = widget.relojNTP.posibleManipulacionReloj;

      // Req. 8.5: marcar si no hubo sincronización NTP en la sesión.
      final tiempoNoVerificado = widget.relojNTP.tiempoNoVerificado;

      final incidencia = IncidenciaLocal(
        tareaId: widget.tareaId,
        operarioId: widget.operarioId,
        elementoId: widget.elementoId,
        tipoElemento: widget.tipoElemento.name,
        categoria: _categoriaSeleccionada!,
        descripcion: _descripcionController.text.trim(),
        coordenadas: widget.coordenadas,
        imagenPath: _imagenPath,
        tiempoVerdadero: tiempoVerdadero,
        tiempoDispositivo: tiempoDispositivo,
        posibleManipulacionReloj: posibleManipulacion,
        tiempoNoVerificado: tiempoNoVerificado,
      );

      // Req. 7.1: persistencia offline vía IncidenciaRepository.
      await widget.incidenciaRepo.persistirIncidencia(incidencia);

      widget.onIncidenciaRegistrada?.call();
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SelectorCategoria(
            valor: _categoriaSeleccionada,
            onChanged: (v) => setState(() => _categoriaSeleccionada = v),
          ),
          const SizedBox(height: 16),
          _CampoDescripcion(
            controller: _descripcionController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _SeccionImagen(
            imagenPath: _imagenPath,
            camaraDenegada: _camaraDenegada,
            onCapturar: _capturarImagen,
            onEliminar: () => setState(() => _imagenPath = null),
          ),
          const SizedBox(height: 24),
          _BotonEnviar(
            habilitado: _puedeEnviar,
            enviando: _enviando,
            onPressed: _enviar,
          ),
        ],
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

/// Selector desplegable de categoría de incidencia.
/// Req. 6.2: 7 categorías obligatorias.
class _SelectorCategoria extends StatelessWidget {
  final String? valor;
  final ValueChanged<String?> onChanged;

  const _SelectorCategoria({required this.valor, required this.onChanged});

  static const _etiquetas = <String, String>{
    CategoriasIncidencia.arbolCaido: 'Árbol caído',
    CategoriasIncidencia.ramaTocandoCable: 'Rama tocando cable',
    CategoriasIncidencia.posteCaido: 'Poste caído',
    CategoriasIncidencia.cableCortado: 'Cable cortado',
    CategoriasIncidencia.cableChispeando: 'Cable chispeando',
    CategoriasIncidencia.notaMantenimiento: 'Nota de mantenimiento',
    CategoriasIncidencia.danoVisible: 'Daño visible',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      decoration: const InputDecoration(
        labelText: 'Categoría *',
        border: OutlineInputBorder(),
      ),
      hint: const Text('Seleccioná una categoría'),
      items: CategoriasIncidencia.todas
          .map(
            (cat) => DropdownMenuItem(
              value: cat,
              child: Text(_etiquetas[cat] ?? cat),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) =>
          v == null ? 'Seleccioná una categoría para continuar.' : null,
    );
  }
}

/// Campo de texto para la descripción de la incidencia.
/// Req. 6.3: no vacío ni solo espacios.
class _CampoDescripcion extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _CampoDescripcion({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      decoration: const InputDecoration(
        labelText: 'Descripción *',
        hintText: 'Describí la incidencia observada…',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'La descripción no puede estar vacía.';
        }
        return null;
      },
    );
  }
}

/// Sección de captura de imagen opcional.
/// Req. 6.6, 6.7, 6.8, 6.9
class _SeccionImagen extends StatelessWidget {
  final String? imagenPath;
  final bool camaraDenegada;
  final VoidCallback onCapturar;
  final VoidCallback onEliminar;

  const _SeccionImagen({
    required this.imagenPath,
    required this.camaraDenegada,
    required this.onCapturar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagen (opcional)',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        if (imagenPath != null) ...[
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  imagenPath!.split('/').last,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Eliminar imagen',
                onPressed: onEliminar,
              ),
            ],
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: onCapturar,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tomar foto'),
          ),
          if (camaraDenegada)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Permiso de cámara denegado. Podés continuar sin imagen.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.orange.shade700),
              ),
            ),
        ],
      ],
    );
  }
}

/// Botón de envío del formulario.
/// Req. 6.3: deshabilitado si la descripción está vacía o la categoría no fue
/// seleccionada.
class _BotonEnviar extends StatelessWidget {
  final bool habilitado;
  final bool enviando;
  final VoidCallback onPressed;

  const _BotonEnviar({
    required this.habilitado,
    required this.enviando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: habilitado ? onPressed : null,
      child: enviando
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Registrar incidencia'),
    );
  }
}
