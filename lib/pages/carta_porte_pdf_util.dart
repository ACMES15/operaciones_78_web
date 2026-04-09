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
          child: pw.Text('CARTA PORTE',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              outside: pw.BorderSide.none,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(4),
            },
            children: [
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Número de control:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(carta['numero_control']?.toString() ?? '-'),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Fecha:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(carta['fecha']?.toString() ?? '-'),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Destino:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(carta['destino']?.toString() ?? '-'),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Chofer:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(carta['chofer']?.toString() ?? '-'),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('RFC:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(carta['rfc']?.toString() ?? '-'),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Unidad:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(carta['unidad']?.toString() ?? '-'),
                ),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        if (columnas.isNotEmpty)
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: pw.Table(
              border: pw.TableBorder.symmetric(
                inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                outside: pw.BorderSide.none,
              ),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8F5E9)),
                  children: columnas
                      .map((col) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(col,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                          ))
                      .toList(),
                ),
                ...filas.map((fila) => pw.TableRow(
                      children: columnas
                          .map((col) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(fila[col]?.toString() ?? ''),
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
