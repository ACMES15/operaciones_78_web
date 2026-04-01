import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';// import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';

class GuiasMkpPage extends StatefulWidget {
  const GuiasMkpPage({Key? key}) : super(key: key);

  @override
  State<GuiasMkpPage> createState() => _GuiasMkpPageState();
}



class _GuiasMkpPageState extends State<GuiasMkpPage> {
  // Notifica a admins si hay devoluciones sin guía con más de 24h
  Future<void> _notificarDevolucionesSinGuia() async {
    final ahora = DateTime.now();
    // Buscar devoluciones sin guía y con fecha > 24h
    final sinGuia24h = _registros.where((r) {
      if ((r['devolucion'] ?? '').toString().isEmpty || (r['guia'] ?? '').toString().isNotEmpty) return false;
      final fechaStr = r['fecha'] ?? '';
      if (fechaStr.isEmpty) return false;
      DateTime? fecha;
      try {
        fecha = DateTime.parse(fechaStr);
      } catch (_) {
        return false;
      }
      return ahora.difference(fecha).inHours >= 24;
    }).toList();
    if (sinGuia24h.isEmpty) return;

    final admins = ['ADMIN OMNICANAL', 'ADMIN ENVIOS'];
    final mensaje = 'Se tienen Devoluciones sin tratar un total de: ${sinGuia24h.length}';
    final detalle = 'Devoluciones sin guía con más de 24h: ${sinGuia24h.map((r) => r['devolucion']).join(', ')}';
    final fecha = ahora.toIso8601String();

    // Leer notificaciones existentes (para compatibilidad con notificaciones_page)
    final doc = await FirebaseFirestore.instance.collection('notificaciones').doc('password').get();
    List items = [];
    if (doc.exists && doc.data() != null) {
      items = (doc.data()!['items'] ?? []) as List;
    }
    // Revisar si ya se envió una notificación igual en las últimas 24h
    final yaEnviada = items.any((n) {
      if (n is! Map) return false;
      if (n['mensaje'] != mensaje) return false;
      if (n['fecha'] == null) return false;
      try {
        final f = DateTime.parse(n['fecha']);
        return ahora.difference(f).inHours < 24;
      } catch (_) {
        return false;
      }
    });
    if (yaEnviada) return;

    // Agregar notificación para cada admin en el array (para notificaciones_page)
    for (final admin in admins) {
      items.add({
        'mensaje': mensaje,
        'detalle': detalle,
        'fecha': fecha,
        'usuario': admin,
        'atendido': false,
      });
    }
    await FirebaseFirestore.instance.collection('notificaciones').doc('password').set({'items': items});

    // Agregar notificación para cada admin como documento individual (para campana principal)
    for (final admin in admins) {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'detalle': detalle,
        'fecha': fecha,
        'para': admin,
        'leida': false,
        'tipo': 'devolucion_sin_guia',
      });
    }
  }
    void _exportarAExcel(List<Map<String, dynamic>> registros) async {
      if (registros.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay registros para exportar.')),
        );
        return;
      }
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Guías MKP'];
      final headers = [
        'Devolución',
        'Guía',
        'Fecha',
      ];
      sheet.appendRow(headers);
      for (final reg in registros) {
        sheet.appendRow([
          reg['devolucion'] ?? '',
          reg['guia'] ?? '',
          reg['fecha'] ?? '',
        ]);
      }
      final bytes = excelFile.encode()!;
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'guias_mkp.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
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
    _cargarRegistros().then((_) => _notificarDevolucionesSinGuia());
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
      // Agrega una nueva fila vacía al final, sin eliminar ni filtrar otras filas
      _registros.add({'devolucion': '', 'guia': '', 'fecha': ''});
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    // Guardar TODOS los registros (incluyendo incompletos) y bloquear solo los completos
    final items = _registros.map((r) {
      final completo = (r['devolucion'] ?? '').toString().isNotEmpty &&
          (r['guia'] ?? '').toString().isNotEmpty &&
          (r['fecha'] ?? '').toString().isNotEmpty;
      if (completo) {
        return {...r, 'bloqueado': true};
      } else {
        return {...r, 'bloqueado': false};
      }
    }).toList();
    await guardarDatosFirestoreYCache('guias', 'mkp', {'items': items});
    setState(() {
      _guardando = false;
      _registros = items;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registros guardados.')),
    );
  }

  void _actualizarCampo(int idx, String campo, String valor) {
    setState(() {
      _registros[idx][campo] = valor;
      if (campo == 'guia' && valor.trim().isNotEmpty) {
        _registros[idx]['fecha'] = DateTime.now().toIso8601String();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrosFiltrados = _filtro.isEmpty
        ? _registros
        : _registros.where((r) {
            final dev = (r['devolucion'] ?? '').toString().toLowerCase();
            final devMkp = (r['devolucion_mkp'] ?? '').toString().toLowerCase();
            final guia = (r['guia'] ?? '').toString().toLowerCase();
            return dev.contains(_filtro) || devMkp.contains(_filtro) || guia.contains(_filtro);
          }).toList();
    // Contador de devoluciones sin guía
    final int devolucionesSinGuia = _registros.where((r) => (r['devolucion'] ?? '').toString().isNotEmpty && (r['guia'] ?? '').toString().isEmpty).length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                const Icon(Icons.assignment, color: Color(0xFF2D6A4F), size: 30),
                if (devolucionesSinGuia > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        devolucionesSinGuia.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            const Text('Registro de Guías MKP'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF2D6A4F),
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF2D6A4F)),
            tooltip: 'Exportar a Excel',
            onPressed: () => _exportarAExcel(registrosFiltrados),
          ),
        ],
      ),
        // ...existing code...
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Botones en la parte superior derecha
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 180,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar fila'),
                              onPressed: _agregarFila,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 180,
                            child: ElevatedButton.icon(
                              icon: _guardando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Guardar'),
                              onPressed: _editando && !_guardando ? _guardar : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 420,
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
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          width: 700,
                          height: 400,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: BoxBorder.lerp(Border.all(color: Colors.grey.shade300), Border.all(color: Colors.grey.shade300), 1)!,
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 650,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    DataTable(
                                      headingRowColor: MaterialStateProperty.all(const Color(0xFF2D6A4F)),
                                      headingTextStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                      dataRowColor: MaterialStateProperty.resolveWith<Color?>((states) {
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
                                      rows: List.generate(
                                        (_registros.length > 8 ? _registros.length : 8),
                                        (idx) {
                                          if (idx < registrosFiltrados.length) {
                                            final reg = registrosFiltrados[idx];
                                            final bloqueado = reg['bloqueado'] == true;
                                            return DataRow(cells: [
                                              DataCell(
                                                bloqueado
                                                    ? Text(reg['devolucion'] ?? '', style: const TextStyle(fontSize: 15))
                                                    : TextFormField(
                                                        initialValue: reg['devolucion'] ?? '',
                                                        decoration: const InputDecoration(
                                                          border: InputBorder.none,
                                                          hintText: 'Devolución',
                                                        ),
                                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                                        onChanged: (v) => _actualizarCampo(_registros.indexOf(reg), 'devolucion', v),
                                                        enabled: true,
                                                      ),
                                              ),
                                              DataCell(
                                                bloqueado
                                                    ? Text(reg['guia'] ?? '', style: const TextStyle(fontSize: 15))
                                                    : TextFormField(
                                                        initialValue: reg['guia'] ?? '',
                                                        decoration: const InputDecoration(
                                                          border: InputBorder.none,
                                                          hintText: 'Guía',
                                                        ),
                                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                                        onChanged: (v) => _actualizarCampo(_registros.indexOf(reg), 'guia', v),
                                                        enabled: true,
                                                      ),
                                              ),
                                              DataCell(
                                                Text(
                                                  (reg['fecha'] ?? '').toString().isEmpty
                                                      ? ''
                                                      : reg['fecha'].toString().replaceFirst('T', ' ').substring(0, 19),
                                                  style: const TextStyle(fontSize: 15, color: Color(0xFF2D6A4F)),
                                                ),
                                              ),
                                            ]);
                                          } else {
                                            // Fila vacía para mantener el tamaño
                                            return const DataRow(cells: [
                                              DataCell(Text('')),
                                              DataCell(Text('')),
                                              DataCell(Text('')),
                                            ]);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ... Botones duplicados eliminados ...
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
