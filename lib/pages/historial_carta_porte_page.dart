import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'carta_porte_edicion_completa_page.dart';
import '../utils/exportar_excel.dart';
import '../utils/firebase_cache_utils.dart';

class HistorialCartaPortePage extends StatefulWidget {
  const HistorialCartaPortePage({Key? key}) : super(key: key);

  @override
  State<HistorialCartaPortePage> createState() =>
      _HistorialCartaPortePageState();
}

class _HistorialCartaPortePageState extends State<HistorialCartaPortePage> {
  // Limpia recursivamente los datos no serializables (ej. Timestamp, FieldValue)
  dynamic _toEncodable(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _toEncodable(v)));
    }
    if (value is List) {
      return value.map(_toEncodable).toList();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value.runtimeType.toString() == 'Timestamp') {
      // Firestore Timestamp
      return value.toDate().toIso8601String();
    }
    if (value.runtimeType.toString().contains('FieldValue')) {
      // No serializar FieldValue
      return null;
    }
    // Manejo genérico para tipos desconocidos (como minifield:oG)
    if (value.runtimeType.toString().startsWith('minifield:')) {
      return value.toString();
    }
    return value;
  }

  final TextEditingController _busquedaController = TextEditingController();
  // bool _esAdmin = false; // Eliminado porque no se usa
  List<Map<String, dynamic>> _cartasCache = [];
  bool _cargando = true;
  bool _error = false;
  String? _errorMsg;
  @override
  void initState() {
    super.initState();
    _cargarCartas();
  }

  Future<void> _cargarCartas({bool forzarFirestore = false}) async {
    setState(() {
      _cargando = true;
      _error = false;
      _errorMsg = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'cartas_porte_cache';
      if (!forzarFirestore && prefs.containsKey(cacheKey)) {
        final cacheData = prefs.getString(cacheKey);
        if (cacheData != null) {
          final decoded = (jsonDecode(cacheData) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cartasCache = decoded;
          setState(() {
            _cargando = false;
          });
          return;
        }
      }
      // Si no hay cache o se fuerza, consulta Firestore
      final snap = await FirebaseFirestore.instance
          .collection('cartas_porte')
          .orderBy('numero_control', descending: true)
          .get();
      _cartasCache = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return Map<String, dynamic>.from(_toEncodable(data) as Map);
      }).toList();
      await prefs.setString(cacheKey, jsonEncode(_cartasCache));
      setState(() {
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _cargando = false;
      });
    }
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  bool _coincideBusqueda(Map<String, dynamic> carta, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    for (final v in carta.values) {
      try {
        if (v != null && v.toString().toLowerCase().contains(lower))
          return true;
      } catch (_) {}
    }
    return false;
  }

  void _editarCarta(Map<String, dynamic> carta) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CartaPorteEdicionCompletaPage(
        carta: carta,
        onGuardar: (updated) async {
          final id = updated['NUMERO_CONTROL']?.toString();
          try {
            if (id != null && id.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('historial_carta_porte')
                  .doc(id)
                  .set(updated, SetOptions(merge: true));
            } else {
              final legacy =
                  await leerDatosConCache('historial_carta_porte', 'datos');
              List datos = [];
              if (legacy != null && legacy['datos'] is List)
                datos = List.from(legacy['datos']);
              datos.add(updated);
              await guardarDatosFirestoreYCache(
                  'historial_carta_porte', 'datos', {'datos': datos});
            }
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Carta guardada')));
          } catch (e) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error guardando: $e')));
          }
          setState(() {});
          Navigator.of(context).pop();
        },
      ),
    ));
  }

  // Provide a simple implementation for exportarAExcel so the call in the UI compiles.
  // Replace this with a proper export implementation or call to your utilities if available.
  Future<void> exportarAExcel(
      List<Map<String, dynamic>> merged, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportación no implementada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Carta Porte'),
        backgroundColor: const Color(0xFF2D6A4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar desde Firestore',
            onPressed: () async {
              await _cargarCartas(forzarFirestore: true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Historial actualizado desde Firestore')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar a Excel',
            onPressed: () async {
              if (_cartasCache.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No hay datos para exportar')));
                return;
              }
              await exportarAExcel(_cartasCache, context);
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: Text('Error cargando historial: \n${_errorMsg ?? ''}'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Historial',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                  color: Color(0xFF2D6A4F))),
                          const Spacer(),
                          SizedBox(
                              width: 350,
                              child: TextField(
                                  controller: _busquedaController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      labelText: 'Buscar en todos los campos',
                                      border: OutlineInputBorder(),
                                      isDense: true))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final q = _busquedaController.text.trim();
                            final filtered = _cartasCache
                                .where((c) => _coincideBusqueda(c, q))
                                .toList();
                            if (filtered.isEmpty) {
                              return Center(
                                  child: Text('Aún no hay historial',
                                      style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500)));
                            }
                            return ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final carta = filtered[idx];
                                bool verDetalles = false;
                                return StatefulBuilder(
                                  builder: (context, setCard) {
                                    return Card(
                                      color: const Color(0xFFF5F6FA),
                                      child: Column(children: [
                                        ListTile(
                                          title: Row(
                                            children: [
                                              Text(
                                                  'Destino: ${carta['DESTINO'] ?? '-'}'),
                                              if ((carta['NUMERO_CONTROL'] ??
                                                      '')
                                                  .toString()
                                                  .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 10),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFB7E4C7),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFF2D6A4F)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .confirmation_number,
                                                            size: 14,
                                                            color: Color(
                                                                0xFF2D6A4F)),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          carta['NUMERO_CONTROL'] ??
                                                              '',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Color(
                                                                  0xFF2D6A4F),
                                                              fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'Chofer: ${carta['CHOFER'] ?? '-'}'),
                                                Text(
                                                    'Unidad: ${carta['UNIDAD'] ?? '-'}'),
                                                Text(
                                                    'RFC: ${carta['RFC'] ?? '-'}'),
                                                Text(
                                                    'Concentrado: ${carta['CONCENTRADO'] ?? '-'}'),
                                                if (carta['FECHA'] != null)
                                                  Text(
                                                      'Fecha: ${carta['FECHA']}')
                                              ]),
                                          trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                    icon: const Icon(Icons.edit,
                                                        color: Colors.blue),
                                                    onPressed: () =>
                                                        _editarCarta(carta)),
                                                IconButton(
                                                    icon: Icon(
                                                        verDetalles
                                                            ? Icons
                                                                .visibility_off
                                                            : Icons.visibility,
                                                        color: Colors.teal),
                                                    tooltip: verDetalles
                                                        ? 'Ocultar detalles'
                                                        : 'Ver detalles',
                                                    onPressed: () => setCard(
                                                        () => verDetalles =
                                                            !verDetalles))
                                              ]),
                                        ),
                                        if (verDetalles &&
                                            carta['TABLE'] != null &&
                                            carta['TABLE'] is List &&
                                            (carta['TABLE'] as List).isNotEmpty)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Builder(
                                                      builder: (context) {
                                                    final table =
                                                        carta['TABLE'] as List;
                                                    if (table.isEmpty)
                                                      return const SizedBox();
                                                    final firstRow =
                                                        table.first;
                                                    List<DataColumn> columns;
                                                    if (firstRow is Map) {
                                                      columns = firstRow.keys
                                                          .map((k) => DataColumn(
                                                              label: Text(k
                                                                  .toString())))
                                                          .toList();
                                                    } else if (firstRow
                                                            is List &&
                                                        carta['COLUMNS']
                                                            is List) {
                                                      columns = (carta[
                                                                  'COLUMNS']
                                                              as List)
                                                          .map<DataColumn>(
                                                              (k) => DataColumn(
                                                                  label: Text(k
                                                                      .toString())))
                                                          .toList();
                                                    } else {
                                                      columns = [];
                                                    }
                                                    List<DataRow> rows = table
                                                        .map<DataRow>((row) {
                                                      if (row is Map)
                                                        return DataRow(
                                                            cells: row.values
                                                                .map((v) =>
                                                                    DataCell(Text(
                                                                        v?.toString() ??
                                                                            '')))
                                                                .toList());
                                                      if (row is List)
                                                        return DataRow(
                                                            cells: row
                                                                .map((v) =>
                                                                    DataCell(Text(
                                                                        v?.toString() ??
                                                                            '')))
                                                                .toList());
                                                      return const DataRow(
                                                          cells: []);
                                                    }).toList();
                                                    return DataTable(
                                                        columns: columns,
                                                        rows: rows);
                                                  }))),
                                      ]),
                                    );
                                  },
                                );
                              },
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
