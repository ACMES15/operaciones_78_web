import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'dart:html' as html;

class ReporteMkpPage extends StatefulWidget {
  const ReporteMkpPage({Key? key}) : super(key: key);

  @override
  State<ReporteMkpPage> createState() => _ReporteMkpPageState();
}

class _ReporteMkpPageState extends State<ReporteMkpPage> {
  // Mapa de SECCION -> JEFATURA (NOMBRE)
  Map<String, String> _seccionToJefatura = {};

  @override
  void initState() {
    super.initState();
    _cargarJefaturas();
  }

  Future<void> _cargarJefaturas() async {
    final doc = await FirebaseFirestore.instance
        .collection('plantilla_ejecutiva')
        .doc('datos')
        .get();
    if (doc.exists && doc.data() != null && doc.data()!['datos'] != null) {
      final raw = doc.data()!['datos'] as List;
      for (final fila in raw) {
        if (fila is Map && fila['SECCION'] != null && fila['NOMBRE'] != null) {
          _seccionToJefatura[fila['SECCION'].toString().trim()] =
              fila['NOMBRE'].toString().trim();
        }
      }
    }
  }

  void _actualizarJefatura(int rowIdx) {
    final seccionIdx = _headers.indexOf('SECCION');
    final jefaturaIdx = _headers.indexOf('JEFATURA');
    if (seccionIdx == -1 || jefaturaIdx == -1) return;
    final seccion = _controllers[rowIdx][seccionIdx].text.trim();
    final jefatura = _seccionToJefatura[seccion] ?? '';
    setState(() {
      _controllers[rowIdx][jefaturaIdx].text = jefatura;
    });
  }

  // Columnas de la tabla
  static const List<String> columnas = [
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

  // Datos de la tabla
  List<List<String>> filas = [];
  // Controladores para edición
  final List<List<TextEditingController>> _controllers = [];

  // Encabezados esperados
  List<String> get _headers => columnas;

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
          final headers = rows.first
              .map((e) => (e?.value ?? '').toString().trim())
              .toList();
          // Mapear encabezados a índice
          final headerMap = <String, int>{};
          for (int i = 0; i < headers.length; i++) {
            headerMap[headers[i]] = i;
          }
          // Solo requerimos encabezados hasta SECCION
          final idxSeccion = _headers.indexOf('SECCION');
          final requiredHeaders = _headers.sublist(0, idxSeccion + 1);
          if (!requiredHeaders.every((h) => headerMap.containsKey(h))) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'El archivo debe tener los encabezados hasta SECCION.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          final newFilas = <List<String>>[];
          for (var i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.every((c) => (c?.value ?? '').toString().trim().isEmpty))
              continue;
            // Construir la fila solo hasta SECCION
            final fila = <String>[];
            for (int j = 0; j <= idxSeccion; j++) {
              final idx = headerMap[_headers[j]]!;
              fila.add(
                  idx < row.length ? (row[idx]?.value ?? '').toString() : '');
            }
            // Calcular JEFATURA
            final seccion = fila[idxSeccion].trim();
            fila.add(_seccionToJefatura[seccion] ?? '');
            // Rellenar el resto de columnas si hay más después de JEFATURA
            while (fila.length < _headers.length) {
              fila.add('');
            }
            newFilas.add(fila);
          }
          setState(() {
            // Limpiar controladores previos
            for (final row in _controllers) {
              for (final ctrl in row) {
                ctrl.dispose();
              }
            }
            _controllers.clear();
            filas = newFilas;
            for (final fila in filas) {
              _controllers.add(List.generate(_headers.length,
                  (i) => TextEditingController(text: fila[i])));
            }
          });
          if (newFilas.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se encontraron filas válidas en el archivo.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Importación exitosa: ${newFilas.length} filas.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    });
  }

  void _agregarFila() {
    setState(() {
      final nueva = List<String>.filled(_headers.length, '');
      filas.add(nueva);
      _controllers
          .add(List.generate(_headers.length, (i) => TextEditingController()));
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
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
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
                            children: List.generate(_headers.length, (colIdx) {
                              final isEditable = colIdx <
                                  _headers.length - 1; // JEFATURA no editable
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2, horizontal: 2),
                                child: isEditable
                                    ? TextField(
                                        controller: rowCtrls[colIdx],
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 4),
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                        onChanged: (_) {
                                          if (_headers[colIdx] == 'SECCION') {
                                            _actualizarJefatura(rowIdx);
                                          }
                                        },
                                      )
                                    : Text(rowCtrls[colIdx].text,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                              );
                            }),
                          );
                        }),
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
