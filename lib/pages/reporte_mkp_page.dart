import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'dart:html' as html;

class ReporteMkpPage extends StatefulWidget {
  const ReporteMkpPage({Key? key}) : super(key: key);

  @override
  State<ReporteMkpPage> createState() => _ReporteMkpPageState();
}

class _ReporteMkpPageState extends State<ReporteMkpPage> {
  // Set de pares (REmision, ARTICULO) que están entregados
  Set<String> _entregados = {};

  // Normaliza valores quitando ceros a la izquierda y espacios
  String _normalizeKey(String value) {
    return value.trim().replaceFirst(RegExp(r'^0+'), '');
  }

  // Cargar entregas MKP para validación
  Future<void> _cargarEntregasMKP() async {
    final doc = await FirebaseFirestore.instance
        .collection('entregas')
        .doc('mkp')
        .get();
    final items = (doc.data()?['items'] ?? []) as List;
    final entregados = <String>{};
    for (final item in items) {
      final dev = _normalizeKey((item['devolucion_mkp'] ?? '').toString());
      final skus = (item['skus'] ?? []) as List?;
      if (skus != null) {
        for (final sku in skus) {
          final normSku = _normalizeKey(sku.toString());
          entregados.add('$dev|$normSku');
        }
      }
    }
    setState(() {
      _entregados = entregados;
    });
  }

  // Mapa SECCION -> NOMBRE (JEFATURA) desde Plantilla Ejecutiva
  Map<String, String> _seccionToJefatura = {};
  String _normalizeSeccion(String s) => s.trim().toUpperCase();
  bool _jefaturasCargadas = false;

  @override
  void initState() {
    super.initState();
    _cargarJefaturas();
    _cargarEntregasMKP();
  }

  Future<void> _cargarJefaturas() async {
    // Leer correctamente la colección y documento reales
    final doc = await FirebaseFirestore.instance
        .collection('plantilla_ejecutiva')
        .doc('datos')
        .get();
    final map = <String, String>{};
    final items = (doc.data()?['items'] ?? []) as List?;
    if (items != null) {
      for (final item in items) {
        final seccion = item['SECCION']?.toString() ?? '';
        final nombre = item['NOMBRE']?.toString() ?? '';
        if (seccion.isNotEmpty) {
          map[_normalizeSeccion(seccion)] = nombre;
        }
      }
    }
    setState(() {
      _seccionToJefatura = map;
      _jefaturasCargadas = true;
    });
  }

  // Encabezados ejecutivos
  final List<String> _headers = [
    'NOMBRE CENTRO',
    'REmision',
    'ARTICULO',
    'NUMERO VENDEDOR',
    'NOMBRE DEL VENDEDOR',
    'ESTATUS ACTUAL',
    'FECHA',
    'SECCION',
    'JEFATURA',
  ];

  // Controladores para edición
  final List<List<TextEditingController>> _controllers = [];

