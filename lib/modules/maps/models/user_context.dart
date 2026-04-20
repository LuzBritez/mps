/// Rol del usuario dentro del módulo.
enum UserRole {
  coordinador,
  operario,
}

/// Contexto de usuario provisto por la Aplicación Principal.
/// El módulo no gestiona autenticación propia; recibe esta información
/// en el momento de su inicialización.
class UserContext {
  /// ID entero del usuario, generado por la Aplicación Principal (BIGSERIAL).
  final int userId;

  /// Nombre visible del usuario.
  final String nombre;

  /// Rol del usuario: coordinador u operario.
  final UserRole rol;

  const UserContext({
    required this.userId,
    required this.nombre,
    required this.rol,
  });

  @override
  String toString() =>
      'UserContext(userId: $userId, nombre: $nombre, rol: $rol)';
}
