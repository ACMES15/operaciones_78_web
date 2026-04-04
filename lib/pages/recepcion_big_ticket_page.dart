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
    'CONCATENATE',
    'ESCANEO',
    'VALIDACION',
    'DIFERENCIA MANIFIESTO',
  ];
  final List<List<String>> _rows = [];

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
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
              dataTextStyle:
                  const TextStyle(fontSize: 16, color: Colors.black87),
              columns: _headers
                  .map((h) => DataColumn(label: Center(child: Text(h))))
                  .toList(),
              rows: _rows.isEmpty
                  ? [
                      DataRow(
                          cells: List.generate(
                              _headers.length, (i) => const DataCell(Text(''))))
                    ]
                  : _rows.map((fila) {
                      return DataRow(
                        cells: List.generate(_headers.length,
                            (i) => DataCell(Center(child: Text(fila[i])))),
                      );
                    }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
