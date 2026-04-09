import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../utils/firebase_cache_utils.dart';
// imports eliminados porque ya no se usan aquí
import 'entregas_mkp_registros_page.dart';

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
  // List<Map<String, dynamic>> _registros = [];
  // bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    // setState(() => _cargando = true);
    // Ya no se requiere cargar registros aquí
  }

  // _exportarAExcel eliminado, ahora la exportación está en la página de registros

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: const [
            Icon(Icons.shopping_cart_checkout,
                color: Color(0xFF2D6A4F), size: 30),
            SizedBox(width: 10),
            Text(
              'Entregas MKP',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final formWidth = isMobile ? double.infinity : 450.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 8 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Card(
                        elevation: 3,
                        child: Container(
                          width: formWidth,
                          padding: EdgeInsets.all(isMobile ? 12 : 24),
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
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              SizedBox(height: isMobile ? 8 : 16),
                              TextField(
                                controller: _devolucionController,
                                decoration: const InputDecoration(
                                  labelText: 'Devolución MKP',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  // Solo números
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              SizedBox(height: isMobile ? 8 : 16),
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
                                    onPressed: () =>
                                        setState(() => _cantidad++),
                                  ),
                                ],
                              ),
                              SizedBox(height: isMobile ? 8 : 16),
                              Row(
                                children: [
                                  const Text('SKU(s):'),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    tooltip: 'Agregar otro SKU',
                                    onPressed: () {
                                      setState(() {
                                        _skuControllers
                                            .add(TextEditingController());
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0),
                                        child: TextField(
                                          controller: ctrl,
                                          decoration: InputDecoration(
                                            labelText: 'SKU ${idx + 1}',
                                            border: const OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
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
                              SizedBox(height: isMobile ? 8 : 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed:
                                      _guardando ? null : _guardarRegistro,
                                  child: _guardando
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('Guardar'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 32),
                    SizedBox(height: isMobile ? 16 : 32),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Ver registros recientes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6A4F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EntregasMkpRegistrosPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
