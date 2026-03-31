import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';

class GuiasMkpPage extends StatefulWidget {
  const GuiasMkpPage({Key? key}) : super(key: key);

  @override
  State<GuiasMkpPage> createState() => _GuiasMkpPageState();
}

class _GuiasMkpPageState extends State<GuiasMkpPage> {
  List<Map<String, dynamic>> _registros = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    setState(() => _cargando = true);
    // Leer devoluciones de Entregas MKP
    final entregasCache = await leerDatosConCache('entregas', 'mkp');
    List<Map<String, dynamic>> entregas = [];
    if (entregasCache != null && entregasCache['items'] is List) {
      entregas = List<Map<String, dynamic>>.from(
        (entregasCache['items'] as List).whereType<Map<String, dynamic>>(),
      );
    }
    // Leer guías guardadas
    final guiasCache = await leerDatosConCache('guias', 'mkp');
    List<Map<String, dynamic>> guias = [];
    if (guiasCache != null && guiasCache['items'] is List) {
      guias = List<Map<String, dynamic>>.from(
        (guiasCache['items'] as List).whereType<Map<String, dynamic>>(),
      );
    }
    // Unir devoluciones y guías
    final Set<String> devoluciones = entregas
        .map((e) => e['devolucion_mkp']?.toString() ?? '')
        .where((d) => d.isNotEmpty)
        .toSet();
    final Map<String, Map<String, dynamic>> guiasMap = {
      for (var g in guias) g['devolucion'] ?? '': g
    };
    final List<Map<String, dynamic>> registros = [];
    for (final dev in devoluciones) {
      if (guiasMap.containsKey(dev)) {
        registros.add({...guiasMap[dev]!});
      } else {
        registros.add({'devolucion': dev, 'guia': '', 'fecha': ''});
      }
    }
    // Agregar manualmente filas extra si existen en guias pero no en entregas
    for (final g in guias) {
      if (!devoluciones.contains(g['devolucion'])) {
        registros.add({...g});
      }
    }
    // Ordenar: sin guía arriba, con guía abajo
    registros.sort((a, b) {
      final aGuia = (a['guia'] ?? '').toString().trim().isEmpty ? 0 : 1;
      final bGuia = (b['guia'] ?? '').toString().trim().isEmpty ? 0 : 1;
      return aGuia - bGuia;
    });
    setState(() {
      _registros = registros;
      _cargando = false;
    });
  }

  void _agregarFila() {
    setState(() {
      _registros.insert(0, {'devolucion': '', 'guia': '', 'fecha': ''});
    });
  }

  void _actualizarCampo(int idx, String campo, String valor) {
    setState(() {
      _registros[idx][campo] = valor;
      if (campo == 'guia' && valor.trim().isNotEmpty) {
        _registros[idx]['fecha'] = DateTime.now().toIso8601String();
      }
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    // Guardar en Firestore y cache
    final items = _registros
        .where((r) => (r['devolucion'] ?? '').toString().isNotEmpty)
        .toList();
    await guardarDatosFirestoreYCache('guias', 'mkp', {'items': items});
    setState(() => _guardando = false);
    await _cargarRegistros();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registros guardados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Guías MKP'),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF2D6A4F),
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar fila'),
                        onPressed: _agregarFila,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6A4F),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Guardar'),
                        onPressed: _guardando ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Devolución')),
                          DataColumn(label: Text('Guía')),
                          DataColumn(label: Text('Fecha')),
                        ],
                        rows: List.generate(_registros.length, (idx) {
                          final reg = _registros[idx];
                          return DataRow(cells: [
                            DataCell(
                              TextFormField(
                                initialValue: reg['devolucion'] ?? '',
                                decoration: const InputDecoration(
                                    border: InputBorder.none),
                                onChanged: (v) =>
                                    _actualizarCampo(idx, 'devolucion', v),
                              ),
                            ),
                            DataCell(
                              TextFormField(
                                initialValue: reg['guia'] ?? '',
                                decoration: const InputDecoration(
                                    border: InputBorder.none),
                                onChanged: (v) =>
                                    _actualizarCampo(idx, 'guia', v),
                              ),
                            ),
                            DataCell(
                              Text(
                                (reg['fecha'] ?? '').toString().isEmpty
                                    ? ''
                                    : reg['fecha']
                                        .toString()
                                        .replaceFirst('T', ' ')
                                        .substring(0, 19),
                              ),
                            ),
                          ]);
                        }),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
