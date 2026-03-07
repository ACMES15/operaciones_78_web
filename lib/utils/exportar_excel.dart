import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;

/// Exporta una lista de cartas porte a Excel.
/// Cada carta debe tener las claves: FECHA, CHOFER, RFC, UNIDAD, DESTINO, COLUMNS, TABLE
Future<void> exportarExcel({
  required List<Map<String, dynamic>> cartas,
  String fileName = 'cartas_porte.xlsx',
}) async {
  final excel = Excel.createExcel();
  final sheet = excel['CartaPorte'];
  if (cartas.isEmpty) return;
  // Determinar columnas base
  final first = cartas.first;
  final columns = [
    'No. Control',
    'Fecha',
    'Chofer',
    'RFC',
    'Unidad',
    'Destino',
    ...List<String>.from(first['COLUMNS'] ?? [])
  ];
  sheet.appendRow(columns);
  for (final carta in cartas) {
    final numeroControl = carta['NUMERO_CONTROL'] ?? '';
    final fecha = carta['FECHA'] ?? '';
    final chofer = carta['CHOFER'] ?? '';
    final rfc = carta['RFC'] ?? '';
    final unidad = carta['UNIDAD'] ?? '';
    final destino = carta['DESTINO'] ?? '';
    final table = (carta['TABLE'] as List?) ?? [];
    for (final row in table) {
      // Solo exportar filas con algún dato
      if (row is List &&
          row.any((c) => (c?.toString().trim() ?? '').isNotEmpty)) {
        sheet.appendRow([
          numeroControl,
          fecha,
          chofer,
          rfc,
          unidad,
          destino,
          ...row.map((c) => c?.toString() ?? '')
        ]);
      }
    }
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
