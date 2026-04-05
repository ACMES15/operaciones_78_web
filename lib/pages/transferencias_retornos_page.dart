import 'package:flutter/material.dart';
import 'entregas_transferencias_retornos_page.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';

class TransferenciasRetornosPage extends StatefulWidget {
  final String usuario;
  const TransferenciasRetornosPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<TransferenciasRetornosPage> createState() =>
      _TransferenciasRetornosPageState();
}

class _TransferenciasRetornosPageState
    extends State<TransferenciasRetornosPage> {
  final List<String> _headers = [
    'TF O DEV ',
    'ORIGEN',
    'DESTINO',
    'SECCION',
    'JEFATURA',
    'RETORNO',
  ];
  final List<List<TextEditingController>> _rows = [];

  void _addRow() {
    setState(() {
      final ctrls = List.generate(_headers.length, (i) {
        if (_headers[i] == 'RETORNO') {
          return TextEditingController(text: 'false');
        }
        return TextEditingController();
      });
      _rows.add(ctrls);
    });
  }

  @override
  void dispose() {
    for (var row in _rows) {
      for (var ctrl in row) {
        ctrl.dispose();
      }
    }
    super.dispose();
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
        final transferencia = row.length > 0 && row[0] != null
            ? row[0]?.value?.toString() ?? ''
            : '';
        final origen = row.length > 1 && row[1] != null
            ? row[1]?.value?.toString() ?? ''
            : '';
        final destino = row.length > 2 && row[2] != null
            ? row[2]?.value?.toString() ?? ''
            : '';
        final seccion = row.length > 3 && row[3] != null
            ? row[3]?.value?.toString() ?? ''
            : '';
        fila.add(transferencia);
        fila.add(origen);
        fila.add(destino);
        fila.add(seccion);
        fila.add(''); // JEFATURA vacío
        fila.add('false'); // RETORNO por default
        datos.add(fila);
      }
      break;
    }
    // Obtener datos de plantilla_ejecutiva una sola vez
    Map<String, String> seccionToJefatura = {};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();
      if (doc.exists && doc.data() != null) {
        final datosPlantilla = doc.data()!['datos'] as List<dynamic>?;
        if (datosPlantilla != null) {
          for (final fila in datosPlantilla) {
            if (fila is Map<String, dynamic> &&
                fila['SECCION'] != null &&
                fila['NOMBRE'] != null) {
              seccionToJefatura[fila['SECCION']
                  .toString()
                  .trim()
                  .toUpperCase()] = fila['NOMBRE'].toString();
            }
          }
        }
      }
    } catch (_) {}

    List<List<TextEditingController>> nuevasFilas = [];
    for (final fila in datos) {
      final List<TextEditingController> ctrls =
          List.generate(_headers.length, (i) {
        if (_headers[i] == 'RETORNO') {
          return TextEditingController(
              text: i < fila.length ? fila[i] : 'false');
        }
        if (_headers[i] == 'JEFATURA') {
          // Buscar jefatura por SECCION
          final seccionIdx = _headers.indexOf('SECCION');
          String seccion = seccionIdx != -1 && seccionIdx < fila.length
              ? fila[seccionIdx].trim().toUpperCase()
              : '';
          String jefatura = seccionToJefatura[seccion] ?? '';
          return TextEditingController(text: jefatura);
        }
        final ctrl = TextEditingController();
        ctrl.text = i < fila.length ? fila[i] : '';
        return ctrl;
      });
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
            Text('Filas importadas: \\${_rows.length}'),
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

  Future<void> _guardarTransferencias() async {
    // Validar que haya datos
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para guardar.')),
      );
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      Map<String, dynamic> map = {};
      for (int j = 0; j < _headers.length; j++) {
        map[_headers[j]] = row[j].text;
      }
      map['id'] = DateTime.now().millisecondsSinceEpoch.toString() + '_$i';
      map['usuarioValido'] = widget.usuario;
      map['FECHA'] = DateTime.now().toIso8601String();
      items.add(map);
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('entregas')
          .doc('transferencias_retornos')
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
        'transferencias_retornos',
        {'items': nuevosItems},
      );
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Información guardada en Transferencias y Retornos.')),
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

  void _verEntregasTransferenciasRetornos() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntregasTransferenciasRetornosPage(),
        settings: RouteSettings(arguments: widget.usuario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileSmall = MediaQuery.of(context).size.shortestSide <= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.swap_horiz, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text(
              'Transferencias y Retornos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: isMobileSmall
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label:
                          const Text('Ver Entregas Transferencias y Retornos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: _verEntregasTransferenciasRetornos,
                    ),
                  ],
                ),
              ],
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
                        onPressed: _guardarTransferencias,
                        child: const Text('Guardar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addRow,
                        child: const Text('Agregar fila'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _verEntregasTransferenciasRetornos,
                        child: const Text(
                            'Ver Entregas Transferencias y Retornos'),
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
                                  final isRetorno = _headers[i] == 'RETORNO';
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
                                        child: isRetorno
                                            ? Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.assignment_return,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  SizedBox(width: 4),
                                                  Text('RETORNO',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16)),
                                                ],
                                              )
                                            : Text(
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
                                      children: List.generate(_headers.length,
                                          (colIdx) {
                                        final isJefatura =
                                            _headers[colIdx] == 'JEFATURA';
                                        final isRetorno =
                                            _headers[colIdx] == 'RETORNO';
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
                                              child: isRetorno
                                                  ? Center(
                                                      child: Checkbox(
                                                        value: _rows[rowIdx]
                                                                    [colIdx]
                                                                .text ==
                                                            'true',
                                                        onChanged: (val) {
                                                          setState(() {
                                                            _rows[rowIdx]
                                                                        [colIdx]
                                                                    .text =
                                                                val == true
                                                                    ? 'true'
                                                                    : 'false';
                                                          });
                                                        },
                                                      ),
                                                    )
                                                  : isJefatura
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
                                                      : (_headers[colIdx] ==
                                                              'SECCION'
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
                                                                final seccion =
                                                                    value
                                                                        .trim();
                                                                if (seccion
                                                                    .isNotEmpty) {
                                                                  final doc = await FirebaseFirestore
                                                                      .instance
                                                                      .collection(
                                                                          'plantilla_ejecutiva')
                                                                      .doc(
                                                                          'datos')
                                                                      .get();
                                                                  if (doc.exists &&
                                                                      doc.data() !=
                                                                          null) {
                                                                    final datos = doc
                                                                            .data()!['datos']
                                                                        as List<
                                                                            dynamic>?;
                                                                    if (datos !=
                                                                        null) {
                                                                      for (final fila
                                                                          in datos) {
                                                                        if (fila is Map<String,
                                                                                dynamic> &&
                                                                            fila['SECCION'].toString().trim().toUpperCase() ==
                                                                                seccion.toUpperCase()) {
                                                                          final jefaturaIdx =
                                                                              _headers.indexOf('JEFATURA');
                                                                          if (jefaturaIdx !=
                                                                              -1) {
                                                                            setState(() {
                                                                              _rows[rowIdx][jefaturaIdx].text = fila['NOMBRE']?.toString() ?? '';
                                                                            });
                                                                          }
                                                                          break;
                                                                        }
                                                                      }
                                                                    }
                                                                  }
                                                                }
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
                                                            )),
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
