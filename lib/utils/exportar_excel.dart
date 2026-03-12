import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;

/// Exporta una lista de cartas porte a Excel exportando todas las claves y filas anidadas.
Future<void> exportarExcel({
  required List<Map<String, dynamic>> cartas,
  String fileName = 'cartas_porte.xlsx',
}) async {
  final excel = Excel.createExcel();
  final sheet = excel['CartasPorte'];
  if (cartas.isEmpty) return;

  // Determinar todas las claves posibles (columnas)
  final Set<String> allKeys = {};
  for (final carta in cartas) {
    allKeys.addAll(carta.keys);
    if (carta['filas'] is List) {
      for (final fila in (carta['filas'] as List)) {
        if (fila is Map) allKeys.addAll(fila.keys.map((k) => 'fila_${k}'));
      }
    }
  }
  final columns = allKeys.toList();

  // Escribir encabezados
  sheet.appendRow(columns);

  // Escribir datos
  for (final carta in cartas) {
    final row = <dynamic>[];
    for (final col in columns) {
      if (col.startsWith('fila_')) {
        // Buscar en filas
        final key = col.substring(5);
        String value = '';
        if (carta['filas'] is List) {
          value = (carta['filas'] as List)
              .map((fila) => fila[key]?.toString() ?? '')
              .where((v) => v.isNotEmpty)
              .join(' | ');
        }
        row.add(value);
      } else {
        row.add(carta[col]?.toString() ?? '');
      }
    }
    sheet.appendRow(row);
  }

  final fileBytes = excel.encode()!;
  final blob = html.Blob([fileBytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
