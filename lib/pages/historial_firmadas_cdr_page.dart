import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';

class HistorialFirmadasCdrPage extends StatefulWidget {
  const HistorialFirmadasCdrPage({Key? key}) : super(key: key);

  @override
  State<HistorialFirmadasCdrPage> createState() =>
      _HistorialFirmadasCdrPageState();
}

class _HistorialFirmadasCdrPageState extends State<HistorialFirmadasCdrPage> {
  List<Map<String, dynamic>> _firmadas = [];
  bool _cargando = true;
  String _filtro = '';
  late TextEditingController _busquedaController;

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarFirmadas();
  }

  Future<void> _cargarFirmadas() async {
    setState(() => _cargando = true);
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore
        .collection('historial_entregas')
        .doc('cdr_firmadas')
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
    setState(() {
      _firmadas = nuevos;
      _cargando = false;
    });
  }

  void _filtrar(String value) {
    setState(() {
      _filtro = value.toLowerCase();
    });
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _filtro.isEmpty
        ? _firmadas
        : _firmadas
            .where((e) => e.entries.any((entry) {
                  final v = entry.value;
                  if (v == null) return false;
                  return v.toString().toLowerCase().contains(_filtro);
                }))
            .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: const Text('HISTORIAL DE ENTREGAS CDR',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargarFirmadas,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                    child: resultados.isEmpty
                        ? const Center(child: Text('No hay entregas firmadas.'))
                        : ListView.separated(
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemCount: resultados.length,
                            itemBuilder: (context, index) {
                              final entrega = resultados[index];
                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 7, horizontal: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFF2D6A4F),
                                    width: 1.2,
                                  ),
                                ),
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _infoChip('LP', entrega['LP']),
                                          _infoChip('SKU', entrega['SKU']),
                                          _infoChip(
                                              'CANT', entrega['CANTIDAD']),
                                          _infoChip('SECC', entrega['SECCION']),
                                          _infoChip('JEF', entrega['JEFATURA']),
                                        ],
                                      ),
                                      if (entrega['firma'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('Firma:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              SizedBox(
                                                height: 80,
                                                child: entrega['firma']
                                                        is String
                                                    ? Image.memory(
                                                        base64Decode(
                                                            entrega['firma']),
                                                        fit: BoxFit.contain,
                                                      )
                                                    : const Text(
                                                        'Firma no disponible'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (entrega['nombreRecibe'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                              'Recibió: ${entrega['nombreRecibe']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      if (entrega['fechaFirma'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2.0),
                                          child: Text(
                                              'Fecha: ${entrega['fechaFirma']}'),
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

  Widget _infoChip(String label, dynamic value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D6A4F)),
      ),
      child: Text('$label: ${value ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
