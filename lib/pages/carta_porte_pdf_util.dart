import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

Future<pw.Document> buildCartaPortePdf(Map<String, dynamic> carta,
    {String? firma}) async {
  final pdf = pw.Document();
  final filas = (carta['filas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  // Usar el orden de columnas como se guarda en carta_porte_table.dart
  List<String> columnas = [];
  if (filas.isNotEmpty) {
    columnas = filas.first.keys.toList();
    // Si carta tiene campo 'headers' o 'columnas', usar ese orden
    if (carta.containsKey('headers')) {
      columnas = List<String>.from(carta['headers']);
    } else if (carta.containsKey('columnas')) {
      columnas = List<String>.from(carta['columnas']);
    }
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) {
        // --- Ajuste de ancho de columnas ---
        // Estimar ancho por string length (como hoja de ruta)
        const double fontSize = 8.0;
        List<double> colWidths = List.filled(columnas.length, 0);
        for (int i = 0; i < columnas.length; i++) {
          int maxLen = columnas[i].length;
          for (final fila in filas) {
            final l = (fila[columnas[i]]?.toString() ?? '').length;
            if (l > maxLen) maxLen = l;
          }
          colWidths[i] = (maxLen * 6.5).clamp(30, 180);
        }
        return [
          pw.Center(
            child: pw.Text('Liv. Galerias 0078',
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
          ),
          pw.SizedBox(height: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Fecha: ${carta['fecha'] ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Chofer: ${carta['chofer'] ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('RFC: ${carta['rfc'] ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Licencia: ${carta['licencia'] ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Unidad: ${carta['unidad'] ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Destino: ${carta['destino'] ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                  'No. Control: ${carta['numero_control']?.toString() ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 20),
          if (columnas.isNotEmpty)
            pw.Container(
              alignment: pw.Alignment.center,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  outside: pw.BorderSide.none,
                ),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: {
                  for (int i = 0; i < columnas.length; i++)
                    i: pw.FixedColumnWidth(colWidths[i]),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFE8F5E9)),
                    children: [
                      for (int i = 0; i < columnas.length; i++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 2, vertical: 1),
                          child: pw.Text(
                            columnas[i].toString().replaceAll('\n', ' '),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: fontSize),
                            maxLines: 1,
                          ),
                        ),
                    ],
                  ),
                  ...filas.map((fila) => pw.TableRow(
                        children: [
                          for (int i = 0; i < columnas.length; i++)
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 1),
                              child: pw.Text(
                                (fila[columnas[i]]?.toString() ?? '')
                                    .replaceAll('\n', ' '),
                                style: pw.TextStyle(fontSize: fontSize),
                                maxLines: 1,
                              ),
                            ),
                        ],
                      )),
                ],
              ),
            ),
          pw.SizedBox(height: 32),
          pw.Row(
            children: [
              pw.Text('Firma:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child:
                      pw.Text(firma ?? '', style: pw.TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ];
      },
    ),
  );
  return pdf;
}
