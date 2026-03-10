class ValidationResult {
  final bool ok;
  final List<String> errors;
  ValidationResult(this.ok, [this.errors = const []]);
}

/// Valida una "sheet" genérica con keys: headers (List), rows (List)
ValidationResult validateSheet(Map<String, dynamic> sheet) {
  final errors = <String>[];
  if (sheet['headers'] == null) {
    errors.add('Faltan encabezados (headers).');
  } else if (sheet['headers'] is! List) {
    errors.add('Encabezados inválidos.');
  }

  if (sheet['rows'] == null) {
    errors.add('Faltan filas (rows).');
  } else if (sheet['rows'] is! List) {
    errors.add('Filas inválidas.');
  } else {
    final headers =
        (sheet['headers'] is List) ? List.from(sheet['headers']) : [];
    final rows = List.from(sheet['rows']);
    if (rows.isEmpty) {
      errors.add('La hoja no contiene filas.');
    } else if (headers.isNotEmpty) {
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        if (r is List) {
          if (r.length != headers.length) {
            errors.add(
                'Fila ${i + 1}: número de columnas (${r.length}) diferente a encabezados (${headers.length}).');
            break;
          }
        } else if (r is Map) {
          // OK: map puede tener keys
        } else {
          errors.add('Fila ${i + 1}: formato de fila desconocido.');
          break;
        }
      }
    }
  }

  // Validar fecha si existe
  if (sheet['fecha'] != null) {
    final f = sheet['fecha'];
    try {
      // admitimos String ISO o DateTime
      if (f is String) DateTime.parse(f);
      if (f is! String && f is! DateTime) {
        errors.add('Fecha en formato inválido.');
      }
    } catch (_) {
      errors.add('Fecha inválida.');
    }
  }

  return ValidationResult(errors.isEmpty, errors);
}
