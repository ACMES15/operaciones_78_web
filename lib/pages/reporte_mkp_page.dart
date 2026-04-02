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
                final val = colIdx < row.length && row[colIdx] != null
                    ? row[colIdx]!.value.toString()
                    : '';
                return TextEditingController(text: val);
              });
              _controllers.add(ctrls);
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
