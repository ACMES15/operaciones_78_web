import 'package:flutter/material.dart';
import 'entregas_xd_page.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firebase_cache_utils.dart';

// Clon de DevMbodasPage adaptado para XD
class DevXdPage extends StatefulWidget {
  final String usuario;
  const DevXdPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<DevXdPage> createState() => _DevXdPageState();
}

class _DevXdPageState extends State<DevXdPage> {
  // --- Lógica y UI clonada de DevMbodasPage, adaptada para XD ---
  // Variables eliminadas por no usarse
  final List<String> _headers = [
    'XD',
    'SKU',
    'DESCRIPCION',
    'CANTIDAD',
    'SECCION',
    'JEFATURA',
  ];
  final List<List<TextEditingController>> _rows = [];

  void _addRow() {
    setState(() {
      final ctrls =
          List.generate(_headers.length, (_) => TextEditingController());
      _rows.add(ctrls);
    });
  }

  void _verEntregasXD() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntregasXdPage(usuario: widget.usuario),
      ),
    );
  }

  Future<void> _buscarJefaturaFirestore(
      String seccion, Function(String) onResult) async {
    // Puedes adaptar la colección si es diferente para XD
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

  Future<void> _importFromExcel() async {
    if (!kIsWeb) return;
    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) async {
        await _procesarExcel(reader.result);
      });
    });
  }

  Future<void> _procesarExcel(Object? result) async {
    final Uint8List bytes =
        result is ByteBuffer ? result.asUint8List() : (result as Uint8List);
    final excel = ex.Excel.decodeBytes(bytes);
    final List<List<String>> datos = [];
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        final fila = <String>[];
        final xd = row.length > 0 && row[0] != null
            ? row[0]?.value?.toString() ?? ''
            : '';
        final sku = row.length > 1 && row[1] != null
            ? row[1]?.value?.toString() ?? ''
            : '';
        final descripcion = row.length > 2 && row[2] != null
            ? row[2]?.value?.toString() ?? ''
            : '';
        final cantidad = row.length > 3 && row[3] != null
            ? row[3]?.value?.toString() ?? ''
            : '';
        final seccion = row.length > 4 && row[4] != null
            ? row[4]?.value?.toString() ?? ''
            : '';
        fila.add(xd); // XD como texto plano
        fila.add(sku);
        fila.add(descripcion);
        fila.add(cantidad);
        fila.add(seccion);
        fila.add(''); // JEFATURA vacío, se llenará luego
        datos.add(fila);
      }
      break;
    }
    List<List<TextEditingController>> nuevasFilas = [];
    for (final fila in datos) {
      final List<TextEditingController> ctrls =
          List.generate(_headers.length, (i) {
        final ctrl = TextEditingController();
        ctrl.text = i < fila.length ? fila[i] : '';
        return ctrl;
      });
      final idxXd = _headers.indexOf('XD');
      final idxSku = _headers.indexOf('SKU');
      if (idxXd != -1 &&
          idxSku != -1 &&
          ctrls[idxXd].text.isEmpty &&
          ctrls[idxSku].text.trim().isNotEmpty) {
        ctrls[idxXd].text = 'Fisico';
      }
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
      nuevasFilas.add(ctrls);
    }
    if (nuevasFilas.isEmpty) {
      nuevasFilas
          .add(List.generate(_headers.length, (_) => TextEditingController()));
    }
    setState(() {
      for (var row in _rows) {
        for (var ctrl in row) {
          ctrl.dispose();
        }
      }
      _rows.clear();
      _rows.addAll(nuevasFilas);
    });
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
  }

  Future<void> _guardarXdYNotificar() async {
    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      Map<String, dynamic> map = {};
      for (int j = 0; j < _headers.length; j++) {
        map[_headers[j]] = row[j].text;
      }
      map['usuarioValido'] = widget.usuario;
      map['id'] = DateTime.now().millisecondsSinceEpoch.toString() + '_$i';
      items.add(map);
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('entregas')
          .doc('xd')
          .get();
      List<dynamic> existentes = [];
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!.containsKey('items')) {
        final data = doc.data()!['items'];
        if (data is List) {
          existentes = List.from(data);
        }
      }
      final nuevosItems = [...existentes, ...items];
      await guardarDatosFirestoreYCache(
        'entregas',
        'xd',
        {'items': nuevosItems},
      );
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información guardada en XD.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error guardando en Firestore: $e'),
            backgroundColor: Colors.red),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileSmall = MediaQuery.of(context).size.shortestSide <= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.extension, color: Color(0xFF2D6A4F), size: 28),
            SizedBox(width: 10),
            Text(
              'Dev XD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: Color(0xFF2D6A4F),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFE9ECEF),
        elevation: 0,
      ),
      body: isMobileSmall
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Ver Entregas XD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18),
                    ),
                    onPressed: _verEntregasXD,
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _importFromExcel,
                        child: const Text('Importar Excel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _guardarXdYNotificar,
                        child: const Text('Guardar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addRow,
                        child: const Text('Agregar fila'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _verEntregasXD,
                        child: const Text('Ver entregas XD'),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
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
                                    decoration: BoxDecoration(
                                      border: const Border(
                                        bottom: BorderSide(
                                            color: Color(0xFFBDBDBD), width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      children: List.generate(_headers.length,
                                          (colIdx) {
                                        final isJefatura =
                                            _headers[colIdx] == 'JEFATURA';
                                        final isSeccion =
                                            _headers[colIdx] == 'SECCION';
                                        final isXd = _headers[colIdx] == 'XD';
                                        return Expanded(
                                          flex: isJefatura ? 2 : 1,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: BorderSide(
                                                  color:
                                                      const Color(0xFFBDBDBD),
                                                  width: 1,
                                                ),
                                                left: colIdx == 0
                                                    ? const BorderSide(
                                                        color:
                                                            Color(0xFFBDBDBD),
                                                        width: 1)
                                                    : BorderSide.none,
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 2),
                                              child: isJefatura
                                                  ? Center(
                                                      child: Text(
                                                        _rows[rowIdx][colIdx]
                                                            .text,
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF2D6A4F)),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    )
                                                  : isXd
                                                      ? TextField(
                                                          controller:
                                                              _rows[rowIdx]
                                                                  [colIdx],
                                                          textAlign:
                                                              TextAlign.center,
                                                          decoration:
                                                              const InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            isDense: true,
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        vertical:
                                                                            8,
                                                                        horizontal:
                                                                            4),
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 14),
                                                        )
                                                      : isSeccion
                                                          ? TextField(
                                                              controller:
                                                                  _rows[rowIdx]
                                                                      [colIdx],
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              decoration:
                                                                  const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                        vertical:
                                                                            8,
                                                                        horizontal:
                                                                            4),
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                              onChanged:
                                                                  (value) async {
                                                                await _buscarJefaturaFirestore(
                                                                    value
                                                                        .trim(),
                                                                    (jefatura) {
                                                                  setState(() {
                                                                    _rows[rowIdx][_headers.indexOf('JEFATURA')]
                                                                            .text =
                                                                        jefatura;
                                                                  });
                                                                });
                                                              },
                                                            )
                                                          : TextField(
                                                              controller:
                                                                  _rows[rowIdx]
                                                                      [colIdx],
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              decoration:
                                                                  const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                        vertical:
                                                                            8,
                                                                        horizontal:
                                                                            4),
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
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
              ),
            ),
    );
  }
}
