import 'package:flutter/material.dart';

class HistorialCartaPortePageMobile extends StatelessWidget {
  final List<dynamic> historial;
  const HistorialCartaPortePageMobile({Key? key, required this.historial})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return Center(child: Text('No hay historial disponible.'));
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
