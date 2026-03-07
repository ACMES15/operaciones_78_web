enum UserType {
  adminOmnicanal,
  adminEnvios,
  usuarioNormal,
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
    }
  }
}
