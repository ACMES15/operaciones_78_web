import 'package:flutter/material.dart';
import 'hoja_de_ruta_extra_page.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeRutaEnviadasPage extends StatelessWidget {
  const HojaDeRutaEnviadasPage({super.key});

  Future<void> _printSheet(Map<String, dynamic> sheet) async {
    final pdf = pw.Document();
    final headers = sheet['headers'] != null
        ? List<String>.from(sheet['headers'])
        : (sheet['rows'].isNotEmpty
            ? (sheet['rows'][0] as List)
                .asMap()
                .keys
                .map((i) => 'Col${i + 1}')
                .toList()
            : []);
    final data = List<List<String>>.from(
        sheet['rows'].map<List<String>>((r) => List<String>.from(r)));

    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return <pw.Widget>[
            pw.Text('Liverpool GDL 78 - Hoja de ruta',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
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

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _showSheetDetail(BuildContext context, Map<String, dynamic> sheet) {
    showDialog(
      context: context,
      builder: (context) {
        // Copia editable de las filas
        final List<String> columns = sheet['headers'] != null
            ? List<String>.from(sheet['headers'])
            : (sheet['rows'].isNotEmpty
                ? (sheet['rows'][0] as List)
                    .asMap()
                    .keys
                    .map((i) => 'Col${i + 1}')
                    .toList()
                : []);
        final List<List<TextEditingController>> rowControllers = List.generate(
          sheet['rows'].length,
          (i) => List.generate(
            (sheet['rows'][i] as List).length,
            (j) => TextEditingController(text: sheet['rows'][i][j]),
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
                          await _printSheet(sheet);
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
    return FutureBuilder(
      future: HojaDeRutaExtraPage.loadSentHojaRutasCache()
          .then((_) => leerDatosConCache('hoja_ruta', 'sentHojaRutas')),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> sent = [];
        final data = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            data != null &&
            data is Map &&
            data['items'] != null) {
          sent = List<Map<String, dynamic>>.from(
            (data['items'] as List).map((e) => Map<String, dynamic>.from(e)),
          ).reversed.toList();
        }
        List<Map<String, dynamic>> filtered = List.from(sent);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void reloadSheets() async {
              await HojaDeRutaExtraPage.loadSentHojaRutasCache();
              final newData =
                  await leerDatosConCache('hoja_ruta', 'sentHojaRutas');
              sent = [];
              if (newData != null && newData['items'] != null) {
                sent = List<Map<String, dynamic>>.from(
                  (newData['items'] as List)
                      .map((e) => Map<String, dynamic>.from(e)),
                ).reversed.toList();
              }
              filtered = List.from(sent);
              setModalState(() {});
            }

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
                    for (final cell in (row as List)) {
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
                                              onPressed: () =>
                                                  _printSheet(sheet)),
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
                                                reloadSheets();
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
