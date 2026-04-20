import 'package:flutter/material.dart';
import 'modules/maps/maps_module.dart';
import 'modules/maps/models/user_context.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trazado Eléctrico',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MapsModule.create(
        userContext: UserContext(
          userId: 1,
          nombre: 'Usuario Demo',
          rol: UserRole.operario,
        ),
      ),
    );
  }
}
