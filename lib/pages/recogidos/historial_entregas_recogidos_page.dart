import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

class HistorialEntregasRecogidosPage extends StatefulWidget {
  final List<Map<String, dynamic>> historial;
  final String tipoUsuarioActual;
  const HistorialEntregasRecogidosPage(
      {Key? key, required this.historial, required this.tipoUsuarioActual})
      : super(key: key);

  @override
  State<HistorialEntregasRecogidosPage> createState() =>
      _HistorialEntregasRecogidosPageState();
}

class _HistorialEntregasRecogidosPageState
    extends State<HistorialEntregasRecogidosPage> {
  late List<Map<String, dynamic>> _resultados;
  Future<void> _eliminarRegistro(int index) async {
    setState(() {
      _resultados.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'historial_entregas_recogidos', jsonEncode(_resultados));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro eliminado del historial.')),
    );
  }

  late TextEditingController _busquedaController;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _resultados = widget.historial;
    _busquedaController = TextEditingController();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _filtrar(String value) {
    setState(() {
      _filtro = value.toLowerCase();
      _resultados = widget.historial.where((e) {
        return e.values
            .any((v) => v.toString().toLowerCase().contains(_filtro));
      }).toList();
    });
  }

  void _descargarExcel() {
    final excel = Excel.createExcel();
    final sheet = excel['Historial'];
    if (_resultados.isNotEmpty) {
      sheet.appendRow(_resultados.first.keys.toList());
      for (final row in _resultados) {
        sheet.appendRow(row.values.toList());
      }
    }
    final bytes = excel.encode();
    if (bytes != null) {
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'historial_entregas_recogidos.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.fact_check, color: Color(0xFF2D6A4F), size: 30),
            const SizedBox(width: 10),
            const Text(
              'Historial Entregas Recogidos',
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
                  ? const Center(child: Text('No hay entregas firmadas'))
                  : ListView.separated(
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _resultados.length,
                      itemBuilder: (context, index) {
                        final entrega = _resultados[index];
                        final dynamic firmaData = entrega['firma'];
                        Widget? firmaWidget;
                        if (firmaData != null) {
                          try {
                            Uint8List? bytes;
                            if (firmaData is Uint8List) {
                              bytes = firmaData;
                            } else if (firmaData is List<int>) {
                              bytes = Uint8List.fromList(firmaData);
                            } else if (firmaData is String) {
                              bytes = Uint8List.fromList(
                                  const Base64Decoder().convert(firmaData));
                            }
                            if (bytes != null && bytes.isNotEmpty) {
                              firmaWidget = Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    bytes,
                                    width: 70,
                                    height: 40,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            }
                          } catch (_) {}
                        }
                        return Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF2D6A4F),
                                      child: const Icon(Icons.fact_check,
                                          color: Colors.white),
                                    ),
                                    if (firmaWidget != null) firmaWidget,
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
                                          Text(
                                            'LP: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700]),
                                          ),
                                          Text(
                                            entrega['LP']?.toString() ?? '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Color(0xFF2D6A4F)),
                                          ),
                                          const Spacer(),
                                          Icon(Icons.calendar_today,
                                              size: 18,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            entrega['fechaFirma'] != null
                                                ? entrega['fechaFirma']
                                                    .toString()
                                                    .substring(0, 10)
                                                : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF495057)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 6),
                                          Text(
                                            entrega['nombreRecibe']
                                                    ?.toString() ??
                                                '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'SKU: \\${entrega['SKU'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Descripción: \\${entrega['DESCRIPCION'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Cantidad: \\${entrega['CANTIDAD'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Sección: \\${entrega['SECCION'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Jefatura: \\${entrega['JEFATURA'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.tipoUsuarioActual ==
                                        'ADMINISTRATIVO' ||
                                    widget.tipoUsuarioActual == 'SUPERADMIN')
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    tooltip: 'Eliminar registro',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title:
                                              const Text('Eliminar registro'),
                                          content: const Text(
                                              '¿Seguro que deseas eliminar este registro del historial?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _eliminarRegistro(index);
                                      }
                                    },
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
