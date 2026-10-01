import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'hoja_de_ruta_extra_page.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<Uint8List> generatePdfBytesEnviadas(Map<String, dynamic> params) async {
  // Eliminar columna 'Docto' solo para impresión PDF
  final headers = List<String>.from(params['headers'] as List);
  final doctoIdx = headers.indexOf('Docto');
  if (doctoIdx != -1) headers.removeAt(doctoIdx);
  final data = List<List<String>>.from(params['data'] as List)
      .map((row) => doctoIdx != -1 && row.length > doctoIdx
          ? (List<String>.from(row)..removeAt(doctoIdx))
          : row)
      .toList();
  final origen = params['origen'] as String? ?? '';
  final fecha = params['fecha'] as String? ?? '';
  final caja = params['caja'] as String? ?? '';
  final tipo = params['tipo'] as String? ?? '';
  final numeroControl = params['numeroControl'] as String? ?? '';

  final pdf = pw.Document();

  // Ajustar ancho de columnas: 'No. Manifiesto o Remisión' angosta, 'SELLOS' ancha
  List<double> colWidths = List.filled(headers.length, 0);
  const double fontSize = 10.0;
  for (int i = 0; i < headers.length; i++) {
    final h = headers[i];
    if (h == 'No. Manifiesto o Remisión') {
      colWidths[i] = 60; // más angosta
      continue;
    }
    if (h == 'SELLOS') {
      colWidths[i] = 160; // más ancha
      continue;
    }
    int maxLen = h.length;
    for (final row in data) {
      if (i < row.length) {
        final l = row[i].toString().length;
        if (l > maxLen) maxLen = l;
      }
    }
    colWidths[i] = (maxLen * 7.5).clamp(40, 120);
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Center(
          child: pw.Text('Hoja de Ruta',
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
        ),
        pw.SizedBox(height: 8),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Origen: $origen',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('N° Caja: $caja',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Fecha: $fecha',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Tipo: $tipo',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('N° de control: $numeroControl',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 16),
        if (headers.isNotEmpty)
          pw.Container(
            width: headers.fold<double>(
                    0, (a, b) => a + colWidths[headers.indexOf(b)]) +
                headers.length * 4,
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            child: pw.Table(
              border: pw.TableBorder.symmetric(
                inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                outside: pw.BorderSide.none,
              ),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              columnWidths: {
                for (int i = 0; i < headers.length; i++)
                  i: pw.FixedColumnWidth(colWidths[i]),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8F5E9)),
                  children: [
                    for (int i = 0; i < headers.length; i++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 2, vertical: 1),
                        child: pw.Text(
                          headers[i].replaceAll('\n', ' '),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: fontSize),
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
                ...data.map((fila) => pw.TableRow(
                      children: [
                        for (int i = 0; i < headers.length; i++)
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 2, vertical: 1),
                            child: pw.Text(
                              (i < fila.length ? fila[i] : '')
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
      ],
    ),
  );

  return pdf.save();
}

class HojaDeRutaEnviadasPage extends StatefulWidget {
  const HojaDeRutaEnviadasPage({super.key});

  @override
  State<HojaDeRutaEnviadasPage> createState() => _HojaDeRutaEnviadasPageState();
}

class _HojaDeRutaEnviadasPageState extends State<HojaDeRutaEnviadasPage> {
  Future<void> _printCaratulaFromSheet(
      BuildContext context, Map<String, dynamic> sheet) async {
    String normalizeLabel(dynamic value) => value
        .toString()
        .toLowerCase()
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    String getFieldIgnoreCase(Map<String, dynamic> m, String name) {
      final wanted = normalizeLabel(name);
      for (final k in m.keys) {
        if (normalizeLabel(k) == wanted) {
          return m[k]?.toString() ?? '';
        }
      }
      return '';
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      final v = (value ?? '').toString().trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'si' || v == 'sí' || v == 'on';
    }

    final origen = getFieldIgnoreCase(sheet, 'origen');
    final tipoHoja = getFieldIgnoreCase(sheet, 'tipo');
    final numeroControl = sheet['numeroControl']?.toString() ?? '';
    final fechaEnvio = getFieldIgnoreCase(sheet, 'fecha');
    final caja = getFieldIgnoreCase(sheet, 'caja');

    final esForaneo = parseBool(sheet['foraneo']) ||
        parseBool(sheet['esForaneo']) ||
        tipoHoja.toLowerCase().contains('foraneo') ||
        tipoHoja.toLowerCase().contains('foráneo');

    String destino = '';
    if (esForaneo) {
      destino = '880 PLAN';
    } else {
      // Igual que hoja nueva: destino viene de "Nombre Alm. destino"
      final fromSaved = getFieldIgnoreCase(sheet, 'destinoCaratula').trim();
      if (fromSaved.isNotEmpty) {
        destino = fromSaved;
      } else if (sheet['rows'] is List) {
        final rows = sheet['rows'] as List;
        final headers = sheet['headers'] is List
            ? List<String>.from(sheet['headers'])
            : <String>[];
        int idxNombreDestino = headers.indexWhere((h) {
          final n = normalizeLabel(h)
              .replaceAll('.', '')
              .replaceAll('(', '')
              .replaceAll(')', '');
          return n.contains('nombre') &&
              n.contains('alm') &&
              n.contains('destino');
        });
        if (idxNombreDestino == -1) {
          idxNombreDestino = headers.indexWhere((h) =>
              normalizeLabel(h).contains('nombre alm') ||
              normalizeLabel(h).contains('destino'));
        }
        if (rows.isNotEmpty) {
          final first = rows.first;
          if (first is Map) {
            if (idxNombreDestino >= 0 && idxNombreDestino < headers.length) {
              destino = first[headers[idxNombreDestino]]?.toString() ?? '';
            }
            if (destino.trim().isEmpty) {
              for (final entry in first.entries) {
                final nk = normalizeLabel(entry.key)
                    .replaceAll('.', '')
                    .replaceAll('(', '')
                    .replaceAll(')', '');
                if (nk.contains('nombre') &&
                    nk.contains('alm') &&
                    nk.contains('destino')) {
                  destino = entry.value?.toString() ?? '';
                  break;
                }
              }
            }
          } else if (first is List &&
              idxNombreDestino >= 0 &&
              idxNombreDestino < first.length) {
            destino = first[idxNombreDestino]?.toString() ?? '';
          }
        }
      }
    }

    if (destino.trim().isEmpty) {
      destino = getFieldIgnoreCase(sheet, 'destino');
    }
    if (destino.trim().isEmpty) {
      destino = 'Sin destino';
    }

    final esZonaEspecial = tipoHoja.toLowerCase().contains('zona especial');

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (esZonaEspecial)
                pw.Center(
                  child: pw.Text(
                    tipoHoja.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red800,
                    ),
                  ),
                ),
              pw.Text('Hoja de Ruta',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('Tipo de hoja:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child:
                          pw.Text(tipoHoja, style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('N° de control:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(numeroControl,
                          style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('Origen:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(origen, style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('Destino:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child:
                          pw.Text(destino, style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('Fecha:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(fechaEnvio,
                          style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('N° de Caja:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(caja, style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showSheetDetail(BuildContext context, Map<String, dynamic> sheet) {
    List<List<String>> rows = [];
    final List<String> columns =
        sheet['headers'] != null ? List<String>.from(sheet['headers']) : [];

    if (sheet['rows'] != null && sheet['rows'] is List && columns.isNotEmpty) {
      final rawRows = sheet['rows'] as List;
      for (final row in rawRows) {
        if (row is Map) {
          rows.add(columns.map((h) => row[h]?.toString() ?? '').toList());
        } else if (row is List) {
          rows.add(List<String>.from(row.map((e) => e.toString())));
        }
      }
    }

    final List<List<TextEditingController>> rowControllers = List.generate(
      rows.length,
      (i) => List.generate(
        rows[i].length,
        (j) => TextEditingController(text: rows[i][j]),
      ),
    );

    Future<void> saveEdits() async {
      final newRows = rowControllers
          .map((r) => r.map((c) => c.text.trim()).toList())
          .toList();
      await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(sheet['numeroControl'])
          .update({'rows': newRows});
    }

    Future<void> deleteSheet() async {
      await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(sheet['numeroControl'])
          .delete();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detalle de hoja de ruta'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns
                    .map((c) => DataColumn(
                        label: Text(c,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))))
                    .toList(),
                rows: List.generate(
                  rowControllers.length,
                  (i) => DataRow(
                    cells: List.generate(
                      columns.length,
                      (j) => DataCell(
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: rowControllers[i][j],
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            if (HojaDeRutaExtraPage.isAdmin)
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
                onPressed: () async {
                  await saveEdits();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            if (HojaDeRutaExtraPage.isAdmin)
              ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Eliminar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await deleteSheet();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Imprimir'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _printSheet(context, sheet);
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _forzarRecarga() async {
    await invalidateCache('hoja_ruta', 'sentHojaRutas');
    setState(() {}); // Forzar rebuild para que FutureBuilder recargue
  }

  Future<void> _printSheet(
      BuildContext context, Map<String, dynamic> sheet) async {
    try {
      String normalizeLabel(dynamic value) => value
          .toString()
          .toLowerCase()
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      String canonicalKey(String label) {
        final n = normalizeLabel(label)
            .replaceAll('.', '')
            .replaceAll('(', '')
            .replaceAll(')', '');
        if (n.contains('manifiesto') || n.contains('remision')) {
          return 'manifiesto';
        }
        if (n.contains('documento')) return 'documento';
        if (n.contains('pedido')) return 'pedido';
        if (n.contains('bulto')) return 'bultos';
        if (n.contains('alm') &&
            n.contains('nombre') &&
            n.contains('destino')) {
          return 'nombre_alm_destino';
        }
        if (n.contains('alm')) return 'no_alm';
        if (n.contains('contenedor') || n.contains('hu')) return 'contenedor';
        if (n.contains('proveedor') && n.contains('nombre')) {
          return 'nombre_proveedor';
        }
        if (n.contains('proveedor')) return 'no_proveedor';
        if (n.contains('sello')) return 'sellos';
        if (n.contains('docto')) return 'docto';
        return n;
      }

      // Encabezados canónicos (igual que Hoja de Ruta nueva)
      const canonicalHeaders = <String>[
        'No. Manifiesto o Remisión',
        'No. Documento',
        'No. Pedido',
        'No. Bultos',
        'No. Alm.',
        'Nombre Alm. destino',
        'No. Contenedor (HU)',
        'No. Proveedor',
        'Nombre de Proveedor',
        'SELLOS',
      ];

      final headers = List<String>.from(canonicalHeaders);

      final allHeaders =
          sheet['headers'] != null ? List<String>.from(sheet['headers']) : [];
      final visibleSourceHeaders = <String>[];
      for (int i = 0; i < allHeaders.length; i++) {
        if (canonicalKey(allHeaders[i]) == 'docto') continue;
        visibleSourceHeaders.add(allHeaders[i].toString());
      }

      final sourceIndexByCanonical = <String, int>{};
      for (int i = 0; i < allHeaders.length; i++) {
        final key = canonicalKey(allHeaders[i]);
        if (key == 'docto') continue;
        sourceIndexByCanonical[key] = i;
      }

      String getMapValueByCanonical(Map row, String canonicalHeader) {
        final wanted = canonicalKey(canonicalHeader);
        for (final entry in row.entries) {
          if (canonicalKey(entry.key.toString()) == wanted) {
            return entry.value?.toString() ?? '';
          }
        }
        if (row.containsKey(canonicalHeader)) {
          return row[canonicalHeader]?.toString() ?? '';
        }
        return '';
      }

      final data = (sheet['rows'] as List?)?.map((row) {
            final ordered = <String>[];
            if (row is Map) {
              for (final h in canonicalHeaders) {
                ordered.add(getMapValueByCanonical(row, h));
              }
            } else if (row is List) {
              for (int j = 0; j < canonicalHeaders.length; j++) {
                final key = canonicalKey(canonicalHeaders[j]);
                int? srcIdx = sourceIndexByCanonical[key];
                srcIdx ??= allHeaders.length == canonicalHeaders.length + 1
                    ? j + 1
                    : j;
                if (srcIdx >= 0 && srcIdx < row.length) {
                  ordered.add(row[srcIdx]?.toString() ?? '');
                } else {
                  ordered.add('');
                }
              }
            } else {
              for (int j = 0; j < canonicalHeaders.length; j++) {
                ordered.add(j == 0 ? row.toString() : '');
              }
            }
            return ordered;
          }).toList() ??
          <List<String>>[];

      if (kDebugMode) {
        debugPrint('PRINT ENVIADAS - headers fuente: $allHeaders');
        debugPrint('PRINT ENVIADAS - headers canonicos: $headers');
        if (data.isNotEmpty) {
          debugPrint('PRINT ENVIADAS - primera fila: ${data.first}');
        }
      }
      final origen = sheet['origen'] ?? '';
      final fecha = sheet['fecha'] ?? '';
      final caja = sheet['caja'] ?? '';
      final tipo = sheet['tipo'] ?? '';
      final numeroControl = sheet['numeroControl'] ?? '';

      // Ajustar ancho de columnas
      List<double> colWidths = List.filled(headers.length, 0);
      const double fontSize = 10.0;
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h == 'No. Manifiesto o Remisión') {
          colWidths[i] = 90;
          continue;
        }
        if (h == 'No. Documento' ||
            h == 'No. Pedido' ||
            h == 'No. Bultos' ||
            h == 'No. Alm.' ||
            h == 'No. Proveedor') {
          colWidths[i] = 70;
          continue;
        }
        if (h == 'Nombre Alm. destino' || h == 'Nombre de Proveedor') {
          colWidths[i] = 130;
          continue;
        }
        if (h == 'No. Contenedor (HU)') {
          colWidths[i] = 110;
          continue;
        }
        if (h == 'SELLOS') {
          colWidths[i] = 140;
          continue;
        }
        int maxLen = h.length;
        for (final row in data) {
          if (i < row.length) {
            final l = row[i].toString().length;
            if (l > maxLen) maxLen = l;
          }
        }
        colWidths[i] = (maxLen * 7.5).clamp(55, 140);
      }
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text('Hoja de Ruta',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Origen: $origen',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('N° Caja: $caja',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Fecha: $fecha',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Tipo: $tipo',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('N° de control: $numeroControl',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 16),
            if (headers.isNotEmpty)
              pw.Container(
                width: colWidths.fold<double>(0, (a, b) => a + b) +
                    headers.length * 4,
                alignment: pw.Alignment.centerLeft,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                child: pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    outside: pw.BorderSide.none,
                  ),
                  defaultVerticalAlignment:
                      pw.TableCellVerticalAlignment.middle,
                  columnWidths: {
                    for (int i = 0; i < headers.length; i++)
                      i: pw.FixedColumnWidth(colWidths[i]),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        for (int i = 0; i < headers.length; i++)
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 2, vertical: 1),
                            child: pw.Text(
                              headers[i].replaceAll('\n', ' '),
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: fontSize),
                            ),
                          ),
                      ],
                    ),
                    ...data.map((fila) => pw.TableRow(
                          children: [
                            for (int i = 0; i < headers.length; i++)
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 1),
                                child: pw.Text(
                                  (i < fila.length ? fila[i] : '')
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
          ],
        ),
      );
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al imprimir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // final searchController = TextEditingController();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('hoja_ruta').snapshots(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> sent = [];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final id = doc.id;
            if (id == 'sentHojaRutas' ||
                id == 'proveedoresCache' ||
                id == 'tiendasCache') continue;
            final data = doc.data();
            if (data.isNotEmpty) {
              sent.add({...data, 'numeroControl': id});
            }
          }
        }
        // Ordenar descendente por fecha (más reciente arriba)
        sent.sort((a, b) {
          final fa = DateTime.tryParse(a['fecha'] ?? '') ?? DateTime(2000);
          final fb = DateTime.tryParse(b['fecha'] ?? '') ?? DateTime(2000);
          return fb.compareTo(fa);
        });
        debugPrint('Hojas de ruta individuales (sent):\n' + sent.toString());
        List<Map<String, dynamic>> filtered = List.from(sent);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterSheets(String query) {
              final q = query.toLowerCase();
              filtered = sent.where((sheet) {
                bool match = (sheet['numeroControl']
                            ?.toString()
                            .toLowerCase()
                            .contains(q) ??
                        false) ||
                    (sheet['origen']?.toString().toLowerCase().contains(q) ??
                        false) ||
                    (sheet['tipo']?.toString().toLowerCase().contains(q) ??
                        false) ||
                    (sheet['caja']?.toString().toLowerCase().contains(q) ??
                        false) ||
                    (sheet['fecha']?.toString().toLowerCase().contains(q) ??
                        false);
                if (!match && sheet['rows'] != null) {
                  for (final row in (sheet['rows'] as List)) {
                    for (final cell in (row is Map ? row.values : row)) {
                      if (cell.toString().toLowerCase().contains(q)) {
                        match = true;
                        break;
                      }
                    }
                  }
                }
                return match;
              }).toList();
              setModalState(() {});
            }

            return Scaffold(
              backgroundColor: const Color(0xFFF4F6FB),
              appBar: AppBar(
                elevation: 4,
                backgroundColor: const Color(0xFF2D6A4F),
                title: Row(
                  children: [
                    const Icon(Icons.assignment_turned_in,
                        color: Colors.white, size: 30),
                    SizedBox(width: 12),
                    const Text('Hojas de Ruta Enviadas',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 1.2,
                        )),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Forzar recarga',
                    onPressed: _forzarRecarga,
                  ),
                ],
              ),
              body: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 18),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.search,
                                    color: Color(0xFF2D6A4F)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText:
                                          'Buscar hoja, origen, tipo, caja, fecha...',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 0, horizontal: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: filterSheets,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: filtered.isEmpty
                                  ? const Center(
                                      child: Text(
                                          'No hay hojas de ruta enviadas.',
                                          style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey)),
                                    )
                                  : ListView.separated(
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 16),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, idx) {
                                        final sheet = filtered[idx];
                                        return Card(
                                          elevation: 5,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          color: Colors.white,
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 14),
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  const Color(0xFF2D6A4F),
                                              child: const Icon(
                                                  Icons.description,
                                                  color: Colors.white),
                                            ),
                                            title: Text(
                                              sheet['origen'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                color: Color(0xFF2D6A4F),
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Fecha:  ${sheet['fecha']}   •   No. Control: ${sheet['numeroControl']}',
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black87),
                                                ),
                                                Text(
                                                  'Tipo: ${sheet['tipo'] ?? ''}   •   Caja: ${sheet['caja'] ?? ''}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.print,
                                                      color: Color(0xFF2D6A4F)),
                                                  tooltip: 'Imprimir hoja',
                                                  onPressed: () async {
                                                    try {
                                                      await _printSheet(
                                                          context, sheet);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  'Error al imprimir: $e')));
                                                    }
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.picture_as_pdf,
                                                      color: Color(0xFF2D6A4F)),
                                                  tooltip: 'Imprimir carátula',
                                                  onPressed: () async {
                                                    try {
                                                      await _printCaratulaFromSheet(
                                                          context, sheet);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  'Error al imprimir carátula: $e')));
                                                    }
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.visibility,
                                                      color: Colors.blueGrey),
                                                  tooltip: 'Ver detalle',
                                                  onPressed: () =>
                                                      _showSheetDetail(
                                                          context, sheet),
                                                ),
                                                if (HojaDeRutaExtraPage.isAdmin)
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red),
                                                    tooltip: 'Eliminar',
                                                    onPressed: () async {
                                                      final confirm =
                                                          await showDialog<
                                                              bool>(
                                                        context: context,
                                                        builder: (ctx) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                              'Eliminar hoja de ruta'),
                                                          content: const Text(
                                                              '¿Estás seguro de eliminar esta hoja de ruta? Esta acción no se puede deshacer.'),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            ctx)
                                                                        .pop(
                                                                            false),
                                                                child: const Text(
                                                                    'Cancelar')),
                                                            ElevatedButton(
                                                              style: ElevatedButton
                                                                  .styleFrom(
                                                                      backgroundColor:
                                                                          Colors
                                                                              .red),
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                          ctx)
                                                                      .pop(
                                                                          true),
                                                              child: const Text(
                                                                  'Eliminar'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm != true)
                                                        return;
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                              'hoja_ruta')
                                                          .doc(sheet[
                                                              'numeroControl'])
                                                          .delete();
                                                    },
                                                  ),
                                              ],
                                            ),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                            onTap: () => _showSheetDetail(
                                                context, sheet),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
