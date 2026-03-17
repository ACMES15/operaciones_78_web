import 'package:flutter/material.dart';
import 'entregas_recogidos_page.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Definición única en el nivel superior
class RecogidosPage extends StatefulWidget {
  final String usuario;
  const RecogidosPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<RecogidosPage> createState() => _RecogidosPageState();
}

class _RecogidosPageState extends State<RecogidosPage> {
  bool _listenerAgregado = false;
  List<Map<String, dynamic>> _ultimaEntregaGuardada = [];
  DateTime? _ultimaFechaEntrega;
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocus = FocusNode();
  String _scanSeccion = '';
  String _scanDepartamento = '';
  final List<String> _headers = [
    'LP',
    'SECCION',
    'JEFATURA',
    'BOX',
    'VALIDACION',
  ];
  List<List<TextEditingController>> _rows = [];

  Future<void> _buscarJefaturaFirestore(
      String seccion, Function(String) onResult) async {
    final doc = await FirebaseFirestore.instance
        .collection('plantilla_ejecutiva')
        .doc('datos')
        .get();
    if (doc.exists && doc.data() != null) {
      final datos = doc.data()!['datos'] as List<dynamic>?;
      if (datos != null) {
        for (final fila in datos) {
          if (fila is Map<String, dynamic> &&
              fila['SECCION'].toString().trim().toUpperCase() ==
                  seccion.trim().toUpperCase()) {
            onResult(fila['NOMBRE']?.toString() ?? '');
            return;
          }
        }
      }
    }
    onResult('');
  }

  void _addRow() {
    setState(() {
      _rows.add(List.generate(_headers.length, (_) => TextEditingController()));
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scanFocus.dispose();
    for (var row in _rows) {
      for (var ctrl in row) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  void _importFromExcel() {
    if (!kIsWeb) return;
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
            final fila = List<String>.generate(
              _headers.length,
              (i) => i < row.length && row[i] != null
                  ? row[i]?.value?.toString() ?? ''
                  : '',
            );
            datos.add(fila);
          }
          break;
        }
        for (var row in _rows) {
          for (var ctrl in row) {
            ctrl.dispose();
          }
        }
        setState(() {
          _rows.clear();
        });
        for (final fila in datos) {
          final List<TextEditingController> ctrls =
              List.generate(_headers.length, (i) {
            final ctrl = TextEditingController();
            if (_headers[i] == 'LP' && i < fila.length) {
              final lp = fila[i].padLeft(10, '0');
              ctrl.text = lp;
            } else {
              ctrl.text = i < fila.length ? fila[i] : '';
            }
            return ctrl;
          });
          final idxSeccion = _headers.indexOf('SECCION');
          final idxJefatura = _headers.indexOf('JEFATURA');
          if (idxSeccion != -1 && idxJefatura != -1) {
            final seccion = ctrls[idxSeccion].text.trim();
            if (seccion.isNotEmpty) {
              await _buscarJefaturaFirestore(seccion, (nombre) {
                ctrls[idxJefatura].text = nombre;
              });
            }
          }
          setState(() {
            _rows.add(ctrls);
          });
        }
        if (_rows.isEmpty) {
          setState(() {
            _rows.add(
                List.generate(_headers.length, (_) => TextEditingController()));
          });
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Diagnóstico de importación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Encabezados detectados:'),
                SelectableText(_headers.join(', ')),
                const SizedBox(height: 8),
                Text('Filas importadas: ${_rows.length}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      });
    });
  }

  // ...existing code para guardar, validar, notificar...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recogidos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar fila'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _importFromExcel,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Importar desde Excel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _headers.length * 140,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.grey[200],
                        child: Row(
                          children: List.generate(_headers.length, (i) {
                            return Container(
                              width: 140,
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _headers[i],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, rowIdx) {
                            return Row(
                              children:
                                  List.generate(_headers.length, (colIdx) {
                                final isJefatura =
                                    _headers[colIdx] == 'JEFATURA';
                                final isSeccion = _headers[colIdx] == 'SECCION';
                                if (isJefatura) {
                                  return Container(
                                    width: 140,
                                    padding: const EdgeInsets.all(4),
                                    child: TextField(
                                      controller: _rows[rowIdx][colIdx],
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 4),
                                      ),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  );
                                } else if (isSeccion) {
                                  return Container(
                                    width: 140,
                                    padding: const EdgeInsets.all(4),
                                    child: TextField(
                                      controller: _rows[rowIdx][colIdx],
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 4),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                      onChanged: (value) async {
                                        await _buscarJefaturaFirestore(
                                            value.trim(), (jefatura) {
                                          setState(() {
                                            _rows[rowIdx][_headers
                                                    .indexOf('JEFATURA')]
                                                .text = jefatura;
                                          });
                                        });
                                      },
                                    ),
                                  );
                                } else {
                                  return Container(
                                    width: 140,
                                    padding: const EdgeInsets.all(4),
                                    child: TextField(
                                      controller: _rows[rowIdx][colIdx],
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 4),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }
                              }),
                            );
                          },
                        ),
                      ),
                    ],
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
