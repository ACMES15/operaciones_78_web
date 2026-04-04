import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:html' as html;
import 'dart:convert';

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
    'SECCION',
    'JEFATURA',
  ];

  void _actualizarJefaturaPorSeccion(int rowIdx, String nuevaSeccion) {
    setState(() {
      _rows[rowIdx][8] = nuevaSeccion;
      _rows[rowIdx][9] = _seccionToJefatura[nuevaSeccion] ?? '';
    });
  }

  // Cache de plantilla ejecutiva para búsqueda rápida
  Map<String, String> _seccionToJefatura = {};
  @override
  void initState() {
    super.initState();
    _cargarPlantillaEjecutiva();
  }

  Future<void> _cargarPlantillaEjecutiva() async {
    // Carga la plantilla ejecutiva de Firestore
    try {
      final snapshot =
          await html.window.localStorage['plantilla_ejecutiva_cache'];
      if (snapshot != null) {
        final List<dynamic> datos = List<dynamic>.from(jsonDecode(snapshot));
        for (final fila in datos) {
          if (fila is Map &&
              fila['SECCION'] != null &&
              fila['NOMBRE'] != null) {
            _seccionToJefatura[fila['SECCION'].toString()] =
                fila['NOMBRE'].toString();
          }
        }
        setState(() {});
      }
    } catch (_) {}
    // Si no hay cache local, podrías agregar aquí una consulta a Firestore si es necesario
  }

  final List<List<String>> _rows = [];
  final TextEditingController _scanController = TextEditingController();
  String? _otPendiente;

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
            final fila = List<String>.filled(_headers.length, '');
            // OT, SKU, SECCION, JEFATURA, Descripción, CANTIDAD, ESCANEO, VALIDACION, DIFERENCIA, MANIFIESTO
            fila[0] = row.isNotEmpty && row[0] != null
                ? row[0]!.value.toString()
                : '';
            fila[1] = row.length > 1 && row[1] != null
                ? row[1]!.value.toString()
                : '';
            fila[2] = row.length > 2 && row[2] != null
                ? row[2]!.value.toString()
                : '';
            // Buscar JEFATURA por SECCION
            fila[3] = _seccionToJefatura[fila[2]] ?? '';
            fila[4] = row.length > 3 && row[3] != null
                ? row[3]!.value.toString()
                : '';
            fila[5] = row.length > 4 && row[4] != null
                ? row[4]!.value.toString()
                : '';
            fila[6] = '0'; // ESCANEO
            fila[7] = ''; // VALIDACION
            fila[8] = '0'; // DIFERENCIA
            fila[9] = '0'; // MANIFIESTO
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
    if (_otPendiente == null) {
      // Esperando OT
      if (scan.length == 14) {
        _otPendiente = scan;
        _scanController.clear();
        setState(() {});
      }
      // Si no es una OT válida, no hace nada
      return;
    } else {
      // Esperando SKU
      final ot = _otPendiente!;
      final sku = scan;
      if (sku.isEmpty) return;
      bool encontrado = false;
      for (var fila in _rows) {
        if (fila.length < _headers.length) continue;
        if (fila[0] == ot && fila[1] == sku) {
          int escaneos = int.tryParse(fila[6]) ?? 0; // ESCANEO
          escaneos++;
          fila[6] = escaneos.toString();
          int cantidad = int.tryParse(fila[5]) ?? 0;
          int diferencia = escaneos - cantidad;
          fila[8] = diferencia.toString(); // DIFERENCIA
          fila[9] = (cantidad - escaneos).toString(); // MANIFIESTO
          if (diferencia == 0) {
            fila[7] = 'Correcto';
          } else if (diferencia > 0) {
            fila[7] = 'Sobrante';
          } else {
            fila[7] = 'Falta';
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
        nuevaFila[2] = '';
        nuevaFila[3] = '';
        nuevaFila[4] = '';
        nuevaFila[5] = '0'; // CANTIDAD
        nuevaFila[6] = '1'; // ESCANEO
        nuevaFila[7] = 'Sobrante'; // VALIDACION
        nuevaFila[8] = '1'; // DIFERENCIA
        nuevaFila[9] = '-1'; // MANIFIESTO (no existe en manifiesto)
        _rows.add(nuevaFila);
      }
      setState(() {});
      _scanController.clear();
      _otPendiente = null;
    }
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
                    decoration: InputDecoration(
                      labelText:
                          _otPendiente == null ? 'Escanear OT' : 'Escanear SKU',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code),
                      hintText: _otPendiente == null
                          ? 'Escanea la OT y presiona ENTER'
                          : 'Escanea el SKU y presiona ENTER',
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: _headers.length * 140, maxWidth: 1400),
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
                            .map((h) => DataColumn(
                                label: Center(
                                    child: Text(h,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2))))
                            .toList(),
                        rows: _rows.isEmpty
                            ? [
                                DataRow(
                                    cells: List.generate(_headers.length,
                                        (i) => const DataCell(Text(''))))
                              ]
                            : List.generate(_rows.length, (rowIdx) {
                                final fila = _rows[rowIdx];
                                Color? validacionColor;
                                Color? diferenciaColor;
                                Color? manifiestoColor;
                                if (fila[7] == 'Correcto') {
                                  validacionColor = Colors.green.shade200;
                                } else if (fila[7] == 'Sobrante') {
                                  validacionColor = Colors.purple.shade200;
                                } else if (fila[7] == 'Falta') {
                                  validacionColor = Colors.red.shade100;
                                }
                                int diferencia = int.tryParse(fila[8]) ?? 0;
                                if (diferencia == 0) {
                                  diferenciaColor = Colors.green.shade200;
                                } else if (diferencia > 0) {
                                  diferenciaColor = Colors.purple.shade200;
                                } else {
                                  diferenciaColor = Colors.red.shade100;
                                }
                                int manifiesto = int.tryParse(fila[9]) ?? 0;
                                if (manifiesto == 0) {
                                  manifiestoColor = Colors.green.shade200;
                                } else if (manifiesto > 0) {
                                  manifiestoColor = Colors.red.shade100;
                                } else {
                                  manifiestoColor = Colors.purple.shade200;
                                }
                                return DataRow(
                                  cells: List.generate(_headers.length, (i) {
                                    if (i == 2) {
                                      // SECCION editable
                                      return DataCell(
                                        TextFormField(
                                          initialValue: fila[i],
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 4, vertical: 2),
                                          ),
                                          style: const TextStyle(fontSize: 15),
                                          onFieldSubmitted: (nuevoValor) {
                                            _actualizarJefaturaPorSeccion(
                                                rowIdx, nuevoValor.trim());
                                          },
                                        ),
                                      );
                                    }
                                    if (i == 3) {
                                      // JEFATURA no editable
                                      return DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          child: Center(
                                              child: Text(fila[i],
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                        ),
                                      );
                                    }
                                    if (i == 7) {
                                      return DataCell(
                                        Container(
                                          color: validacionColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          child: Center(
                                              child: Text(fila[i],
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                        ),
                                      );
                                    }
                                    if (i == 8) {
                                      return DataCell(
                                        Container(
                                          color: diferenciaColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          child: Center(
                                              child: Text(fila[i],
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                        ),
                                      );
                                    }
                                    if (i == 9) {
                                      return DataCell(
                                        Container(
                                          color: manifiestoColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          child: Center(
                                              child: Text(fila[i],
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                        ),
                                      );
                                    }
                                    return DataCell(Center(
                                        child: Text(fila[i],
                                            overflow: TextOverflow.ellipsis)));
                                  }),
                                );
                              }),
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
