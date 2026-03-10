import 'package:flutter/material.dart';
import 'hoja_de_ruta_extra_page.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeRutaEnviadasPage extends StatelessWidget {
  const HojaDeRutaEnviadasPage({super.key});

  Future<void> _printSheet(
      BuildContext context, Map<String, dynamic> sheet) async {
    try {
      final pdf = pw.Document();
      final rawRows =
          (sheet['rows'] is List) ? List.from(sheet['rows']) : <dynamic>[];
      final headers = sheet['headers'] != null
          ? List<String>.from(sheet['headers'])
          : (rawRows.isNotEmpty
              ? (rawRows[0] is List
                  ? List.generate(
                      (rawRows[0] as List).length, (i) => 'Col${i + 1}')
                  : (rawRows[0] is Map
                      ? (rawRows[0] as Map)
                          .keys
                          .map((k) => k.toString())
                          .toList()
                      : []))
              : []);

      final data = <List<String>>[];
      for (final r in rawRows) {
        if (r is List) {
          data.add(r.map((c) => c.toString()).toList());
        } else if (r is Map) {
          data.add((r as Map).values.map((v) => v.toString()).toList());
        } else {
          data.add([r.toString()]);
        }
      }

      final pageFormat = PdfPageFormat.letter;
      pdf.addPage(pw.MultiPage(
          pageFormat: pageFormat,
          build: (context) {
            return <pw.Widget>[
              pw.Text('Liverpool GDL 78 - Hoja de ruta',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Origen: ${sheet['origen']}    Fecha: ${sheet['fecha']}'),
              pw.SizedBox(height: 12),
              if (data.isNotEmpty)
                pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  headerStyle:
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellStyle: pw.TextStyle(fontSize: 8),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                  columnWidths: {
                    for (var i = 0; i < data[0].length; i++)
                      i: const pw.FlexColumnWidth(1)
                  },
                ),
            ];
          }));

      // En web: abrir PDF en nueva pestaña (el usuario puede imprimir desde el navegador)
      if (kIsWeb) {
        // Para evitar bloqueos de popup: abrir una pestaña vacía primero (user gesture),
        // luego cargar el PDF una vez generado.
        final newWindow = html.window.open('', '_blank');
        final bytes = await pdf.save();
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        try {
          newWindow.location.href = url;
        } catch (_) {
          // fallback: crear un <a> con download y disparar click para forzar descarga
          try {
            final anchor =
                html.document.createElement('a') as html.AnchorElement;
            anchor.href = url;
            anchor.download = 'hoja_de_ruta.pdf';
            anchor.style.display = 'none';
            html.document.body!.append(anchor);
            anchor.click();
            anchor.remove();
          } catch (e) {
            html.window.open(url, '_blank');
          }
        }
        // revoke after un poco de tiempo
        Future.delayed(const Duration(seconds: 5), () {
          try {
            html.Url.revokeObjectUrl(url);
          } catch (_) {}
        });
        return;
      }

      // En plataformas desktop/mesa: permitir al usuario elegir impresora y enviar directamente
      try {
        final printer = await Printing.pickPrinter(context: context);
        if (printer != null) {
          await Printing.directPrintPdf(
            printer: printer,
            onLayout: (PdfPageFormat format) async => pdf.save(),
          );
          return;
        }
      } catch (e) {
        // ignore and fallback to layoutPdf
      }

      // Fallback: abrir diálogo de impresión con tamaño carta
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        usePrinterSettings: true,
        name: 'Hoja de ruta',
        format: pageFormat,
      );
    } catch (e, st) {
      // Mostrar error al usuario para ayudar debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar/imprimir PDF: $e')),
      );
      debugPrint('Error _printSheet: $e\n$st');
    }
  }

  void _showSheetDetail(BuildContext context, Map<String, dynamic> sheet) {
    // Asegurar que rows sea List<List<String>> aunque venga como List<Map> de Firestore
    List<List<String>> rows = [];
    if (sheet['rows'] != null && sheet['rows'] is List) {
      final rawRows = sheet['rows'] as List;
      if (rawRows.isNotEmpty && rawRows.first is Map) {
        // Convertir List<Map> a List<List<String>>
        rows = rawRows
            .map((e) => (e as Map).values.map((v) => v.toString()).toList())
            .toList();
      } else {
        rows = rawRows.map((e) => List<String>.from(e)).toList();
      }
    }
    final List<String> columns = sheet['headers'] != null
        ? List<String>.from(sheet['headers'])
        : (rows.isNotEmpty
            ? List.generate(rows[0].length, (i) => 'Col${i + 1}')
            : []);
    final List<List<TextEditingController>> rowControllers = List.generate(
      rows.length,
      (i) => List.generate(
        rows[i].length,
        (j) => TextEditingController(text: rows[i][j]),
      ),
    );
    void saveEdits(StateSetter setModalState) {
      sheet['rows'] = rowControllers
          .map((r) => r.map((c) => c.text.trim()).toList())
          .toList();
      Navigator.of(context).pop();
    }

    void deleteSheet(StateSetter setModalState) {
      HojaDeRutaExtraPage.sentHojaRutas.remove(sheet);
      Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final double maxWidth = MediaQuery.of(context).size.width * 0.95;
          double colWidth = ((maxWidth - 48) / columns.length).clamp(70, 120);
          final double minTableWidth = columns.length * colWidth;
          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.95),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cerrar',
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context).pop();
                            })),
                    // Cabecera: ORIGEN / Tipo de hoja
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ORIGEN',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(sheet['origen'] ?? '',
                                      style: const TextStyle(fontSize: 15)),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    const Text('No. de Caja:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                        width: 80,
                                        child: Text(sheet['caja'] ?? '',
                                            style:
                                                const TextStyle(fontSize: 15))),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Text('Fecha de Envío:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text(sheet['fecha'] ?? '')
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Text('Núm. de control:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    if ((sheet['numeroControl'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(sheet['numeroControl'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold)),
                                  ]),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tipo de hoja:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 8),
                                  Text(sheet['tipo'] ?? '',
                                      style: const TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Tabla
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minWidth: minTableWidth),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Card(
                                elevation: 1,
                                margin: const EdgeInsets.all(0),
                                child: DataTable(
                                  columnSpacing: 2,
                                  dataRowMinHeight: 28,
                                  dataRowMaxHeight: 32,
                                  headingRowHeight: 34,
                                  columns:
                                      List.generate(columns.length, (colIdx) {
                                    return DataColumn(
                                      label: Container(
                                        alignment: Alignment.center,
                                        width: colWidth,
                                        decoration: BoxDecoration(
                                          border: colIdx < columns.length - 1
                                              ? const Border(
                                                  right: BorderSide(
                                                      color: Color(0xFFE0E0E0),
                                                      width: 1))
                                              : null,
                                        ),
                                        child: Text(columns[colIdx],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                    );
                                  }),
                                  rows: List.generate(rowControllers.length,
                                      (rowIdx) {
                                    final rowCtrls = rowControllers[rowIdx];
                                    return DataRow(
                                        cells: List.generate(columns.length,
                                            (colIdx) {
                                      return DataCell(Container(
                                        alignment: Alignment.center,
                                        width: colWidth,
                                        decoration: BoxDecoration(
                                          border: colIdx < columns.length - 1
                                              ? const Border(
                                                  right: BorderSide(
                                                      color: Color(0xFFE0E0E0),
                                                      width: 1))
                                              : null,
                                        ),
                                        child: TextField(
                                          controller: rowCtrls[colIdx],
                                          enabled: HojaDeRutaExtraPage.isAdmin,
                                          textAlign: TextAlign.center,
                                          decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 4)),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ));
                                    }));
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (HojaDeRutaExtraPage.isAdmin) ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar cambios'),
                          onPressed: () => saveEdits(setModalState),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Eliminar'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => deleteSheet(setModalState),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Imprimir'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _printSheet(context, sheet);
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar')),
                    ]),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc('sentHojaRutas')
          .snapshots(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> sent = [];
        final data = snapshot.data?.data();
        if (snapshot.hasData && data != null && data['items'] != null) {
          sent = List<Map<String, dynamic>>.from(
            (data['items'] as List).map((e) => Map<String, dynamic>.from(e)),
          ).reversed.toList();
        }
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
                    if (match) break;
                  }
                }
                return match;
              }).toList();
              setModalState(() {});
            }

            return Scaffold(
              appBar: AppBar(
                  title: const Text('Hoja de ruta enviadas'),
                  backgroundColor: const Color.fromARGB(184, 69, 70, 69)),
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar hoja de ruta',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: filterSheets,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No hay hojas de ruta enviadas'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final sheet = filtered[idx];
                                return Card(
                                  child: ListTile(
                                    title: Text('Hoja: ${sheet['createdAt']}'),
                                    subtitle: Text(
                                        'Fecha: ${sheet['fecha']}  •  No. Control: ${sheet['numeroControl']}'),
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                              icon: const Icon(Icons.print),
                                              onPressed: () async {
                                                try {
                                                  await _printSheet(
                                                      context, sheet);
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              'Error al imprimir: $e')));
                                                }
                                              }),
                                          IconButton(
                                              icon:
                                                  const Icon(Icons.visibility),
                                              onPressed: () => _showSheetDetail(
                                                  context, sheet)),
                                          if (HojaDeRutaExtraPage.isAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              tooltip: 'Eliminar',
                                              onPressed: () async {
                                                HojaDeRutaExtraPage
                                                    .sentHojaRutas
                                                    .remove(sheet);
                                                await guardarDatosFirestoreYCache(
                                                    'hoja_ruta',
                                                    'sentHojaRutas', {
                                                  'items': HojaDeRutaExtraPage
                                                      .sentHojaRutas
                                                });
                                              },
                                            ),
                                        ]),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
