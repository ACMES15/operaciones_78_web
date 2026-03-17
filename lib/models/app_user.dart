enum UserRole {
  administrador,
  usuario,
}

enum UserType {
  adminOmnicanal,
  cliente,
  invitado,
  inventarios,
  mesadebodas,
}

class AppUser {
  final String id;
  final String nombre;
  final UserRole rol;
  final UserType tipo;

  AppUser({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.tipo,
  });
}

// Ejemplo de uso:
// AppUser(
//   id: '1',
//   nombre: 'Juan',
//   rol: UserRole.administrador,
//   tipo: UserType.adminOmnicanal,
// )
