import 'package:flutter/material.dart';

class HojaDeRutaTablaPage extends StatelessWidget {
  const HojaDeRutaTablaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = const [
      'Centro',
      'Documento',
      'Pedido',
      'Destino',
      'Tipo',
      'Sellos',
      'Contenedor',
      'Proveedor',
    ];
    final rows =
        List.generate(5, (i) => List.generate(columns.length, (j) => ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoja de Ruta (Tabla Simple)'),
        backgroundColor: const Color.fromARGB(184, 69, 70, 69),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: columns
                .map((col) => DataColumn(
                      label: Text(col,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ))
                .toList(),
            rows: rows
                .map((row) => DataRow(
                      cells:
                          row.map((cell) => const DataCell(Text(''))).toList(),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
