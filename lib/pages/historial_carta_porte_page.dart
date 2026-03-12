import 'package:flutter/material.dart';
import '../utils/exportar_excel.dart';

class HistorialCartaPortePage extends StatelessWidget {
  // Simulación de datos para la estructura visual
  final List<Map<String, dynamic>> cartasDemo = const [
    {
      'MANIFIESTO': '969696',
      'DESTINO': '168',
      'FECHA': '2026-03-11',
      'NOMBRE': 'acmes15',
      'USUARIO': 'acmes15',
    },
    {
      'MANIFIESTO': '123456',
      'DESTINO': '200',
      'FECHA': '2026-03-10',
      'NOMBRE': 'usuario2',
      'USUARIO': 'usuario2',
    },
  ];

  HistorialCartaPortePage({Key? key}) : super(key: key);

  final TextEditingController _busquedaController = TextEditingController();

  Future<void> exportarAExcel(
      List<Map<String, dynamic>> merged, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportación no implementada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Carta Porte'),
        backgroundColor: const Color(0xFF2D6A4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar a Excel',
            onPressed: () async {
              // Aquí se llamaría a exportarAExcel con los datos reales
              await exportarAExcel([], context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _busquedaController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                // No hace nada aún, solo estructura visual
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: cartasDemo.length,
                itemBuilder: (context, idx) {
                  final carta = cartasDemo[idx];
                  return Card(
                    color: const Color(0xFFF5F6FA),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text('Manifiesto: ${carta['MANIFIESTO']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Destino: ${carta['DESTINO']}'),
                          Text('Fecha: ${carta['FECHA']}'),
                          Text('Nombre: ${carta['NOMBRE']}'),
                          Text('Usuario: ${carta['USUARIO']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
