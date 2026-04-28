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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cargarHistorialCompleto(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final historial = snapshot.data ?? [];
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
      },
    );
  }

  Future<List<Map<String, dynamic>>> _cargarHistorialCompleto() async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore
        .collection('historial_entregas')
        .doc('recogidos_firmadas')
        .get();
    final data = doc.exists ? doc.data() : null;
    List<Map<String, dynamic>> antiguos = [];
    if (data != null && data['items'] is List) {
      for (var e in (data['items'] as List)) {
        if (e is Map) {
          antiguos.add(Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }
    // Cargar subcolección firmas
    final snap = await firestore
        .collection('historial_entregas')
        .doc('recogidos_firmadas')
        .collection('firmas')
        .get();
    final firmas = snap.docs
        .map((doc) => {
              ...doc.data(),
              'id': doc.id,
            })
        .toList();
    // Unir ambos y eliminar duplicados por id
    final Map<String, Map<String, dynamic>> unificados = {};
    for (final reg in antiguos) {
      final id = reg['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        unificados[id] = reg;
      } else {
        unificados[UniqueKey().toString()] = reg;
      }
    }
    for (final reg in firmas) {
      final id = reg['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        unificados[id] = reg;
      } else {
        unificados[UniqueKey().toString()] = reg;
      }
    }
    final todos = unificados.values.toList();
    // Ordenar descendente por fechaFirma o fecha
    todos.sort((a, b) {
      final fa = a['fechaFirma'] ?? a['fecha'] ?? '';
      final fb = b['fechaFirma'] ?? b['fecha'] ?? '';
      return fb.compareTo(fa);
    });
    return todos;
  }
}
