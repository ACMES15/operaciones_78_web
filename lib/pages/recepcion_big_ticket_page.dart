import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:html' as html;

class RecepcionBigTicketPage extends StatefulWidget {
  const RecepcionBigTicketPage({Key? key}) : super(key: key);

  @override
  State<RecepcionBigTicketPage> createState() => _RecepcionBigTicketPageState();
}

class _RecepcionBigTicketPageState extends State<RecepcionBigTicketPage> {
  final List<String> _headers = [
    'OT',
    'SKU',
    'Descripción',
    'CANTIDAD',
    'ESCANEO',
    'VALIDACION',
    'DIFERENCIA',
    'MANIFIESTO',
  ];
  final List<List<String>> _rows = [];
  final TextEditingController _scanController = TextEditingController();
  String _ultimoOT = '';

  void _importFromExcel() {
    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) {
        final result = reader.result;
        final Uint8List bytes =
            result is ByteBuffer ? result.asUint8List() : (result as Uint8List);
        final excel = ex.Excel.decodeBytes(bytes);
        final List<List<String>> datos = [];
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;
          for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
            final row = sheet.row(rowIndex);
            final fila = List<String>.generate(
              _headers.length,
              (i) => i < row.length && row[i] != null
                  ? row[i]!.value.toString()
                  : '',
            );
            datos.add(fila);
          }
          break;
        }
        setState(() {
          _rows.clear();
          _rows.addAll(datos);
        });
      });
    });
  }

  void _procesarEscaneoUnico() {
    final scan = _scanController.text.trim();
    if (scan.length < 14) return; // OT (14 dígitos) + SKU (resto)
    final ot = scan.substring(0, 14);
    final sku = scan.substring(14);
    if (ot.isEmpty || sku.isEmpty) return;
    bool encontrado = false;
    for (var fila in _rows) {
      if (fila.length < _headers.length) continue;
      if (fila[0] == ot && fila[1] == sku) {
        int escaneos = int.tryParse(fila[5]) ?? 0;
        escaneos++;
        fila[5] = escaneos.toString();
        int cantidad = int.tryParse(fila[3]) ?? 0;
        int diferencia = escaneos - cantidad;
        fila[7] = diferencia.toString(); // DIFERENCIA MANIFIESTO
        if (diferencia == 0) {
          fila[6] = 'Correcto';
        } else if (diferencia > 0) {
          fila[6] = 'Sobrante';
        } else {
          fila[6] = 'Falta';
        }
        encontrado = true;
        break;
      }
    }
    if (!encontrado) {
      // Si no existe, agregar como sobrante
      final nuevaFila = List<String>.filled(_headers.length, '');
      nuevaFila[0] = ot;
      nuevaFila[1] = sku;
      nuevaFila[3] = '0'; // CANTIDAD
      nuevaFila[5] = '1'; // ESCANEO
      nuevaFila[6] = 'Sobrante';
      nuevaFila[7] = '1'; // DIFERENCIA
      _rows.add(nuevaFila);
    }
    setState(() {});
    _scanController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recepción Big Ticket',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 2,
        actions: [
          ElevatedButton.icon(
            onPressed: _importFromExcel,
            icon: const Icon(Icons.file_upload),
            label: const Text('Importar desde Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scanController,
                    decoration: const InputDecoration(
                      labelText: 'Escanear OT+SKU',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                      hintText: 'Escanea OT y luego SKU',
                    ),
                    autofocus: true,
                    onSubmitted: (_) => _procesarEscaneoUnico(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _headers.length * 180,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowColor:
                            MaterialStateProperty.all(const Color(0xFF2D6A4F)),
                        headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                        dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) {
                          if (states.contains(MaterialState.selected)) {
                            return Colors.deepPurple.shade50;
                          }
                          return null;
                        }),
                        dataTextStyle: const TextStyle(
                            fontSize: 16, color: Colors.black87),
                        columns: _headers
                            .map((h) =>
                                DataColumn(label: Center(child: Text(h))))
                            .toList(),
                        rows: _rows.isEmpty
                            ? [
                                DataRow(
                                    cells: List.generate(_headers.length,
                                        (i) => const DataCell(Text(''))))
                              ]
                            : _rows.map((fila) {
                                Color? validacionColor;
                                Color? diferenciaColor;
                                if (fila[6] == 'Correcto') {
                                  validacionColor = Colors.green.shade200;
                                } else if (fila[6] == 'Sobrante') {
                                  validacionColor = Colors.purple.shade200;
                                } else if (fila[6] == 'Falta') {
                                  validacionColor = Colors.red.shade100;
                                }
                                int diferencia = int.tryParse(fila[7]) ?? 0;
                                if (diferencia == 0) {
                                  diferenciaColor = Colors.green.shade200;
                                } else if (diferencia > 0) {
                                  diferenciaColor = Colors.purple.shade200;
                                } else {
                                  diferenciaColor = Colors.red.shade100;
                                }
                                return DataRow(
                                  cells: List.generate(_headers.length, (i) {
                                    if (i == 6) {
                                      return DataCell(
                                        Container(
                                          color: validacionColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          child: Center(child: Text(fila[i])),
                                        ),
                                      );
                                    }
                                    if (i == 7) {
                                      return DataCell(
                                        Container(
                                          color: diferenciaColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          child: Center(child: Text(fila[i])),
                                        ),
                                      );
                                    }
                                    return DataCell(
                                        Center(child: Text(fila[i])));
                                  }),
                                );
                              }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
