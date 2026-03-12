import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> descargarCartaPortePDF({
  required String chofer,
  required String unidad,
  required String destino,
  required String rfc,
  required String fecha,
  required List<String> columns,
  required List<List<String>> table,
}) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('Liv. Galerias 0078',
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800)),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Fecha: $fecha'),
            pw.Text('Chofer: $chofer'),
            pw.Text('RFC: $rfc'),
            pw.Text('Unidad: $unidad'),
            pw.Text('Destino: $destino'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: columns,
              data: table,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
              cellStyle: pw.TextStyle(fontSize: 12),
              border: pw.TableBorder.all(color: PdfColors.grey),
              headerDecoration: pw.BoxDecoration(color: PdfColors.green100),
            ),
            pw.SizedBox(height: 32),
            pw.Text('Nombre del Chofer:', style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 8),
            pw.Text(chofer,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 24),
            pw.Container(
              height: 40,
              decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(width: 2, color: PdfColors.black))),
            ),
            pw.Center(
                child: pw.Text('Firma', style: pw.TextStyle(fontSize: 16))),
          ],
        );
      },
    ),
  );
  final bytes = await pdf.save();
  await Printing.layoutPdf(onLayout: (_) => bytes);
}
