import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

Future<pw.Document> buildCartaPortePdf(Map<String, dynamic> carta,
    {String? firma}) async {
  final pdf = pw.Document();
  final filas = (carta['filas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text('Carta Porte',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Número de control: \\${carta['numero_control'] ?? '-'}'),
        pw.Text('Fecha: \\${carta['fecha'] ?? '-'}'),
        pw.Text('Destino: \\${carta['destino'] ?? '-'}'),
        pw.Text('Chofer: \\${carta['chofer'] ?? '-'}'),
        pw.Text('RFC: \\${carta['rfc'] ?? '-'}'),
        pw.Text('Unidad: \\${carta['unidad'] ?? '-'}'),
        pw.SizedBox(height: 16),
        pw.Text('Filas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...filas.map((fila) => pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: fila.entries
                    .map((e) => pw.Text('${e.key}: ${e.value}'))
                    .toList(),
              ),
            )),
        pw.SizedBox(height: 24),
        pw.Divider(),
        pw.Text('Firma:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text(firma ?? '', style: pw.TextStyle(fontSize: 16)),
      ],
    ),
  );
  return pdf;
}
