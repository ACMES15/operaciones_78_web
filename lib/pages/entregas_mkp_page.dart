import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:html' as html;

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

  Future<void> _exportarAExcel() async {
    if (_registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }
    final excel = Excel.createExcel();
    final sheet = excel['Entregas MKP'];
    // Encabezados
    final headers = [
      'Empleado',
      'Devolución MKP',
      'SKU(s)',
      'Cantidad',
      'Usuario',
      'Fecha'
    ];
    sheet.appendRow(headers);
    for (final reg in _registros) {
      sheet.appendRow([
        reg['empleado'] ?? '',
        reg['devolucion_mkp'] ?? '',
        (reg['skus'] as List?)?.join(', ') ?? '',
        reg['cantidad']?.toString() ?? '',
        reg['usuario'] ?? '',
        reg['fecha'] ?? '',
      ]);
    }
    final bytes = excel.encode()!;
    final blob = html.Blob([Uint8List.fromList(bytes)],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'entregas_mkp.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
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
                              ),
                              SizedBox(height: isMobile ? 8 : 16),
                              TextField(
                                controller: _devolucionController,
                                decoration: const InputDecoration(
                                  labelText: 'Devolución MKP',
                                  border: OutlineInputBorder(),
                                ),
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
                                  onPressed:
                                      _guardando ? null : _guardarRegistro,
                                  child: _guardando
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
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
                    const Text('Registros recientes:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: isMobile ? 8 : 16),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: isMobile ? 350 : 500),
                      child: _cargando
                          ? const Center(child: CircularProgressIndicator())
                          : _registros.isEmpty
                              ? const Center(
                                  child: Text('No hay registros aún.'))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _registros.length,
                                  itemBuilder: (context, idx) {
                                    final reg =
                                        _registros[_registros.length - 1 - idx];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: ListTile(
                                        title: Text(
                                            'Empleado: ${reg['empleado'] ?? '-'} | Devolución: ${reg['devolucion_mkp'] ?? '-'}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'SKU(s): ${(reg['skus'] as List?)?.join(', ') ?? '-'}'),
                                            Text(
                                                'Cantidad: ${reg['cantidad'] ?? '-'}'),
                                            Text(
                                                'Usuario: ${reg['usuario'] ?? '-'}'),
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
            ),
          );
        },
      ),
    );
  }
}
