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
  late TextEditingController _busquedaController;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _recargarFirestore();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _filtrar(String value) {
    setState(() {
      _filtro = value.toLowerCase();
      _resultados = _datosOriginales.where((e) {
        return e.entries.any((entry) {
          final v = entry.value;
          if (v == null) return false;
          return v.toString().toLowerCase().contains(_filtro);
        });
      }).toList();
    });
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
    if (_filtro.isNotEmpty) {
      _resultados = _datosOriginales.where((e) {
        return e.entries.any((entry) {
          final v = entry.value;
          if (v == null) return false;
          return v.toString().toLowerCase().contains(_filtro);
        });
      }).toList();
    } else {
      _resultados = List<Map<String, dynamic>>.from(_datosOriginales);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.fact_check, color: Color(0xFF2D6A4F), size: 30),
            const SizedBox(width: 10),
            const Text(
              'Historial Entregas XD',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2D6A4F)),
            onPressed: _recargarFirestore,
            tooltip: 'Actualizar desde Firestore',
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
                labelText: 'Buscar por cualquier campo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filtrar,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _resultados.isEmpty
                  ? const Center(child: Text('Actualiza para ver las entregas'))
                  : ListView.separated(
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _resultados.length,
                      itemBuilder: (context, index) {
                        final entrega = _resultados[index];
                        return Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF2D6A4F),
                                      child: const Icon(Icons.fact_check,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'XD: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700]),
                                          ),
                                          Text(
                                            entrega['XD']?.toString() ?? '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Color(0xFF2D6A4F)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 6),
                                          Text(
                                            (entrega['nombreRecibe']
                                                        ?.toString() ??
                                                    '-')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('SKU: \\${entrega['SKU'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Descripción: \\${entrega['DESCRIPCION'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Cantidad: \\${entrega['CANTIDAD'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Sección: \\${entrega['SECCION'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Jefatura: \\${entrega['JEFATURA'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.verified_user,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 6),
                                          Text(
                                              'Validó: ' +
                                                  (entrega['usuarioValido']
                                                          ?.toString() ??
                                                      '-'),
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF495057))),
                                          const SizedBox(width: 16),
                                          const Icon(Icons.person_outline,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 6),
                                          Text(
                                              'Entregó: ' +
                                                  (entrega['usuarioEntrega']
                                                          ?.toString() ??
                                                      '-'),
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF495057))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
