import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistorialEntregasXdPage extends StatefulWidget {
  final List<Map<String, dynamic>> historial;
  final String tipoUsuarioActual;
  const HistorialEntregasXdPage({
    Key? key,
    required this.historial,
    required this.tipoUsuarioActual,
  }) : super(key: key);

  @override
  State<HistorialEntregasXdPage> createState() =>
      _HistorialEntregasXdPageState();
}

class _HistorialEntregasXdPageState extends State<HistorialEntregasXdPage> {
  late List<Map<String, dynamic>> _resultados;
  List<Map<String, dynamic>> _datosOriginales = [];

  @override
  void initState() {
    super.initState();
    _recargarFirestore();
  }

  Future<void> _recargarFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore
        .collection('historial_entregas')
        .doc('dev_xd_firmadas')
        .get();
    final data = doc.exists ? doc.data() : null;
    List<Map<String, dynamic>> nuevos = [];
    if (data != null && data['items'] is List) {
      for (var e in (data['items'] as List)) {
        if (e is Map) {
          nuevos.add(Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }
    _datosOriginales = List<Map<String, dynamic>>.from(nuevos);
    setState(() {
      _resultados = List<Map<String, dynamic>>.from(_datosOriginales);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Entregas XD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recargarFirestore,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _resultados.isEmpty
          ? const Center(child: Text('No hay entregas XD firmadas.'))
          : ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final item = _resultados[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('XD: ${item['XD'] ?? ''}'),
                    subtitle: Text(
                        'SKU: ${item['SKU'] ?? ''}\nDescripción: ${item['DESCRIPCION'] ?? ''}\nCantidad: ${item['CANTIDAD'] ?? ''}\nSección: ${item['SECCION'] ?? ''}\nJefatura: ${item['JEFATURA'] ?? ''}'),
                  ),
                );
              },
            ),
    );
  }
}
