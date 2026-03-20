import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/historial_tf_retornos.dart';

class HistorialTfRetornosPage extends StatefulWidget {
  final String usuario;
  const HistorialTfRetornosPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<HistorialTfRetornosPage> createState() =>
      _HistorialTfRetornosPageState();
}

class _HistorialTfRetornosPageState extends State<HistorialTfRetornosPage> {
  List<HistorialTfRetorno> _items = [];
  bool _cargando = true;
  String _filtro = '';
  late TextEditingController _busquedaController;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarItems();
  }

  Future<void> _cargarItems() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore
          .collection('historial_tf_retornos')
          .doc('items')
          .get();
      final data = doc.exists ? doc.data() : null;
      List<HistorialTfRetorno> nuevos = [];
      if (data != null && data['items'] is List) {
        for (var e in (data['items'] as List)) {
          if (e is Map) {
            nuevos.add(HistorialTfRetorno.fromMap(
                Map<String, dynamic>.from(
                    e.map((k, v) => MapEntry(k.toString(), v))),
                e['id']?.toString() ?? ''));
          }
        }
      }
      setState(() {
        _items = nuevos;
        _cargando = false;
        _errorCarga = null;
      });
    } catch (e) {
      setState(() {
        _items = [];
        _cargando = false;
        _errorCarga = 'Error al cargar datos: ' + e.toString();
      });
    }
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
        ? _items
        : _items
            .where((e) =>
                e.tfOdev.toLowerCase().contains(_filtro) ||
                e.origen.toLowerCase().contains(_filtro) ||
                e.valido.toLowerCase().contains(_filtro) ||
                e.entrego.toLowerCase().contains(_filtro) ||
                (e.observaciones?.toLowerCase().contains(_filtro) ?? false))
            .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF2D6A4F), size: 30),
            const SizedBox(width: 10),
            const Text(
              'Historial TF o Retornos',
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
            onPressed: _cargarItems,
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
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _errorCarga != null
                      ? Center(
                          child: Text(
                            _errorCarga!,
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        )
                      : resultados.isEmpty
                          ? const Center(child: Text('No hay registros.'))
                          : ListView.separated(
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemCount: resultados.length,
                              itemBuilder: (context, index) {
                                final item = resultados[index];
                                return Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Column(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  const Color(0xFF2D6A4F),
                                              child: const Icon(
                                                  Icons.swap_horiz,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(height: 10),
                                            if (item.retorno)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text('RETORNO',
                                                    style: TextStyle(
                                                        color: Colors.orange,
                                                        fontWeight:
                                                            FontWeight.bold)),
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
                                                  Text('TF o DEV: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .grey[700])),
                                                  Text(item.tfOdev,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                          color: Color(
                                                              0xFF2D6A4F))),
                                                  const SizedBox(width: 18),
                                                  Text('Origen: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .grey[700])),
                                                  Text(item.origen,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Color(
                                                              0xFF2D6A4F))),
                                                  const Spacer(),
                                                  if (item.fecha != null)
                                                    Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .calendar_today,
                                                            size: 18,
                                                            color: Colors
                                                                .grey[600]),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                            '${item.fecha!.toLocal().toString().substring(0, 10)}',
                                                            style: const TextStyle(
                                                                fontSize: 14,
                                                                color: Color(
                                                                    0xFF495057))),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.verified_user,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 6),
                                                  Text('Validó: ${item.valido}',
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          color: Color(
                                                              0xFF495057))),
                                                  const SizedBox(width: 16),
                                                  const Icon(
                                                      Icons.person_outline,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                      'Entregó: ${item.entrego}',
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          color: Color(
                                                              0xFF495057))),
                                                ],
                                              ),
                                              if (item.observaciones != null &&
                                                  item.observaciones!
                                                      .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8.0),
                                                  child: Text(
                                                      'Obs: ${item.observaciones}',
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey)),
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
