enum UserType {
  adminOmnicanal,
  adminEnvios,
  usuarioNormal,
  inventarios,
  mesadebodas,
  staffCyc,
  staffOperaciones,
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
      case UserType.staffCyc:
        return 'STAFF CYC';
      case UserType.staffOperaciones:
        return 'STAFF OPERACIONES';
    }
  }
}
