import 'package:flutter/material.dart';

class ReporteMkpPage extends StatefulWidget {
  const ReporteMkpPage({Key? key}) : super(key: key);

  @override
  State<ReporteMkpPage> createState() => _ReporteMkpPageState();
}

class _ReporteMkpPageState extends State<ReporteMkpPage> {
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
                  onPressed: () {}, // Implementar importación
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar fila'),
                  onPressed: () {}, // Implementar agregar fila
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: columnas
                      .map((col) => DataColumn(
                          label: Text(col,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))))
                      .toList(),
                  rows: filas.isEmpty
                      ? [
                          DataRow(
                              cells: List.generate(columnas.length,
                                  (i) => const DataCell(Text('')))),
                        ]
                      : filas
                          .map((fila) => DataRow(
                                cells: List.generate(
                                  columnas.length,
                                  (i) => DataCell(
                                      Text(fila.length > i ? fila[i] : '')),
                                ),
                              ))
                          .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
