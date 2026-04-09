import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

Future<pw.Document> buildCartaPortePdf(Map<String, dynamic> carta,
    {String? firma}) async {
  final pdf = pw.Document();
  final filas = (carta['filas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  // Determinar columnas de la tabla de filas
  final Set<String> columnasFilas = {};
  for (final fila in filas) {
    columnasFilas.addAll(fila.keys);
  }
  final columnas = columnasFilas.toList();

  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Center(
          child: pw.Text('Liv. Galerias 0078',
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('Fecha: ${carta['fecha'] ?? '-'}   ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Chofer: ${carta['chofer'] ?? '-'}   ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('RFC: ${carta['rfc'] ?? '-'}   ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Licencia: ${carta['licencia'] ?? '-'}   ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Unidad: ${carta['unidad'] ?? '-'}   ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Destino: ${carta['destino'] ?? '-'}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Text('No. Control:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 8),
            pw.Text(carta['numero_control']?.toString() ?? '-'),
          ],
        ),
        pw.SizedBox(height: 20),
        if (columnas.isNotEmpty)
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Table(
              border: pw.TableBorder.symmetric(
                inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                outside: pw.BorderSide.none,
              ),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              columnWidths: {
                for (int i = 0; i < columnas.length; i++)
                  i: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8F5E9)),
                  children: columnas
                      .map((col) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 2, vertical: 1),
                            child: pw.Text(
                              col.toString().replaceAll('\n', ' '),
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 8),
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                ),
                ...filas.map((fila) => pw.TableRow(
                      children: columnas
                          .map((col) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 1),
                                child: pw.Text(
                                  (fila[col]?.toString() ?? '')
                                      .replaceAll('\n', ' '),
                                  style: pw.TextStyle(fontSize: 8),
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
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
                child: pw.Text(firma ?? '', style: pw.TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return pdf;
}
