import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';

class EntregasMkpPage extends StatefulWidget {
  final String usuario;
  const EntregasMkpPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EntregasMkpPage> createState() => _EntregasMkpPageState();
}

class _EntregasMkpPageState extends State<EntregasMkpPage> {
  final _empleadoController = TextEditingController();
  final _devolucionController = TextEditingController();
  final List<TextEditingController> _skuControllers = [TextEditingController()];
  int _cantidad = 1;
  bool _guardando = false;
  List<Map<String, dynamic>> _registros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    setState(() => _cargando = true);
    final cache = await leerDatosConCache('entregas', 'mkp');
    List<Map<String, dynamic>> registros = [];
    if (cache != null && cache['items'] is List) {
      registros = List<Map<String, dynamic>>.from(
        (cache['items'] as List).whereType<Map<String, dynamic>>(),
      );
    }
    setState(() {
      _registros = registros;
      _cargando = false;
    });
  }

  Future<void> _guardarRegistro() async {
    if (_empleadoController.text.trim().isEmpty ||
        _devolucionController.text.trim().isEmpty ||
        _skuControllers.any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }
    setState(() => _guardando = true);
    final nuevo = {
      'empleado': _empleadoController.text.trim(),
      'devolucion_mkp': _devolucionController.text.trim(),
      'skus': _skuControllers.map((c) => c.text.trim()).toList(),
      'cantidad': _cantidad,
      'usuario': widget.usuario,
      'fecha': DateTime.now().toIso8601String(),
    };
    // Leer existentes
    final doc = await FirebaseFirestore.instance
        .collection('entregas')
        .doc('mkp')
        .get();
    List<dynamic> existentes = [];
    if (doc.exists && doc.data() != null && doc.data()!.containsKey('items')) {
      final data = doc.data()!['items'];
      if (data is List) {
        existentes = List.from(data);
      }
    }
    final nuevosItems = [...existentes, nuevo];
    await guardarDatosFirestoreYCache(
        'entregas', 'mkp', {'items': nuevosItems});
    setState(() {
      _guardando = false;
      _empleadoController.clear();
      _devolucionController.clear();
      for (final c in _skuControllers) {
        c.clear();
      }
      _cantidad = 1;
    });
    await _cargarRegistros();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro guardado.')),
    );
  }

  @override
  void dispose() {
    _empleadoController.dispose();
    _devolucionController.dispose();
    for (final c in _skuControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entregas MKP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _empleadoController,
                      decoration: const InputDecoration(
                        labelText: 'Número de empleado',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _devolucionController,
                      decoration: const InputDecoration(
                        labelText: 'Devolución MKP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Cantidad:'),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _cantidad > 1
                              ? () => setState(() => _cantidad--)
                              : null,
                        ),
                        Text('$_cantidad',
                            style: const TextStyle(fontSize: 18)),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _cantidad++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('SKU(s):'),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Agregar otro SKU',
                          onPressed: () {
                            setState(() {
                              _skuControllers.add(TextEditingController());
                            });
                          },
                        ),
                      ],
                    ),
                    ..._skuControllers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ctrl = entry.value;
                      return Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: TextField(
                                controller: ctrl,
                                decoration: InputDecoration(
                                  labelText: 'SKU ${idx + 1}',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          if (_skuControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              tooltip: 'Eliminar SKU',
                              onPressed: () {
                                setState(() {
                                  _skuControllers.removeAt(idx);
                                });
                              },
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardarRegistro,
                        child: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Registros recientes:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _registros.isEmpty
                      ? const Center(child: Text('No hay registros aún.'))
                      : ListView.builder(
                          itemCount: _registros.length,
                          itemBuilder: (context, idx) {
                            final reg = _registros[_registros.length - 1 - idx];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(
                                    'Empleado: ${reg['empleado'] ?? '-'} | Devolución: ${reg['devolucion_mkp'] ?? '-'}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'SKU(s): ${(reg['skus'] as List?)?.join(', ') ?? '-'}'),
                                    Text('Cantidad: ${reg['cantidad'] ?? '-'}'),
                                    Text('Usuario: ${reg['usuario'] ?? '-'}'),
                                    Text(
                                        'Fecha: ${reg['fecha'] != null ? reg['fecha'].toString().substring(0, 19).replaceFirst('T', ' ') : '-'}'),
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
