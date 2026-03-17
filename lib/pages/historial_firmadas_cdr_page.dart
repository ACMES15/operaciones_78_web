import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'package:universal_html/html.dart' as html;

class HistorialFirmadasCdrPage extends StatefulWidget {
  const HistorialFirmadasCdrPage({Key? key}) : super(key: key);

  @override
  State<HistorialFirmadasCdrPage> createState() =>
      _HistorialFirmadasCdrPageState();
}

class _HistorialFirmadasCdrPageState extends State<HistorialFirmadasCdrPage> {
  List<Map<String, dynamic>> _firmadas = [];
  bool _cargando = true;
  String _filtro = '';
  late TextEditingController _busquedaController;

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarFirmadas();
  }

  Future<void> _cargarFirmadas() async {
    setState(() => _cargando = true);
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore
        .collection('historial_entregas')
        .doc('cdr_firmadas')
        .get();
    final data = doc.exists ? doc.data() : null;
    List<Map<String, dynamic>> nuevos = [];
    if (data != null && data['items'] is List) {
      for (var e in (data['items'] as List)) {
        if (e is Map) {
          nuevos.add(Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }
    setState(() {
      _firmadas = nuevos;
      _cargando = false;
    });
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
              'Historial Entregas CDR',
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
                  : resultados.isEmpty
                      ? const Center(child: Text('No hay entregas firmadas.'))
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
                            final isFaltante = entrega['BOX'] == true ||
                                entrega['BOX'] == 'true';
                            return Card(
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: isFaltante
                                  ? const Color(0xFFFFCDD2)
                                  : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              const Color(0xFF2D6A4F),
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
                                                entrega['LP']?.toString() ??
                                                    '-',
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
                                                (entrega['nombreRecibe']
                                                            ?.toString() ??
                                                        '-')
                                                    .toUpperCase(),
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
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.verified_user,
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
                                                          Color(0xFF495057))),
                                              const SizedBox(width: 16),
                                              const Icon(Icons.person_outline,
                                                  size: 18,
                                                  color: Color(0xFF2D6A4F)),
                                              const SizedBox(width: 6),
                                              Text(
                                                  'Entregó: ' +
                                                      (entrega['usuarioEntrega']
                                                              ?.toString() ??
                                                          '-'),
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      color:
                                                          Color(0xFF495057))),
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
    if (_firmadas.isNotEmpty) {
      // Obtener todas las claves únicas de todos los registros
      final allKeys = <String>{};
      for (final row in _firmadas) {
        allKeys.addAll(row.keys);
      }
      final orderedKeys = allKeys.toList();
      sheet.appendRow(orderedKeys);
      for (final row in _firmadas) {
        // Alinear los valores según el orden de las claves
        final rowValues = orderedKeys.map((k) => row[k] ?? '').toList();
        sheet.appendRow(rowValues);
      }
    }
    final bytes = excel.encode();
    if (bytes != null) {
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'historial_entregas_cdr.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Widget _infoChip(String label, dynamic value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D6A4F)),
      ),
      child: Text('$label: ${value ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
