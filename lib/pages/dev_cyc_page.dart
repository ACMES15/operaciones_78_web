import 'package:flutter/material.dart';
import 'entregas_cyc_page.dart';
import 'historial_entregas_cyc_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class DevCycPage extends StatefulWidget {
  final String usuario;
  const DevCycPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<DevCycPage> createState() => _DevCycPageState();
}

class _DevCycPageState extends State<DevCycPage> {
  final List<String> _headers = [
    'NUMERO DE PEDIDO',
    'LP',
    'SKU',
    'DESCRIPCION',
    'SECCION',
    'BODEGA',
    'JEFATURA',
  ];
  final List<List<TextEditingController>> _rows = [];
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (_rows.isEmpty) {
      _addRow();
    }
  }

  void _addRow() {
    setState(() {
      _rows.add(List.generate(_headers.length, (_) => TextEditingController()));
    });
  }

  Future<String> _buscarJefaturaFirestore(String seccion) async {
    if (seccion.isEmpty) return '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();
      final data = doc.data();
      if (data != null && data['datos'] is List) {
        final List<dynamic> lista = data['datos'];
        final encontrado = lista.firstWhere(
          (item) => (item['SECCION'] ?? '').toString().trim() == seccion.trim(),
          orElse: () => null,
        );
        if (encontrado != null && encontrado['NOMBRE'] != null) {
          return encontrado['NOMBRE'].toString();
        }
      }
    } catch (e) {
      print('Error buscando JEFATURA en Firestore: $e');
    }
    return '';
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
                  ? row[i]!.value.toString()
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
        List<List<TextEditingController>> nuevasFilas = [];
        List<Future<void>> jefaturaFutures = [];
        for (final fila in datos) {
          final List<TextEditingController> ctrls =
              List.generate(_headers.length, (i) {
            final ctrl = TextEditingController();
            ctrl.text = i < fila.length ? fila[i] : '';
            return ctrl;
          });
          final idxSeccion = _headers.indexOf('SECCION');
          final idxJefatura = _headers.indexOf('JEFATURA');
          if (idxSeccion != -1 && idxJefatura != -1) {
            final seccion = ctrls[idxSeccion].text.trim();
            if (seccion.isNotEmpty) {
              jefaturaFutures
                  .add(_buscarJefaturaFirestore(seccion).then((jefatura) {
                ctrls[idxJefatura].text = jefatura;
              }));
            }
          }
          nuevasFilas.add(ctrls);
        }
        await Future.wait(jefaturaFutures);
        if (nuevasFilas.isEmpty) {
          nuevasFilas.add(
              List.generate(_headers.length, (_) => TextEditingController()));
        }
        setState(() {
          _rows.clear();
          _rows.addAll(nuevasFilas);
          if (_rows.isEmpty) {
            _addRow();
          }
        });
      });
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

  void _guardarEnFirestore() async {
    final List<Map<String, dynamic>> datos = [];
    for (final row in _rows) {
      final fila = <String, dynamic>{};
      for (int i = 0; i < _headers.length; i++) {
        fila[_headers[i]] = row[i].text.trim();
      }
      if (fila.values.any((v) => v != null && v.toString().isNotEmpty)) {
        datos.add(fila);
      }
    }
    if (datos.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection('entregas_cyc');
    for (final fila in datos) {
      final doc = col.doc();
      fila['id'] = doc.id;
      fila['usuarioValido'] = widget.usuario;
      batch.set(doc, fila);
    }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos guardados en Firestore')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile =
        mediaQuery.size.shortestSide <= 600 || mediaQuery.size.width < 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.assignment, color: Color(0xFF2D6A4F), size: 32),
                SizedBox(width: 10),
                Text(
                  'Dev CyC',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    color: Color(0xFF2D6A4F),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isMobile)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            EntregasCycPage(usuario: widget.usuario),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Ver Entregas CyC'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 200, 220, 255),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 18),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar fila'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 224, 230, 227),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _importFromExcel,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Importar desde Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 216, 222, 220),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _guardarEnFirestore,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 173, 220, 183),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EntregasCycPage(usuario: widget.usuario),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Ver Entregas CyC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 200, 220, 255),
                    ),
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
                          color: const Color(0xFFE9ECEF),
                          child: Row(
                            children: List.generate(_headers.length, (i) {
                              final isJefatura = _headers[i] == 'JEFATURA';
                              return Expanded(
                                flex: isJefatura ? 2 : 1,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: const Color(0xFFBDBDBD),
                                        width: 1,
                                      ),
                                      left: i == 0
                                          ? const BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1)
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _headers[i],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _rows.length,
                            itemBuilder: (context, rowIdx) {
                              return Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Color(0xFFBDBDBD), width: 1),
                                  ),
                                ),
                                child: Row(
                                  children:
                                      List.generate(_headers.length, (colIdx) {
                                    final isJefatura =
                                        _headers[colIdx] == 'JEFATURA';
                                    final isSeccion =
                                        _headers[colIdx] == 'SECCION';
                                    return Expanded(
                                      flex: isJefatura ? 2 : 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: const Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            left: colIdx == 0
                                                ? const BorderSide(
                                                    color: Color(0xFFBDBDBD),
                                                    width: 1)
                                                : BorderSide.none,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6, horizontal: 2),
                                          child: isJefatura
                                              ? Center(
                                                  child: Text(
                                                    _rows[rowIdx][colIdx].text,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                )
                                              : isSeccion
                                                  ? TextField(
                                                      controller: _rows[rowIdx]
                                                          [colIdx],
                                                      textAlign:
                                                          TextAlign.center,
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        4),
                                                      ),
                                                      style: const TextStyle(
                                                          fontSize: 14),
                                                      onChanged: (value) {
                                                        _rows[rowIdx][_headers
                                                                .indexOf(
                                                                    'JEFATURA')]
                                                            .text = '';
                                                        _buscarJefaturaFirestore(
                                                                value.trim())
                                                            .then((jefatura) {
                                                          setState(() {
                                                            _rows[rowIdx][_headers
                                                                    .indexOf(
                                                                        'JEFATURA')]
                                                                .text = jefatura;
                                                          });
                                                        });
                                                      },
                                                    )
                                                  : TextField(
                                                      controller: _rows[rowIdx]
                                                          [colIdx],
                                                      textAlign:
                                                          TextAlign.center,
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        4),
                                                      ),
                                                      style: const TextStyle(
                                                          fontSize: 14),
                                                    ),
                                        ),
                                      ),
                                    );
                                  }),
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
            ],
          ],
        ),
      ),
    );
  }
}
