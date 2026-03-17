enum UserType {
  adminOmnicanal,
  adminEnvios,
  usuarioNormal,
  inventarios,
  mesadebodas,
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.adminOmnicanal:
        return 'ADMIN OMNICANAL';
      case UserType.adminEnvios:
        return 'ADMIN ENVIOS';
      case UserType.usuarioNormal:
        return 'Usuario Normal';
      case UserType.inventarios:
        return 'INVENTARIOS';
      case UserType.mesadebodas:
        return 'MESADEBODAS';
    }
  }
}