  // Importar desde Excel
  Future<void> _importarExcel() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(files[0]);
        reader.onLoadEnd.listen((event) async {
          final bytes = reader.result as Uint8List;
          final excelFile = excel.Excel.decodeBytes(bytes);
          final sheet = excelFile.tables.values.first;
          final rows = sheet.rows;
          if (rows.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El archivo está vacío.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          setState(() {
            _controllers.clear();
            for (int i = 1; i < rows.length; i++) {
              final row = rows[i];
              final ctrls = List.generate(_headers.length, (colIdx) {
                String val = colIdx < row.length && row[colIdx] != null
                    ? row[colIdx]!.value.toString()
                    : '';
                return TextEditingController(text: val);
              });
              _controllers.add(ctrls);
            }
            // Forzar actualización de JEFATURA después de importar (normalizando SECCION)
            for (final ctrls in _controllers) {
              final seccionIdx = _headers.indexOf('SECCION');
              final jefaturaIdx = _headers.indexOf('JEFATURA');
              if (seccionIdx != -1 && jefaturaIdx != -1) {
                final seccion = ctrls[seccionIdx].text;
                final nuevaJefatura =
                    _seccionToJefatura[_normalizeSeccion(seccion)] ?? '';
                ctrls[jefaturaIdx].text = nuevaJefatura;
              }
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Importación exitosa: ${rows.length - 1} filas.'),
              backgroundColor: Colors.green,
            ),
          );
        });
      }
    });
  }

  void _agregarFila() {
    setState(() {
      final ctrls =
          List.generate(_headers.length, (i) => TextEditingController());
      _controllers.add(ctrls);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.assignment, color: Color(0xFF2D6A4F), size: 30),
            SizedBox(width: 10),
            Text('Reporte MKP', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar Excel'),
                  onPressed: _importarExcel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar fila'),
                  onPressed: _agregarFila,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Table(
                      border: TableBorder(
                        horizontalInside:
                            BorderSide(color: Colors.grey.shade300, width: 1),
                        verticalInside:
                            BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                      columnWidths: {
                        for (int i = 0; i < _headers.length; i++)
                          i: const FlexColumnWidth(),
                      },
                      children: [
                        TableRow(
                          decoration:
                              const BoxDecoration(color: Color(0xFF2D6A4F)),
                          children: _headers
                              .map((col) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 4),
                                    child: Text(col,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                  ))
                              .toList(),
                        ),
                        ...List.generate(
                          _controllers.isEmpty ? 1 : _controllers.length,
                          (rowIdx) {
                            final rowCtrls = _controllers.isEmpty
                                ? List.generate(_headers.length,
                                    (i) => TextEditingController())
                                : _controllers[rowIdx];
                            return TableRow(
                              decoration: BoxDecoration(
                                color: rowIdx % 2 == 0
                                    ? Colors.white
                                    : Colors.grey.shade50,
                              ),
                              children:
                                  List.generate(_headers.length, (colIdx) {
                                final isEditable = colIdx < _headers.length - 1;
                                // Si es SECCION, actualizar JEFATURA al editar (siempre)
                                if (_headers[colIdx] == 'SECCION') {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 2),
                                    child: TextField(
                                      controller: rowCtrls[colIdx],
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 4),
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (value) {
                                        final jefaturaIdx =
                                            _headers.indexOf('JEFATURA');
                                        final nuevaJefatura =
                                            _seccionToJefatura[
                                                    _normalizeSeccion(value)] ??
                                                '';
                                        rowCtrls[jefaturaIdx].text =
                                            nuevaJefatura;
                                        setState(() {});
                                      },
                                    ),
                                  );
                                }
                                // Si es JEFATURA, mostrar siempre el valor actualizado y no editable
                                if (_headers[colIdx] == 'JEFATURA') {
                                  final seccionIdx =
                                      _headers.indexOf('SECCION');
                                  final seccion = rowCtrls[seccionIdx].text;
                                  final jefatura = _seccionToJefatura[
                                          _normalizeSeccion(seccion)] ??
                                      '';
                                  if (rowCtrls[colIdx].text != jefatura) {
                                    rowCtrls[colIdx].text = jefatura;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 2),
                                    child: Text(
                                      jefatura,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                }
                                // Si es REmision o ARTICULO, actualizar ESTATUS ACTUAL al editar (normalizando)
                                if (_headers[colIdx] == 'REmision' ||
                                    _headers[colIdx] == 'ARTICULO') {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 2),
                                    child: TextField(
                                      controller: rowCtrls[colIdx],
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 4),
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (_) {
                                        final remisionIdx =
                                            _headers.indexOf('REmision');
                                        final articuloIdx =
                                            _headers.indexOf('ARTICULO');
                                        final estatusIdx =
                                            _headers.indexOf('ESTATUS ACTUAL');
                                        final remision =
                                            rowCtrls[remisionIdx].text;
                                        final articulo =
                                            rowCtrls[articuloIdx].text;
                                        final key =
                                            '${_normalizeKey(remision)}|${_normalizeKey(articulo)}';
                                        setState(() {
                                          if (_entregados.contains(key)) {
                                            rowCtrls[estatusIdx].text =
                                                'ENTREGADO';
                                          } else if (rowCtrls[estatusIdx]
                                                  .text ==
                                              'ENTREGADO') {
                                            rowCtrls[estatusIdx].text = '';
                                          }
                                        });
                                      },
                                    ),
                                  );
                                }
                                // Si es ESTATUS ACTUAL y es ENTREGADO, pintar verde
                                if (_headers[colIdx] == 'ESTATUS ACTUAL' &&
                                    rowCtrls[colIdx].text == 'ENTREGADO') {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 2),
                                    child: Container(
                                      color: Colors.green.shade200,
                                      alignment: Alignment.center,
                                      child: Text(
                                        rowCtrls[colIdx].text,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2, horizontal: 2),
                                  child: isEditable
                                      ? TextField(
                                          controller: rowCtrls[colIdx],
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    vertical: 8, horizontal: 4),
                                          ),
                                          style: const TextStyle(fontSize: 13),
                                        )
                                      : Text(rowCtrls[colIdx].text,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                );
                              }),
                            );
                          },
                        ),
                      ],
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
