import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'dart:html' as html;

class HistorialEntregasXdPage extends StatefulWidget {
  final List<Map<String, dynamic>> historial;
  final String tipoUsuarioActual;
  const HistorialEntregasXdPage({
    Key? key,
    required this.historial,
    required this.tipoUsuarioActual,
  }) : super(key: key);

  @override
  State<HistorialEntregasXdPage> createState() =>
      _HistorialEntregasXdPageState();
}

class _HistorialEntregasXdPageState extends State<HistorialEntregasXdPage> {
  String _formatearFecha(dynamic fecha) {
    try {
      DateTime dt =
          fecha is DateTime ? fecha : DateTime.parse(fecha.toString());
      String dia = dt.day.toString().padLeft(2, '0');
      String mes = dt.month.toString().padLeft(2, '0');
      String anio = dt.year.toString();
      return '$dia-$mes-$anio';
    } catch (_) {
      return 'null';
    }
  }

  late List<Map<String, dynamic>> _resultados;
  List<Map<String, dynamic>> _datosOriginales = [];
  late TextEditingController _busquedaController;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _recargarFirestore();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _filtrar(String value) {
    setState(() {
      _filtro = value.toLowerCase();
      _resultados = _datosOriginales.where((e) {
        return e.entries.any((entry) {
          final v = entry.value;
          if (v == null) return false;
          return v.toString().toLowerCase().contains(_filtro);
        });
      }).toList();
    });
  }

  Future<void> _recargarFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore
        .collection('historial_entregas')
        .doc('dev_xd_firmadas')
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
    _datosOriginales = List<Map<String, dynamic>>.from(nuevos);
    _busquedaController.clear();
    _filtro = '';
    _resultados = List<Map<String, dynamic>>.from(_datosOriginales);
    setState(() {});
  }

  void _exportarAExcel() {
    final excel = Excel.createExcel();
    final sheet = excel['Historial Entregas XD'];
    // Encabezados
    final headers = [
      'XD',
      'SKU',
      'DESCRIPCION',
      'CANTIDAD',
      'SECCION',
      'JEFATURA',
      'nombreRecibe',
      'usuarioValido',
      'usuarioEntrega',
      'fecha'
    ];
    sheet.appendRow(headers);
    for (final entrega in _resultados) {
      sheet.appendRow([
        entrega['XD'] ?? '',
        entrega['SKU'] ?? '',
        entrega['DESCRIPCION'] ?? '',
        entrega['CANTIDAD'] ?? '',
        entrega['SECCION'] ?? '',
        entrega['JEFATURA'] ?? '',
        entrega['nombreRecibe'] ?? '',
        entrega['usuarioValido'] ?? '',
        entrega['usuarioEntrega'] ?? '',
        entrega['fecha'] ?? '',
      ]);
    }
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final blob = html.Blob([fileBytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'historial_entregas_xd.xlsx')
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
              'Historial Entregas XD',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        // ...existing code...
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2D6A4F)),
            onPressed: _recargarFirestore,
            tooltip: 'Actualizar desde Firestore',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF2D6A4F)),
            onPressed: _exportarAExcel,
            tooltip: 'Descargar Excel',
          ),
        ],
      ),
      // ...existing code...
      // ...existing code...
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
                  ? Center(
                      child: Text(
                        _filtro.isEmpty
                            ? 'No hay entregas registradas'
                            : 'No hay coincidencias para tu búsqueda',
                        style: const TextStyle(fontSize: 16),
                      ),
                    )
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
                              bytes =
                                  Uint8List.fromList(base64Decode(firmaData));
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
                                            'XD: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700]),
                                          ),
                                          Text(
                                            entrega['XD']?.toString() ?? '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Color(0xFF2D6A4F)),
                                          ),
                                          const SizedBox(width: 18),
                                          // FECHA
                                          Icon(Icons.calendar_today,
                                              size: 18,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            (entrega['fecha']
                                                            ?.toString()
                                                            .substring(0, 10) ??
                                                        '-') !=
                                                    ''
                                                ? entrega['fecha']
                                                    .toString()
                                                    .substring(0, 10)
                                                : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF495057)),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.person_outline,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 4),
                                          Text(
                                            entrega['usuarioEntrega']
                                                    ?.toString() ??
                                                '-',
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
                                      Text('SKU: \\${entrega['SKU'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Descripción: \\${entrega['DESCRIPCION'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Cantidad: \\${entrega['CANTIDAD'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Sección: \\${entrega['SECCION'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'Jefatura: \\${entrega['JEFATURA'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF495057))),
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
                                                  color: Color(0xFF495057))),
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
                                                  color: Color(0xFF495057))),
                                        ],
                                      ),
                                      // Mostrar la firma si existe
                                      ...((entrega['firma'] != null &&
                                              entrega['firma']
                                                  .toString()
                                                  .isNotEmpty)
                                          ? [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Firma:',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                                0xFF495057))),
                                                    SizedBox(height: 6),
                                                    Image.memory(
                                                      base64Decode(
                                                          entrega['firma']),
                                                      height: 80,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const Text(
                                                              'Firma inválida',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ]
                                          : []),
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
}
