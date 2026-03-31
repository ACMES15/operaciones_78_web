import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';

class GuiasMkpPage extends StatefulWidget {
  const GuiasMkpPage({Key? key}) : super(key: key);

  @override
  State<GuiasMkpPage> createState() => _GuiasMkpPageState();
}

class _GuiasMkpPageState extends State<GuiasMkpPage> {
  final TextEditingController _busquedaController = TextEditingController();
  String _filtro = '';
  bool _editando = true;
  List<Map<String, dynamic>> _registros = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    _busquedaController.addListener(() {
      setState(() {
        _filtro = _busquedaController.text.trim().toLowerCase();
      });
    });
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
    setState(() {
      _guardando = false;
      _editando = false;
    });
    await _cargarRegistros();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registros guardados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registrosFiltrados = _filtro.isEmpty
        ? _registros
        : _registros.where((r) {
            final dev = (r['devolucion'] ?? '').toString().toLowerCase();
            final guia = (r['guia'] ?? '').toString().toLowerCase();
            final fecha = (r['fecha'] ?? '').toString().toLowerCase();
            return dev.contains(_filtro) ||
                guia.contains(_filtro) ||
                fecha.contains(_filtro);
          }).toList();
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
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(24),
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 600,
                    child: TextField(
                      controller: _busquedaController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por devolución, guía o fecha...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                    const Color(0xFF2D6A4F)),
                                headingTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                                dataRowColor:
                                    MaterialStateProperty.resolveWith<Color?>(
                                        (states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.amber.shade100;
                                  }
                                  return Colors.white;
                                }),
                                columns: const [
                                  DataColumn(label: Text('Devolución')),
                                  DataColumn(label: Text('Guía')),
                                  DataColumn(label: Text('Fecha')),
                                ],
                                rows: List.generate(registrosFiltrados.length,
                                    (idx) {
                                  final reg = registrosFiltrados[idx];
                                  final esEditable = _editando &&
                                          (reg['devolucion'] ?? '')
                                              .toString()
                                              .isEmpty ||
                                      _editando &&
                                          (reg['guia'] ?? '')
                                              .toString()
                                              .isEmpty;
                                  return DataRow(cells: [
                                    DataCell(
                                      esEditable
                                          ? TextFormField(
                                              initialValue:
                                                  reg['devolucion'] ?? '',
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                hintText: 'Devolución',
                                              ),
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500),
                                              onChanged: (v) =>
                                                  _actualizarCampo(
                                                      _registros.indexOf(reg),
                                                      'devolucion',
                                                      v),
                                            )
                                          : Text(reg['devolucion'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                    ),
                                    DataCell(
                                      esEditable
                                          ? TextFormField(
                                              initialValue: reg['guia'] ?? '',
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                hintText: 'Guía',
                                              ),
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500),
                                              onChanged: (v) =>
                                                  _actualizarCampo(
                                                      _registros.indexOf(reg),
                                                      'guia',
                                                      v),
                                            )
                                          : Text(reg['guia'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                    ),
                                    DataCell(
                                      Text(
                                        (reg['fecha'] ?? '').toString().isEmpty
                                            ? ''
                                            : reg['fecha']
                                                .toString()
                                                .replaceFirst('T', ' ')
                                                .substring(0, 19),
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF2D6A4F)),
                                      ),
                                    ),
                                  ]);
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar fila'),
                                onPressed: _editando ? _agregarFila : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D6A4F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                icon: _guardando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.save),
                                label: const Text('Guardar'),
                                onPressed:
                                    _editando && !_guardando ? _guardar : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
