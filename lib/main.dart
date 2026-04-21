import 'package:flutter/material.dart';
import 'modules/maps/maps_module.dart';
import 'modules/maps/models/user_context.dart';
import 'modules/maps/services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar la URL del backend Docker.
  // - Emulador Android: 10.0.2.2 apunta al host de la máquina
  // - Dispositivo físico: usar la IP de la máquina en la red WiFi
  //   Ejemplo: http://192.168.1.100:3000
  apiClient = ApiClient(
    baseUrl: const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://10.0.2.2:3000',
    ),
  );

  runApp(
    MapsModule.create(
      userContext: const UserContext(
        userId: 1,
        nombre: 'Usuario Demo',
        rol: UserRole.coordinador,
      ),
    ),
  );
}
