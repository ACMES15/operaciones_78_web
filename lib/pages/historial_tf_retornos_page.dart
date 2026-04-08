import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/historial_tf_retornos.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'dart:html' as html;

class HistorialTfRetornosPage extends StatefulWidget {
  final String usuario;
  const HistorialTfRetornosPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<HistorialTfRetornosPage> createState() =>
      _HistorialTfRetornosPageState();
}

class _HistorialTfRetornosPageState extends State<HistorialTfRetornosPage> {
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

  Future<void> _exportarAExcel() async {
    // Usar package:excel y dart:html para exportar
    // Solo exportar los registros actualmente filtrados
    final resultados = _filtro.isEmpty
        ? List.generate(_items.length, (i) => MapEntry(_items[i], _rawItems[i]))
        : List.generate(_items.length, (i) => MapEntry(_items[i], _rawItems[i]))
            .where((pair) {
            final e = pair.key;
            final raw = pair.value;
            // Buscar por TF O DEV en todos los posibles nombres
            final tfOdevRaw = (raw['TF O DEV']?.toString().toLowerCase() ?? '');
            return e.tfOdev.toLowerCase().contains(_filtro) ||
                tfOdevRaw.contains(_filtro) ||
                e.origen.toLowerCase().contains(_filtro) ||
                (raw['SECCION']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['JEFATURA']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['nombreRecibe']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['VALIDO']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['ENTREGO']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (e.valido.toLowerCase().contains(_filtro)) ||
                (e.entrego.toLowerCase().contains(_filtro)) ||
                (e.observaciones?.toLowerCase().contains(_filtro) ?? false);
          }).toList();

    if (resultados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }
    // Usar package:excel
    final excel = Excel.createExcel();
    final sheet = excel['Historial TF Retornos'];
    // Encabezados
    final headers = [
      'ID',
      'TF O DEV',
      'ORIGEN',
      'DESTINO',
      'SECCION',
      'JEFATURA',
      'RETORNO',
      'usuarioValido'
    ];
    sheet.appendRow(headers);
    for (final pair in resultados) {
      final e = pair.key;
      final raw = pair.value;
      // Asegurar que el campo TF O DEV exporte el valor correcto
      sheet.appendRow([
        e.id,
        raw['TF O DEV'] ?? e.tfOdev,
        e.origen,
        raw['DESTINO'] ?? '',
        raw['SECCION'] ?? '',
        raw['JEFATURA'] ?? '',
        raw['RETORNO'] ?? '',
        raw['usuarioValido'] ?? '',
      ]);
    }
    final bytes = excel.encode()!;
    final blob = html.Blob([Uint8List.fromList(bytes)],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'historial_tf_retornos.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  List<HistorialTfRetorno> _items = [];
  List<Map<String, dynamic>> _rawItems = [];
  bool _cargando = true;
  String _filtro = '';
  late TextEditingController _busquedaController;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarItems();
  }

  Future<void> _cargarItems() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore
          .collection('historial_entregas')
          .doc('transferencias_retornos_firmadas')
          .get();
      final data = doc.exists ? doc.data() : null;
      List<HistorialTfRetorno> nuevos = [];
      List<Map<String, dynamic>> rawNuevos = [];
      if (data != null && data['items'] is List) {
        for (var e in (data['items'] as List)) {
          if (e is Map) {
            final map = Map<String, dynamic>.from(
                e.map((k, v) => MapEntry(k.toString(), v)));
            nuevos.add(
                HistorialTfRetorno.fromMap(map, map['id']?.toString() ?? ''));
            rawNuevos.add(map);
          }
        }
      }
      setState(() {
        _items = nuevos;
        _rawItems = rawNuevos;
        _cargando = false;
        _errorCarga = null;
      });
    } catch (e) {
      setState(() {
        _items = [];
        _rawItems = [];
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
        ? List.generate(_items.length, (i) => MapEntry(_items[i], _rawItems[i]))
        : List.generate(_items.length, (i) => MapEntry(_items[i], _rawItems[i]))
            .where((pair) {
            final e = pair.key;
            final raw = pair.value;
            return e.tfOdev.toLowerCase().contains(_filtro) ||
                e.origen.toLowerCase().contains(_filtro) ||
                (raw['SECCION']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['JEFATURA']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['nombreRecibe']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['VALIDO']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (raw['ENTREGO']?.toString().toLowerCase() ?? '')
                    .contains(_filtro) ||
                (e.valido.toLowerCase().contains(_filtro)) ||
                (e.entrego.toLowerCase().contains(_filtro)) ||
                (e.observaciones?.toLowerCase().contains(_filtro) ?? false);
          }).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF2D6A4F), size: 30),
            const SizedBox(width: 10),
            const Text(
              'Historial TF o Retornos',
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
            tooltip: 'Exportar a Excel',
            onPressed: _exportarAExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2D6A4F)),
            onPressed: _cargarItems,
            tooltip: 'Actualizar desde Firestore',
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
                          ? const Center(child: Text('No hay registros.'))
                          : ListView.separated(
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemCount: resultados.length,
                              itemBuilder: (context, index) {
                                final item = resultados[index].key;
                                final raw = resultados[index].value;
                                Uint8List? firmaBytes;
                                if (raw['firma'] != null &&
                                    raw['firma'] is String &&
                                    raw['firma'].isNotEmpty) {
                                  try {
                                    firmaBytes = Uint8List.fromList(
                                        base64Decode(raw['firma']));
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
                                                  Icons.swap_horiz,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(height: 10),
                                            if (firmaBytes != null &&
                                                firmaBytes.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.memory(
                                                    firmaBytes,
                                                    width: 70,
                                                    height: 40,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                            if (item.retorno)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text('RETORNO',
                                                    style: TextStyle(
                                                        color: Colors.orange,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
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
                                                  Text('TF o DEV: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .grey[700])),
                                                  Text(
                                                    raw['TF O DEV']
                                                            ?.toString() ??
                                                        raw['TF O DEV ']
                                                            ?.toString() ??
                                                        raw['TRANSFERENCIA']
                                                            ?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                  ),
                                                  const SizedBox(width: 18),
                                                  Text('Origen: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .grey[700])),
                                                  Text(
                                                    raw['ORIGEN']?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                  ),
                                                  const SizedBox(width: 18),
                                                  Text('Sección: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .grey[700])),
                                                  Text(
                                                    raw['SECCION']
                                                            ?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                  ),
                                                  const SizedBox(width: 18),
                                                  Text('Jefatura: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .grey[700])),
                                                  Text(
                                                    raw['JEFATURA']
                                                            ?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color:
                                                            Color(0xFF2D6A4F)),
                                                  ),
                                                  const SizedBox(width: 18),
                                                  if (raw['RETORNO'] == true ||
                                                      raw['RETORNO'] == 'true')
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .orange.shade100,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: const Text(
                                                          'RETORNO',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.orange,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                  const Spacer(),
                                                  if (item.fecha != null)
                                                    Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .calendar_today,
                                                            size: 18,
                                                            color: Colors
                                                                .grey[600]),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          item.fecha != null
                                                              ? _formatearFecha(
                                                                  item.fecha)
                                                              : 'null',
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              color: Color(
                                                                  0xFF495057)),
                                                        ),
                                                      ],
                                                    ),

// Agregar función de formateo
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.person,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 6),
                                                  Text('Recibió: ',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                              0xFF2D6A4F))),
                                                  Text(
                                                      raw['nombreRecibe']
                                                              ?.toString() ??
                                                          '-',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.verified_user,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 6),
                                                  Text('Validó: ',
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          color: Color(
                                                              0xFF495057))),
                                                  Text(
                                                      raw['usuarioValido']
                                                              ?.toString() ??
                                                          raw['VALIDO']
                                                              ?.toString() ??
                                                          '-',
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          color: Color(
                                                              0xFF495057))),
                                                  const SizedBox(width: 16),
                                                  const Icon(
                                                      Icons.person_outline,
                                                      size: 18,
                                                      color: Color(0xFF2D6A4F)),
                                                  const SizedBox(width: 6),
                                                  Text('Entregó: ',
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          color: Color(
                                                              0xFF495057))),
                                                  Text(
                                                    raw['usuarioEntrega']
                                                            ?.toString() ??
                                                        raw['ENTREGO']
                                                            ?.toString() ??
                                                        raw['usuario']
                                                            ?.toString() ??
                                                        '-',
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        color:
                                                            Color(0xFF495057)),
                                                  ),
                                                ],
                                              ),
                                              if (item.observaciones != null &&
                                                  item.observaciones!
                                                      .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8.0),
                                                  child: Text(
                                                      'Obs: ${item.observaciones}',
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey)),
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
}
