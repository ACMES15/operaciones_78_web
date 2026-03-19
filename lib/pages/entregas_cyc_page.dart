import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:signature/signature.dart';
import 'dart:convert';

class EntregasCycPage extends StatefulWidget {
  final String usuario;
  const EntregasCycPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EntregasCycPage> createState() => _EntregasCycPageState();
}

class _EntregasCycPageState extends State<EntregasCycPage> {
  List<Map<String, dynamic>> _pendientes = [];
  List<Map<String, dynamic>> _originales = [];
  bool _cargando = true;
  Set<int> _seleccionados = {};
  late TextEditingController _busquedaController;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    setState(() => _cargando = true);
    final snap =
        await FirebaseFirestore.instance.collection('entregas_cyc').get();
    final docs = snap.docs;
    final List<Map<String, dynamic>> nuevos = docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    setState(() {
      _pendientes = nuevos;
      _originales = nuevos;
      _cargando = false;
      _seleccionados.clear();
    });
  }

  void _filtrar(String value) {
    setState(() {
      _filtro = value.toLowerCase();
      _pendientes = _originales
          .where((e) => e.entries.any((entry) {
                final v = entry.value;
                if (v == null) return false;
                return v.toString().toLowerCase().contains(_filtro);
              }))
          .toList();
    });
  }

  Future<void> _firmarSeleccionados(BuildContext context) async {
    final seleccionadas =
        _seleccionados.map((idx) => _pendientes[idx]).toList();
    final nombreController = TextEditingController();
    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    final isMobile = MediaQuery.of(context).size.shortestSide <= 600;
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => isMobile
          ? Dialog(
              insetPadding: const EdgeInsets.all(0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Firmar entregas',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D6A4F),
                                  fontSize: 22)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nombreController,
                            decoration: const InputDecoration(
                                labelText: 'Nombre de quien recibe',
                                border: OutlineInputBorder()),
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (value) {
                              final upper = value.toUpperCase();
                              if (value != upper) {
                                nombreController.value =
                                    nombreController.value.copyWith(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                      offset: upper.length),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text('Firma:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D6A4F))),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFF2D6A4F)),
                            ),
                            width: double.infinity,
                            height: 180,
                            child: Signature(
                              controller: signatureController,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => signatureController.clear(),
                              icon:
                                  const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Limpiar firma'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final firmaBytes =
                                      await signatureController.toPngBytes();
                                  if (nombreController.text.trim().isEmpty ||
                                      firmaBytes == null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Nombre y firma requeridos.')));
                                    return;
                                  }
                                  Navigator.of(ctx).pop({
                                    'nombre': nombreController.text
                                        .trim()
                                        .toUpperCase(),
                                    'firma': base64Encode(firmaBytes),
                                  });
                                },
                                child: const Text('Guardar'),
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : AlertDialog(
              title: const Text('Firmar entregas',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F))),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(
                            labelText: 'Nombre de quien recibe',
                            border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (value) {
                          final upper = value.toUpperCase();
                          if (value != upper) {
                            nombreController.value =
                                nombreController.value.copyWith(
                              text: upper,
                              selection:
                                  TextSelection.collapsed(offset: upper.length),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Firma:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D6A4F))),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF2D6A4F)),
                        ),
                        width: double.infinity,
                        height: 180,
                        child: Signature(
                          controller: signatureController,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => signatureController.clear(),
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('Limpiar firma'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    final firmaBytes = await signatureController.toPngBytes();
                    if (nombreController.text.trim().isEmpty ||
                        firmaBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Nombre y firma requeridos.')));
                      return;
                    }
                    Navigator.of(context).pop({
                      'nombre': nombreController.text.trim().toUpperCase(),
                      'firma': base64Encode(firmaBytes),
                    });
                  },
                  child: const Text('Guardar'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
    );
    if (resultado == null) return;
    final nombre = resultado['nombre'] as String;
    final firma = resultado['firma'] as String;
    // Mover a historial y borrar de pendientes
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final historialRef =
        firestore.collection('historial_entregas').doc('cyc_firmadas');
    final historialDoc = await historialRef.get();
    List<dynamic> historial = [];
    if (historialDoc.exists &&
        historialDoc.data() != null &&
        historialDoc.data()!['items'] is List) {
      historial = List.from(historialDoc.data()!['items']);
    }
    final ahora = DateTime.now();
    for (final item in seleccionadas) {
      final nuevo = Map<String, dynamic>.from(item);
      nuevo['validadoPor'] = widget.usuario;
      nuevo['fechaValidacion'] = ahora.toIso8601String();
      nuevo['recibidoPor'] = nombre;
      nuevo['firma'] = firma;
      historial.add(nuevo);
      batch.delete(firestore.collection('entregas_cyc').doc(item['id']));
    }
    batch.set(historialRef, {'items': historial}, SetOptions(merge: true));
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entregas firmadas y movidas a historial.')));
    await _cargarPendientes();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.shortestSide <= 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas CyC'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busquedaController,
                          decoration: const InputDecoration(
                            labelText: 'Buscar',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: _filtrar,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _seleccionados.isEmpty
                            ? null
                            : () => _firmarSeleccionados(context),
                        icon: const Icon(Icons.edit),
                        label: const Text('Firmar seleccionados'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6A4F),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _pendientes.isEmpty
                        ? const Center(
                            child: Text('No hay entregas pendientes.'))
                        : Scrollbar(
                            child: ListView.builder(
                              itemCount: _pendientes.length,
                              itemBuilder: (context, idx) {
                                final item = _pendientes[idx];
                                final seleccionado =
                                    _seleccionados.contains(idx);
                                return Card(
                                  color: seleccionado
                                      ? const Color(0xFFD8F3DC)
                                      : null,
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: seleccionado,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _seleccionados.add(idx);
                                          } else {
                                            _seleccionados.remove(idx);
                                          }
                                        });
                                      },
                                    ),
                                    title: Text(item.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join(' | ')),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
