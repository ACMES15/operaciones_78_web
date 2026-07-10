import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'inventario_pdis_page.dart';

class InventarioHistoricoPage extends StatefulWidget {
  const InventarioHistoricoPage({Key? key}) : super(key: key);

  @override
  State<InventarioHistoricoPage> createState() =>
      _InventarioHistoricoPageState();
}

class _InventarioHistoricoPageState extends State<InventarioHistoricoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Histórico Inventarios',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventarios_historico')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty)
            return const Center(
                child: Text('No hay auditorías guardadas',
                    style: TextStyle(color: Colors.white)));
          final docs = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final jefe = data['jefe']?.toString() ?? 'Desconocido';
              final created = (data['createdAt'] is Timestamp)
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null;
              final percent = (data['percentScanned'] is num)
                  ? (data['percentScanned'] as num).toDouble()
                  : ((data['percentScanned'] is double)
                      ? data['percentScanned']
                      : 0.0);
              final quality = (data['qualityScore'] is num)
                  ? (data['qualityScore'] as num).toDouble()
                  : 0.0;

              return Card(
                color: Colors.white,
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  onTap: () => _openDetails(context, data),
                  title: Text('$jefe',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.black)),
                  subtitle: Text(created != null ? created.toString() : '',
                      style: const TextStyle(color: Colors.black54)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(percent * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      Text('Calidad ${quality.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _editInventory(context, data),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6)),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editInventory(BuildContext context, Map<String, dynamic> data) {
    final usuario = data['usuario']?.toString() ?? '';
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => InventarioPdisPage(
                  usuario: usuario,
                  initialPayload: data,
                )));
  }

  void _openDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
        context: context,
        builder: (ctx) {
          final skus = <MapEntry<String, dynamic>>[];
          if (data['skus'] is Map) {
            (data['skus'] as Map).forEach((k, v) {
              skus.add(MapEntry(k.toString(), v));
            });
          }
          final sobrantes = <MapEntry<String, dynamic>>[];
          if (data['sobrantes'] is Map) {
            (data['sobrantes'] as Map).forEach((k, v) {
              sobrantes.add(MapEntry(k.toString(), v));
            });
          }
          final percent = (data['percentScanned'] is num)
              ? (data['percentScanned'] as num).toDouble()
              : 0.0;
          final quality = (data['qualityScore'] is num)
              ? (data['qualityScore'] as num).toDouble()
              : 0.0;

          // build question percentages (Sí -> 100, No -> 0)
          final q = [
            data['q1'] == true ? 1.0 : 0.0,
            data['q2'] == true ? 1.0 : 0.0,
            data['q3'] == true ? 1.0 : 0.0,
            data['q4'] == true ? 1.0 : 0.0,
          ];

          return AlertDialog(
            title: Text('Resultado - ${data['jefe'] ?? 'Jefe'}'),
            content: SizedBox(
              width: 820,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top graphics: percent scanned and quality
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                const Text('Escaneo',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Stack(alignment: Alignment.center, children: [
                                  SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: CircularProgressIndicator(
                                          value: percent,
                                          strokeWidth: 12,
                                          color: Colors.blue)),
                                  Text('${(percent * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))
                                ]),
                                const SizedBox(height: 8),
                                Text(
                                    'Scanned: ${data['totalScanned'] ?? 0} / ${data['totalPdis'] ?? 0}')
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                const Text('Calidad',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Stack(alignment: Alignment.center, children: [
                                  SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: CircularProgressIndicator(
                                          value: (quality / 100),
                                          strokeWidth: 12,
                                          color: Colors.green)),
                                  Text('${quality.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))
                                ]),
                                const SizedBox(height: 8),
                                Text('Calidad calculada')
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Questions summary
                  Card(
                      elevation: 1,
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Formulario (resumen)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: _buildQuestionChip(
                                        '1) Mercancía identificada', q[0])),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _buildQuestionChip(
                                        '2) Faltante primer escaneo', q[1])),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _buildQuestionChip(
                                        '3) Mercancía dañada', q[2])),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _buildQuestionChip(
                                        '4) En bodega', q[3])),
                              ])
                            ],
                          ))),
                  const SizedBox(height: 12),
                  // Sobrantes
                  if (sobrantes.isNotEmpty)
                    Card(
                        color: Colors.red.shade50,
                        elevation: 1,
                        child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sobrantes detectados',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 140,
                                  child: ListView.builder(
                                    itemCount: sobrantes.length,
                                    itemBuilder: (context, i) {
                                      final k = sobrantes[i].key;
                                      final v = sobrantes[i].value;
                                      return ListTile(
                                        dense: true,
                                        title: Text(k,
                                            style: const TextStyle(
                                                color: Colors.black)),
                                        trailing: Text('${v ?? 0}',
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold)),
                                      );
                                    },
                                  ),
                                )
                              ],
                            ))),
                  const SizedBox(height: 12),
                  // Full SKU table
                  const Text('Detalle de SKUs',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('PDIS'), numeric: true),
                          DataColumn(label: Text('Escaneado'), numeric: true),
                        ],
                        rows: skus.map((e) {
                          final k = e.key;
                          final v = e.value;
                          final pdis = (v is Map && v['pdis'] != null)
                              ? v['pdis'].toString()
                              : '';
                          final scanned = (v is Map && v['scanned'] != null)
                              ? v['scanned'].toString()
                              : '0';
                          return DataRow(cells: [
                            DataCell(Text(k)),
                            DataCell(Text(pdis)),
                            DataCell(Text(scanned)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar')),
              TextButton(
                  onPressed: () => _exportHistoricoToExcel(data),
                  child: const Text('Exportar Excel')),
              TextButton(
                  onPressed: () => _exportHistoricoToPdf(data),
                  child: const Text('Exportar PDF'))
            ],
          );
        });
  }

  Future<void> _exportHistoricoToPdf(Map<String, dynamic> payload) async {
    final doc = pw.Document();

    final percent = (payload['percentScanned'] is num)
        ? (payload['percentScanned'] as num).toDouble()
        : 0.0;
    final quality = (payload['qualityScore'] is num)
        ? (payload['qualityScore'] as num).toDouble()
        : 0.0;

    final headers = ['SKU', 'PDIS', 'Escaneado'];
    final rows = <List<String>>[];
    if (payload['skus'] is Map) {
      (payload['skus'] as Map).forEach((k, v) {
        final pdis =
            (v is Map && v['pdis'] != null) ? v['pdis'].toString() : '0';
        final scanned =
            (v is Map && v['scanned'] != null) ? v['scanned'].toString() : '0';
        rows.add([k.toString(), pdis, scanned]);
      });
    }

    final sobrantesRows = <List<String>>[];
    if (payload['sobrantes'] is Map) {
      (payload['sobrantes'] as Map).forEach((k, v) {
        sobrantesRows.add([k.toString(), v.toString()]);
      });
    }

    doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
              pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Inventario - ${payload['jefe'] ?? ''}',
                                  style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                  'Fecha: ${payload['createdAt'] is Timestamp ? (payload['createdAt'] as Timestamp).toDate().toString() : ''}'),
                            ]),
                        pw.Column(children: [
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                  color: PdfColors.blue200,
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(6))),
                              child: pw.Column(children: [
                                pw.Text('Escaneado',
                                    style: pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                    '${(percent * 100).toStringAsFixed(1)}%',
                                    style: pw.TextStyle(
                                        fontSize: 20,
                                        fontWeight: pw.FontWeight.bold))
                              ])),
                          pw.SizedBox(height: 8),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                  color: PdfColors.green200,
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(6))),
                              child: pw.Column(children: [
                                pw.Text('Calidad',
                                    style: pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 6),
                                pw.Text('${quality.toStringAsFixed(0)}%',
                                    style: pw.TextStyle(
                                        fontSize: 20,
                                        fontWeight: pw.FontWeight.bold))
                              ]))
                        ])
                      ])),
              pw.SizedBox(height: 12),
              pw.Text('Formulario (resumen)',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Bullet(
                  text:
                      '1) Mercancía identificada: ${payload['q1'] == true ? 'Sí' : 'No'}'),
              pw.Bullet(
                  text:
                      '2) Faltante primer escaneo: ${payload['q2'] == true ? 'Sí' : 'No'}'),
              pw.Bullet(
                  text:
                      '3) Mercancía dañada: ${payload['q3'] == true ? 'Sí' : 'No'}'),
              pw.Bullet(
                  text: '4) En bodega: ${payload['q4'] == true ? 'Sí' : 'No'}'),
              pw.SizedBox(height: 12),
              pw.Text('Detalle de SKUs',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (rows.isNotEmpty)
                pw.Table.fromTextArray(
                    headers: headers,
                    data: rows,
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (sobrantesRows.isNotEmpty) pw.SizedBox(height: 12),
              if (sobrantesRows.isNotEmpty)
                pw.Text('Sobrantes',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (sobrantesRows.isNotEmpty)
                pw.Table.fromTextArray(
                    headers: ['SKU', 'Cantidad'], data: sobrantesRows)
            ]));

    final pdfBytes = await doc.save();
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download =
          'inventario_historico_${payload['jefe'] ?? 'jefe'}_${DateTime.now().toIso8601String()}.pdf';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  Widget _buildQuestionChip(String label, double value) {
    final pct = (value * 100).toInt();
    final color = value >= 1.0 ? Colors.green : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
                child: LinearProgressIndicator(
                    value: value,
                    color: color,
                    backgroundColor: Colors.grey.shade200)),
            const SizedBox(width: 8),
            Text('$pct%',
                style: TextStyle(fontWeight: FontWeight.bold, color: color))
          ],
        )
      ],
    );
  }

  Future<void> _exportHistoricoToExcel(Map<String, dynamic> payload) async {
    final workbook = ex.Excel.createExcel();
    final summary = workbook['Resumen'];
    final skusSheet = workbook['SKUs'];
    final sobrantesSheet = workbook['Sobrantes'];

    // metadata
    summary.appendRow(['Jefatura', payload['jefe'] ?? '']);
    summary.appendRow([
      'Fecha',
      (payload['createdAt'] is Timestamp)
          ? (payload['createdAt'] as Timestamp).toDate().toString()
          : ''
    ]);
    summary.appendRow(['Total PDIS', payload['totalPdis'] ?? 0]);
    summary.appendRow(['Total Escaneado', payload['totalScanned'] ?? 0]);
    summary.appendRow(['% Escaneado', (payload['percentScanned'] ?? 0.0)]);
    summary.appendRow(['Calidad', (payload['qualityScore'] ?? 0.0)]);
    summary.appendRow([]);
    summary.appendRow(['Formulario', 'Valor']);
    summary.appendRow(
        ['1) Mercancía identificada', payload['q1'] == true ? 'Sí' : 'No']);
    summary.appendRow(
        ['2) Faltante primer escaneo', payload['q2'] == true ? 'Sí' : 'No']);
    summary.appendRow(
        ['3) Mercancía dañada', payload['q3'] == true ? 'Sí' : 'No']);
    summary.appendRow(['4) En bodega', payload['q4'] == true ? 'Sí' : 'No']);

    // SKUs
    skusSheet.appendRow(['SKU', 'PDIS', 'Escaneado']);
    if (payload['skus'] is Map) {
      (payload['skus'] as Map).forEach((k, v) {
        final pdis =
            (v is Map && v['pdis'] != null) ? v['pdis'].toString() : '0';
        final scanned =
            (v is Map && v['scanned'] != null) ? v['scanned'].toString() : '0';
        skusSheet.appendRow([k.toString(), pdis, scanned]);
      });
    }

    // Sobrantes
    sobrantesSheet.appendRow(['SKU', 'Cantidad']);
    if (payload['sobrantes'] is Map) {
      (payload['sobrantes'] as Map).forEach((k, v) {
        sobrantesSheet.appendRow([k.toString(), v.toString()]);
      });
    }

    final bytes = workbook.encode();
    if (bytes == null) return;
    final bytesData = Uint8List.fromList(bytes);
    final blob = html.Blob([bytesData],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download =
          'inventario_historico_${payload['jefe'] ?? 'jefe'}_${DateTime.now().toIso8601String()}.xlsx';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
}
