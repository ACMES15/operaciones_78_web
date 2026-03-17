import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

class HistorialEntregasCdrPage extends StatefulWidget {
  const HistorialEntregasCdrPage({Key? key}) : super(key: key);

  @override
  State<HistorialEntregasCdrPage> createState() =>
      _HistorialEntregasCdrPageState();
}

class _HistorialEntregasCdrPageState extends State<HistorialEntregasCdrPage> {
  List<Map<String, dynamic>> _resultados = [];
  List<Map<String, dynamic>> _datosOriginales = [];
  late TextEditingController _busquedaController;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarDesdeFirestore();
  }

  Future<void> _cargarDesdeFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('entregas_cdr').get();
    final docs = snapshot.docs;
    List<Map<String, dynamic>> nuevos = [];
    for (final doc in docs) {
      nuevos.add(doc.data());
    }
    _datosOriginales = List<Map<String, dynamic>>.from(nuevos);
    _aplicarFiltro();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('historial_entregas_cdr', jsonEncode(nuevos));
  }

  void _aplicarFiltro() {
    setState(() {
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
    });
  }

  void _filtrar(String value) {
    _filtro = value.toLowerCase();
    _aplicarFiltro();
  }

  void _descargarExcel() {
    // ...igual que DevCan, pero para CDR
    // Puedes implementar si lo necesitas
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: const [
            Icon(Icons.fact_check, color: Color(0xFF2D6A4F), size: 30),
            SizedBox(width: 10),
            Text(
              'Historial Entregas CDR',
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
            onPressed: _cargarDesdeFirestore,
            tooltip: 'Actualizar desde Firestore',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF2D6A4F)),
            onPressed: _descargarExcel,
            tooltip: 'Descargar Excel',
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
                        // Aquí puedes agregar la visualización de firmas, estructura, etc.
                        return Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...entrega.entries
                                    .map((e) => Text('${e.key}: ${e.value}')),
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
