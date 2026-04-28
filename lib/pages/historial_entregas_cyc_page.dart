import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'package:universal_html/html.dart' as html;

class HistorialEntregasCycPage extends StatefulWidget {
  final String usuario;
  const HistorialEntregasCycPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<HistorialEntregasCycPage> createState() =>
      _HistorialEntregasCycPageState();
}

class _HistorialEntregasCycPageState extends State<HistorialEntregasCycPage> {
  List<Map<String, dynamic>> _firmadas = [];
  bool _cargando = true;
  String _filtro = '';
  late TextEditingController _busquedaController;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarFirmadas();
  }

  Future<void> _cargarFirmadas() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      // Cargar items antiguos
      final doc = await firestore
          .collection('historial_entregas')
          .doc('cyc_firmadas')
          .get();
      final data = doc.exists ? doc.data() : null;
      List<Map<String, dynamic>> antiguos = [];
      if (data != null && data['items'] is List) {
        for (var e in (data['items'] as List)) {
          if (e is Map) {
            antiguos.add(Map<String, dynamic>.from(
                e.map((k, v) => MapEntry(k.toString(), v))));
          }
        }
      }
      // Cargar subcolección firmas
      final snap = await firestore
          .collection('historial_entregas')
          .doc('cyc_firmadas')
          .collection('firmas')
          .get();
      final firmas = snap.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
      // Unir ambos y eliminar duplicados por id
      final Map<String, Map<String, dynamic>> unificados = {};
      for (final reg in antiguos) {
        final id = reg['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          unificados[id] = reg;
        } else {
          unificados[UniqueKey().toString()] = reg;
        }
      }
      for (final reg in firmas) {
        final id = reg['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          unificados[id] = reg;
        } else {
          unificados[UniqueKey().toString()] = reg;
        }
      }
      final nuevos = unificados.values.toList();
      // Ordenar descendente por fechaValidacion o fechaFirma o fecha
      nuevos.sort((a, b) {
        final fa = a['fechaValidacion'] ?? a['fechaFirma'] ?? a['fecha'] ?? '';
        final fb = b['fechaValidacion'] ?? b['fechaFirma'] ?? b['fecha'] ?? '';
        return fb.compareTo(fa);
      });
      setState(() {
        _firmadas = nuevos;
        _cargando = false;
        _errorCarga = null;
      });
    } catch (e) {
      setState(() {
        _firmadas = [];
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
        ? _firmadas
        : _firmadas
            .where((e) => e.entries.any((entry) {
                  final v = entry.value;
                  if (v == null) return false;
                  return v.toString().toLowerCase().contains(_filtro);
                }))
            .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.fact_check, color: Color(0xFF2D6A4F), size: 30),
            const SizedBox(width: 10),
            const Text(
              'Historial Entregas CyC',
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
            onPressed: _cargarFirmadas,
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
                          ? const Center(
                              child: Text('No hay entregas firmadas.'))
                          : ListView.separated(
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemCount: resultados.length,
                              itemBuilder: (context, index) {
                                final entrega = resultados[index];
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
                                          const Base64Decoder()
                                              .convert(firmaData));
                                    }
                                    if (bytes != null && bytes.isNotEmpty) {
                                      firmaWidget = Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Column(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  const Color(0xFF2D6A4F),
                                              child: const Icon(
                                                  Icons.fact_check,
                                                  color: Colors.white),
                                            ),
                                            if (firmaWidget != null)
                                              firmaWidget,
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.grey[700]),
                                                  ),
                                                  Text(
                                                    entrega['LP']?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                  ),
                                                  const SizedBox(width: 18),
                                                  Text(
                                                    'N° PEDIDO: ',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.grey[700]),
                                                  ),
                                                  Text(
                                                    entrega['NUMERO DE PEDIDO']
                                                            ?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                  ),
                                                  const Spacer(),
                                                  Icon(Icons.calendar_today,
                                                      size: 18,
                                                      color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    (entrega['fechaValidacion']
                                                                    ?.toString()
                                                                    .substring(
                                                                        0,
                                                                        10) ??
                                                                '-') !=
                                                            ''
                                                        ? entrega[
                                                                'fechaValidacion']
                                                            .toString()
                                                            .substring(0, 10)
                                                        : '-',
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color:
                                                            Color(0xFF495057)),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.person_outline,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    entrega['validadoPor']
                                                            ?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color:
                                                            Color(0xFF495057)),
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
                                                    'Recibió: ',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                  ),
                                                  Text(
                                                    (entrega['recibidoPor']
                                                                ?.toString() ??
                                                            '-')
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              const SizedBox(height: 8),
                                              Text(
                                                'SKU: ${entrega['SKU'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF495057)),
                                              ),
                                              Text(
                                                'Descripción: ${entrega['DESCRIPCION'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF495057)),
                                              ),
                                              // No hay campo CANTIDAD en tus datos, así que lo omito
                                              Text(
                                                'Sección: ${entrega['SECCION'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF495057)),
                                              ),
                                              Text(
                                                'Jefatura: ${entrega['JEFATURA'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF495057)),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.verified_user,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Validó: ' +
                                                        (entrega['usuarioValido']
                                                                ?.toString() ??
                                                            '-'),
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        color:
                                                            Color(0xFF495057)),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  const Icon(
                                                      Icons.person_outline,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Entregó: ' +
                                                        (entrega['validadoPor']
                                                                ?.toString() ??
                                                            '-'),
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        color:
                                                            Color(0xFF495057)),
                                                  ),
                                                ],
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

  void _descargarExcel() {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Historial'];
    // Orden de columnas igual que en dev_cyc_page.dart
    final orderedKeys = [
      'NUMERO DE PEDIDO',
      'LP',
      'SKU',
      'DESCRIPCION',
      'SECCION',
      'BODEGA',
      'JEFATURA',
    ];
    // Encabezados para Excel
    final headerMap = {
      'NUMERO DE PEDIDO': 'NUMERO DE PEDIDO',
      'LP': 'LP',
      'SKU': 'SKU',
      'DESCRIPCION': 'DESCRIPCION',
      'SECCION': 'SECCION',
      'BODEGA': 'BODEGA',
      'JEFATURA': 'JEFATURA',
    };
    sheet.appendRow([for (final k in orderedKeys) headerMap[k] ?? k]);
    for (final row in _firmadas) {
      final rowValues = orderedKeys.map((k) => row[k] ?? '').toList();
      sheet.appendRow(rowValues);
    }
    final bytes = excel.encode();
    if (bytes != null) {
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'historial_entregas_cyc.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }
}
