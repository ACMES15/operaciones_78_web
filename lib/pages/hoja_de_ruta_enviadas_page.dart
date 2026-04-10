import 'dart:async';
import 'package:flutter/material.dart';
import 'hoja_de_ruta_extra_page.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeRutaEnviadasPage extends StatefulWidget {
  const HojaDeRutaEnviadasPage({super.key});

  @override
  State<HojaDeRutaEnviadasPage> createState() => _HojaDeRutaEnviadasPageState();
}

class _HojaDeRutaEnviadasPageState extends State<HojaDeRutaEnviadasPage> {
  Future<void> _printCaratulaFromSheet(
      BuildContext context, Map<String, dynamic> sheet) async {
    final origen = sheet['origen'] ?? '';
    final tipo = sheet['tipo'] ?? '';
    final numeroControl = sheet['numeroControl'] ?? '';
    final fechaEnvio = sheet['fecha'] ?? '';
    final caja = sheet['caja'] ?? '';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text('CARÁTULA HOJA DE RUTA',
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Origen:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(origen, style: pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Fecha:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(fechaEnvio, style: pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tipo:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(tipo, style: pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('N° Caja:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(caja, style: pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('N° de control:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(numeroControl, style: pw.TextStyle(fontSize: 14)),
            ],
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
                  child: pw.Text('', style: pw.TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showSheetDetail(BuildContext context, Map<String, dynamic> sheet) {
    // Alinear los datos de cada fila al orden de headers
    List<List<String>> rows = [];
    final List<String> columns =
        sheet['headers'] != null ? List<String>.from(sheet['headers']) : [];
    if (sheet['rows'] != null && sheet['rows'] is List && columns.isNotEmpty) {
      final rawRows = sheet['rows'] as List;
      for (final row in rawRows) {
        if (row is Map) {
          // Ordenar los valores según headers
          rows.add(columns.map((h) => row[h]?.toString() ?? '').toList());
        } else if (row is List) {
          rows.add(List<String>.from(row.map((e) => e.toString())));
        }
      }
    }
    final List<List<TextEditingController>> rowControllers = List.generate(
        rows.length,
        (i) => List.generate(
            rows[i].length, (j) => TextEditingController(text: rows[i][j])));

    void saveEdits(StateSetter setModalState) async {
      // Actualizar los datos en Firestore
      final newRows = rowControllers
          .map((r) => r.map((c) => c.text.trim()).toList())
          .toList();
      await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(sheet['numeroControl'])
          .update({'rows': newRows});
      Navigator.of(context).pop();
    }

    void deleteSheet(StateSetter setModalState) async {
      await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(sheet['numeroControl'])
          .delete();
      Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final double maxWidth = MediaQuery.of(context).size.width * 0.95;
          double colWidth =
              ((maxWidth - 48) / (columns.isNotEmpty ? columns.length : 1))
                  .clamp(70, 120);
          final double minTableWidth = columns.length * colWidth;

          // Build table columns and rows in variables to keep widget tree readable
          final tableColumns = List.generate(
            columns.length,
            (colIdx) => DataColumn(
              label: Container(
                alignment: Alignment.center,
                width: colWidth,
                decoration: BoxDecoration(
                  border: colIdx < columns.length - 1
                      ? const Border(
                          right: BorderSide(color: Color(0xFFE0E0E0), width: 1))
                      : null,
                ),
                child: Text(columns[colIdx],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          );

          final tableRows = List.generate(rowControllers.length, (rowIdx) {
            final rowCtrls = rowControllers[rowIdx];
            return DataRow(
              cells: List.generate(columns.length, (colIdx) {
                return DataCell(
                  Container(
                    alignment: Alignment.center,
                    width: colWidth,
                    decoration: BoxDecoration(
                      border: colIdx < columns.length - 1
                          ? const Border(
                              right: BorderSide(
                                  color: Color(0xFFE0E0E0), width: 1))
                          : null,
                    ),
                    child: HojaDeRutaExtraPage.isAdmin
                        ? TextField(
                            controller: rowCtrls[colIdx],
                            enabled: true,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 4)),
                            style: const TextStyle(fontSize: 13),
                          )
                        : Text(
                            rowCtrls[colIdx].text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                );
              }),
            );
          });

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
                        },
                      ),
                    ),
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
                                  Row(
                                    children: [
                                      const Text('No. de Caja:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                          width: 80,
                                          child: Text(sheet['caja'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 15))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Fecha de Envío:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Text(sheet['fecha'] ?? '')
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
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
                                    ],
                                  ),
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
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 16,
                                    dataRowMinHeight: 28,
                                    dataRowMaxHeight: 32,
                                    headingRowHeight: 34,
                                    columns: tableColumns,
                                    rows: tableRows,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
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
      final headers = sheet['headers'] != null
          ? List<String>.from(sheet['headers'])
          : (sheet['rows'] != null &&
                  (sheet['rows'] as List).isNotEmpty &&
                  (sheet['rows'] as List).first is Map
              ? (sheet['rows'][0] as Map).keys.map((k) => k.toString()).toList()
              : []);
      final data = (sheet['rows'] as List?)?.map((row) {
            if (row is List) {
              return row.map((e) => e.toString()).toList();
            } else if (row is Map) {
              return headers.map((h) => row[h]?.toString() ?? '').toList();
            } else {
              return [row.toString()];
            }
          }).toList() ??
          [];
      final origen = sheet['origen'] ?? '';
      final fecha = sheet['fecha'] ?? '';
      final caja = sheet['caja'] ?? '';
      final tipo = sheet['tipo'] ?? '';
      final numeroControl = sheet['numeroControl'] ?? '';

      // Estimación simple: ancho proporcional a la longitud máxima de texto (caracteres) de cada columna
      List<double> colWidths = List.filled(headers.length, 0);
      const double fontSize = 10.0;
      for (int i = 0; i < headers.length; i++) {
        int maxLen = headers[i].length;
        for (final row in data) {
          if (i < row.length) {
            final l = row[i].toString().length;
            if (l > maxLen) maxLen = l;
          }
        }
        // 7.5 es un factor empírico para tamaño de fuente 10
        colWidths[i] = (maxLen * 7.5).clamp(40, 320);
      }
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text('Hoja de Ruta',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Expanded(
                  child: pw.Text('Origen: $origen',
                      style: pw.TextStyle(fontSize: 12))),
              pw.SizedBox(width: 16),
              pw.Text('N° Caja: $caja', style: pw.TextStyle(fontSize: 12)),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.Expanded(
                  child: pw.Text('Fecha: $fecha',
                      style: pw.TextStyle(fontSize: 12))),
              pw.SizedBox(width: 16),
              pw.Text('Tipo: $tipo', style: pw.TextStyle(fontSize: 12)),
            ]),
            pw.SizedBox(height: 4),
            pw.Text('N° de control: $numeroControl',
                style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 12),
            if (headers.isNotEmpty && data.isNotEmpty)
              pw.Container(
                width: double.infinity,
                child: pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
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
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
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
                                  overflow: pw.TextOverflow.clip,
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
