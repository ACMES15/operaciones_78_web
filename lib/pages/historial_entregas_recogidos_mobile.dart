import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialEntregasRecogidosPageMobile extends StatelessWidget {
  final List<Map<String, dynamic>> historial;
  final String tipoUsuarioActual;
  const HistorialEntregasRecogidosPageMobile(
      {Key? key, required this.historial, required this.tipoUsuarioActual})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No hay historial disponible.'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Regresar al menú'),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: historial.length,
      itemBuilder: (context, index) {
        final item = historial[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(item['titulo'] ?? 'Sin título'),
            subtitle: Text(item['detalle'] ?? ''),
            trailing: item['fecha'] != null ? Text(item['fecha']) : null,
          ),
        );
      },
    );
  }
}
