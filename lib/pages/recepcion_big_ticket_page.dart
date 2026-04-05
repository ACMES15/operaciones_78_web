import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:html' as html;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

class RecepcionBigTicketPage extends StatefulWidget {
  const RecepcionBigTicketPage({Key? key}) : super(key: key);

  @override
  State<RecepcionBigTicketPage> createState() => _RecepcionBigTicketPageState();
}

class _RecepcionBigTicketPageState extends State<RecepcionBigTicketPage> {
  void _finalizarEscaneo() {
    setState(() {
      for (var fila in _rows) {
        int cantidad = int.tryParse(fila[3]) ?? 0;
        int escaneo = int.tryParse(fila[4]) ?? 0;
        int diferencia = escaneo - cantidad;
        fila[6] = diferencia.toString();
        if (diferencia == 0) {
          fila[5] = 'Correcto';
        } else if (diferencia > 0) {
          fila[5] = 'Sobrante';
        } else {
          fila[5] = 'Faltante';
        }
      }
      // Mover sobrantes al final (sin modificar MANIFIESTO)
      List<List<String>> correctosYfaltantes =
          _rows.where((f) => f[5] != 'Sobrante').toList();
      List<List<String>> sobrantes =
          _rows.where((f) => f[5] == 'Sobrante').toList();
      _rows
        ..clear()
        ..addAll(correctosYfaltantes)
        ..addAll(sobrantes);
    });
  }

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
    'Acciones',
  ];

  void _actualizarJefaturaPorSeccion(int rowIdx, String nuevaSeccion) async {
    _rows[rowIdx][8] = nuevaSeccion;
    String? jefatura = _seccionToJefatura[nuevaSeccion];
    if (jefatura == null || jefatura.isEmpty) {
      // Buscar en Firestore: colección 'plantilla_ejecutiva', documento 'datos', array de objetos
      try {
        final doc = await FirebaseFirestore.instance
            .collection('plantilla_ejecutiva')
            .doc('datos')
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['datos'] is List) {
            final List<dynamic> lista = data['datos'];
            final match = lista.firstWhere(
              (e) => e is Map && e['SECCION'] == nuevaSeccion,
              orElse: () => null,
            );
            if (match != null && match['NOMBRE'] != null) {
              jefatura = match['NOMBRE'].toString();
              _seccionToJefatura[nuevaSeccion] = jefatura;
              // Actualiza el cache localStorage
              final cache =
                  html.window.localStorage['plantilla_ejecutiva_cache'];
              List<dynamic> cacheList = [];
              if (cache != null) {
                cacheList = List<dynamic>.from(jsonDecode(cache));
              }
              bool updated = false;
              for (final fila in cacheList) {
                if (fila is Map && fila['SECCION'] == nuevaSeccion) {
                  fila['NOMBRE'] = jefatura;
                  updated = true;
                  break;
                }
              }
              if (!updated) {
                cacheList.add({'SECCION': nuevaSeccion, 'NOMBRE': jefatura});
              }
              html.window.localStorage['plantilla_ejecutiva_cache'] =
                  jsonEncode(cacheList);
            } else {
              jefatura = '';
            }
          } else {
            jefatura = '';
          }
        } else {
          jefatura = '';
        }
      } catch (_) {
        jefatura = '';
      }
    }
    setState(() {
      _rows[rowIdx][9] = jefatura ?? '';
    });
  }

  // Cache de plantilla ejecutiva para búsqueda rápida
  Map<String, String> _seccionToJefatura = {};

  @override
  void initState() {
    super.initState();
    _cargarPlantillaEjecutiva();
    // Usuario se puede obtener con html.window.localStorage['usuario'] cuando se requiera
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
  final FocusNode _scanFocusNode = FocusNode();
  String? _otPendiente;

  Future<void> _importFromExcel() async {
    // Esperar a que la plantilla ejecutiva esté cargada
    if (_seccionToJefatura.isEmpty) {
      await _cargarPlantillaEjecutiva();
    }
    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) async {
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
            // OT, SKU, Descripción, CANTIDAD, ESCANEO, VALIDACION, DIFERENCIA, MANIFIESTO, SECCION, JEFATURA
            fila[0] = row.isNotEmpty && row[0] != null
                ? row[0]!.value.toString()
                : '';
            fila[1] = row.length > 1 && row[1] != null
                ? row[1]!.value.toString()
                : '';
            fila[2] = row.length > 2 && row[2] != null
                ? row[2]!.value.toString()
                : '';
            fila[3] = row.length > 3 && row[3] != null
                ? row[3]!.value.toString()
                : '';
            fila[4] = row.length > 4 && row[4] != null
                ? row[4]!.value.toString()
                : '0'; // ESCANEO (si viene, si no 0)
            fila[5] = row.length > 5 && row[5] != null
                ? row[5]!.value.toString()
                : ''; // VALIDACION
            fila[6] = row.length > 6 && row[6] != null
                ? row[6]!.value.toString()
                : '0'; // DIFERENCIA
            fila[7] = row.length > 7 && row[7] != null
                ? row[7]!.value.toString()
                : '0'; // MANIFIESTO
            fila[8] = row.length > 8 && row[8] != null
                ? row[8]!.value.toString()
                : '';
            // Buscar JEFATURA automáticamente por SECCION usando plantilla ejecutiva
            fila[9] = _seccionToJefatura[fila[8]] ?? '';
            datos.add(fila);
          }
          break;
        }
        setState(() {
          _rows.clear();
          for (final fila in datos) {
            // Asegura que cada fila tenga la longitud de _headers
            while (fila.length < _headers.length) {
              fila.add('');
            }
            _rows.add(fila);
          }
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
        FocusScope.of(context).requestFocus(_scanFocusNode);
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
          int escaneos = int.tryParse(fila[4]) ?? 0; // ESCANEO
          escaneos++;
          fila[4] = escaneos.toString();
          int cantidad = int.tryParse(fila[3]) ?? 0;
          int diferencia = escaneos - cantidad;
          fila[6] = diferencia.toString(); // DIFERENCIA
          // MANIFIESTO nunca se modifica aquí
          if (diferencia == 0) {
            fila[5] = 'Correcto';
          } else if (diferencia > 0) {
            fila[5] = 'Sobrante';
          } else {
            fila[5] = 'Faltante';
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
        nuevaFila[3] = '0'; // CANTIDAD
        nuevaFila[4] = '1'; // ESCANEO
        nuevaFila[5] = 'Sobrante'; // VALIDACION
        nuevaFila[6] = '1'; // DIFERENCIA
        nuevaFila[7] = '0'; // MANIFIESTO igual a CANTIDAD (0)
        nuevaFila[8] = '';
        nuevaFila[9] = '';
        _rows.add(nuevaFila);
      }
      setState(() {});
      _scanController.clear();
      _otPendiente = null;
      FocusScope.of(context).requestFocus(_scanFocusNode);
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
          ElevatedButton.icon(
            onPressed: _finalizarEscaneo,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Finalizar escaneo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
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
                    focusNode: _scanFocusNode,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: (_headers.length - 2) * 90.0 +
                              180 +
                              120, // 9 cols normales + JEFATURA + ACCIONES
                          maxWidth: 1800,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                                const Color(0xFF2D6A4F)),
                            headingTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                            dataRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                                    (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.deepPurple.shade50;
                              }
                              return null;
                            }),
                            dataTextStyle: const TextStyle(
                                fontSize: 10, color: Colors.black87),
                            columns: List.generate(_headers.length, (i) {
                              double fontSize = 10;
                              double? colWidth;
                              // Ajuste de ancho para campos de 3 dígitos
                              if (_headers[i] == 'CANTIDAD' ||
                                  _headers[i] == 'ESCANEO' ||
                                  _headers[i] == 'VALIDACION' ||
                                  _headers[i] == 'DIFERENCIA') {
                                colWidth = 48;
                              } else if (_headers[i] == 'JEFATURA') {
                                fontSize = 11;
                                colWidth = 180;
                              } else if (_headers[i] == 'Acciones') {
                                fontSize = 11;
                                colWidth = 120;
                              }
                              return DataColumn(
                                label: Container(
                                  width: colWidth,
                                  alignment: Alignment.center,
                                  child: Text(
                                    _headers[i],
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            rows: _rows.isEmpty
                                ? [
                                    DataRow(
                                        cells: List.generate(
                                            _headers.length,
                                            (i) => const DataCell(Text('',
                                                style:
                                                    TextStyle(fontSize: 10)))))
                                  ]
                                : List.generate(_rows.length, (rowIdx) {
                                    final fila = _rows[rowIdx];
                                    Color? validacionColor;
                                    Color? diferenciaColor;
                                    if (fila[5] == 'Correcto') {
                                      validacionColor = Colors.green.shade200;
                                    } else if (fila[5] == 'Sobrante') {
                                      validacionColor = Colors.purple.shade200;
                                    } else if (fila[5] == 'Faltante') {
                                      validacionColor = Colors.red.shade100;
                                    }
                                    int diferencia = int.tryParse(fila[6]) ?? 0;
                                    if (diferencia == 0) {
                                      diferenciaColor = Colors.green.shade200;
                                    } else if (diferencia > 0) {
                                      diferenciaColor = Colors.purple.shade200;
                                    } else {
                                      diferenciaColor = Colors.red.shade100;
                                    }
                                    return DataRow(
                                      cells:
                                          List.generate(_headers.length, (i) {
                                        if (i == 8) {
                                          // SECCION editable
                                          return DataCell(
                                            TextFormField(
                                              initialValue: fila[i],
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 1,
                                                        vertical: 0),
                                              ),
                                              style:
                                                  const TextStyle(fontSize: 10),
                                              onFieldSubmitted: (nuevoValor) {
                                                _actualizarJefaturaPorSeccion(
                                                    rowIdx, nuevoValor.trim());
                                              },
                                            ),
                                          );
                                        }
                                        if (i == 9) {
                                          // JEFATURA no editable
                                          return DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                      vertical: 0),
                                              child: Center(
                                                  child: Text(fila[i],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 10))),
                                            ),
                                          );
                                        }
                                        if (i == 5) {
                                          return DataCell(
                                            Container(
                                              color: validacionColor,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                      vertical: 0),
                                              child: Center(
                                                  child: Text(fila[i],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 10))),
                                            ),
                                          );
                                        }
                                        if (i == 6) {
                                          return DataCell(
                                            Container(
                                              color: diferenciaColor,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                      vertical: 0),
                                              child: Center(
                                                  child: Text(fila[i],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 10))),
                                            ),
                                          );
                                        }
                                        if (i == 7) {
                                          // MANIFIESTO solo lectura, sin color especial
                                          return DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                      vertical: 0),
                                              child: Center(
                                                  child: Text(fila[i],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 10))),
                                            ),
                                          );
                                        }
                                        if (i == 10) {
                                          // Acciones: eliminar fila
                                          return DataCell(
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              tooltip: 'Eliminar fila',
                                              onPressed: () {
                                                setState(() {
                                                  _rows.removeAt(rowIdx);
                                                });
                                              },
                                            ),
                                          );
                                        }
                                        if (i == 2) {
                                          // DESCRIPCIÓN con máximo 10 caracteres y '...'
                                          String desc = fila[i];
                                          String displayDesc = desc.length > 10
                                              ? desc.substring(0, 10) + '...'
                                              : desc;
                                          return DataCell(Center(
                                            child: Text(
                                              displayDesc,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            ),
                                          ));
                                        }
                                        return DataCell(Center(
                                            child: Text(fila[i],
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 10))));
                                      }),
                                    );
                                  }),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Eliminado bloque duplicado y corregido el índice de diferencia en la tabla principal
          ],
        ),
      ),
    );
  }
}
