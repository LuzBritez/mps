import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Widget de edición geométrica superpuesto sobre el mapa.
///
/// Usa [CustomPaint] para trazar geometrías sin afectar los tiles subyacentes.
/// Persiste cada edición en la tabla SQLite `ediciones_locales` antes de
/// confirmar al usuario.
///
/// Requerimientos: 9.8, 9.9
class CanvasEdicionWidget extends StatefulWidget {
  /// Widget del mapa sobre el que se superpone el canvas.
  final Widget mapaWidget;

  const CanvasEdicionWidget({
    super.key,
    required this.mapaWidget,
  });

  @override
  State<CanvasEdicionWidget> createState() => _CanvasEdicionWidgetState();
}

class _CanvasEdicionWidgetState extends State<CanvasEdicionWidget> {
  final List<Offset> _puntos = [];
  Database? _db;

  static const _dbName = 'maps_offline.db';

  static const _kCreateEdicionesLocales = '''
    CREATE TABLE IF NOT EXISTS ediciones_locales (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      tipo         TEXT NOT NULL,
      geometria    BLOB NOT NULL,
      atributos    TEXT NOT NULL,
      creada_en    TEXT NOT NULL,
      sincronizada INTEGER NOT NULL DEFAULT 0
    )
  ''';

  @override
  void initState() {
    super.initState();
    _abrirDb();
  }

  Future<Database> _abrirDb() async {
    _db ??= await openDatabase(
      _dbName,
      version: 1,
      onCreate: (db, _) => db.execute(_kCreateEdicionesLocales),
      onOpen: (db) async {
        // Asegurar que la tabla exista si la DB fue creada por otro servicio
        await db.execute(_kCreateEdicionesLocales);
      },
    );
    return _db!;
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _puntos
      ..clear()
      ..add(details.localPosition));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _puntos.add(details.localPosition));
  }

  Future<void> _onPanEnd(DragEndDetails _) async {
    if (_puntos.length < 2) return;

    // Serializar geometría como WKB simplificado (lista de coordenadas en bytes)
    final geometria = _puntosAWkbSimplificado(_puntos);
    final atributos = jsonEncode({'tipo': 'trazo_libre', 'puntos': _puntos.length});
    final creadaEn = DateTime.now().toUtc().toIso8601String();

    // Persistir en SQLite antes de confirmar al usuario — Requerimiento 9.9
    final db = await _abrirDb();
    await db.insert('ediciones_locales', {
      'tipo': 'trazo_libre',
      'geometria': geometria,
      'atributos': atributos,
      'creada_en': creadaEn,
      'sincronizada': 0,
    });
  }

  /// Serializa una lista de [Offset] como bytes (WKB simplificado).
  Uint8List _puntosAWkbSimplificado(List<Offset> puntos) {
    final buffer = ByteData(puntos.length * 8);
    for (int i = 0; i < puntos.length; i++) {
      buffer.setFloat32(i * 8, puntos[i].dx);
      buffer.setFloat32(i * 8 + 4, puntos[i].dy);
    }
    return buffer.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.mapaWidget,
        // Capa Canvas ligera — Requerimiento 9.8
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _TrazoPainter(_puntos),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _TrazoPainter extends CustomPainter {
  final List<Offset> puntos;

  _TrazoPainter(this.puntos);

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.length < 2) return;
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrazoPainter old) => old.puntos != puntos;
}
