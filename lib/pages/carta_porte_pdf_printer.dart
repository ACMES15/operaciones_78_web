import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

class CartaPortePdfPrinter {
  static Future<void> printCartaPortePdf({
    required String chofer,
    required String unidad,
    required String destino,
    required String rfc,
    required String fecha,
    required List<String> columns,
    required List<List<String>> table,
    String? numeroControl,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child: pw.Text('Liv. Galerias 0078',
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
          ),
          pw.SizedBox(height: 16),
          if (numeroControl != null && numeroControl.isNotEmpty)
            pw.Text('No. Control: $numeroControl',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
          pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Chofer: $chofer', style: pw.TextStyle(fontSize: 14)),
          pw.Text('RFC: $rfc', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Unidad: $unidad', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Destino: $destino', style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: columns,
            data: table,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
            headerDecoration: pw.BoxDecoration(color: PdfColors.green100),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          ),
          pw.SizedBox(height: 40),
          pw.Text('Nombre del Chofer: $chofer',
              style: pw.TextStyle(fontSize: 14)),
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 16),
            height: 1,
            width: 200,
            color: PdfColors.black,
          ),
          pw.Center(child: pw.Text('Firma', style: pw.TextStyle(fontSize: 14))),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
