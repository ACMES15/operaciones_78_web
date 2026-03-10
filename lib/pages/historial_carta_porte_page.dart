import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final TextEditingController _busquedaController = TextEditingController();
  bool _esAdmin = false;

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

  Future<void> _eliminarCarta(
      Map<String, dynamic> carta, List<Map<String, dynamic>> merged,
      {required bool fromCollection}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar carta porte'),
        content: const Text(
            '¿Estás seguro de eliminar esta hoja de carta porte? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (fromCollection) {
        final id = carta['NUMERO_CONTROL']?.toString();
        if (id != null && id.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('historial_carta_porte')
              .doc(id)
              .delete();
        }
      } else {
        merged.removeWhere((c) => (c['NUMERO_CONTROL'] != null &&
            c['NUMERO_CONTROL'] == carta['NUMERO_CONTROL']));
        await guardarDatosFirestoreYCache(
            'historial_carta_porte', 'datos', {'datos': merged});
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Carta eliminada'), backgroundColor: Colors.green));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error eliminando: $e'), backgroundColor: Colors.red));
    }
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
    final collectionStream = FirebaseFirestore.instance
        .collection('historial_carta_porte')
        .snapshots();
    final legacyStream = FirebaseFirestore.instance
        .collection('historial_carta_porte')
        .doc('datos')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Carta Porte'),
        backgroundColor: const Color(0xFF2D6A4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar a Excel',
            onPressed: () async {
              final col = await FirebaseFirestore.instance
                  .collection('historial_carta_porte')
                  .get();
              final legacy = await FirebaseFirestore.instance
                  .collection('historial_carta_porte')
                  .doc('datos')
                  .get();
              final merged = <Map<String, dynamic>>[];
              for (final d in col.docs) merged.add(d.data());
              if (legacy.exists &&
                  legacy.data() != null &&
                  legacy.data()!['datos'] is List)
                merged.addAll(List<Map<String, dynamic>>.from(
                    legacy.data()!['datos'] as List));
              if (merged.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No hay datos para exportar')));
                return;
              }
              await exportarAExcel(merged, context);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: collectionStream,
        builder: (context, colSnap) {
          if (colSnap.hasError)
            return Center(
                child: Text('Error cargando historial: ${colSnap.error}'));
          final colList = <Map<String, dynamic>>[];
          if (colSnap.hasData)
            for (final d in colSnap.data!.docs) colList.add(d.data());
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: legacyStream,
            builder: (context, legacySnap) {
              final merged = <Map<String, dynamic>>[];
              merged.addAll(colList);
              if (legacySnap.hasData && legacySnap.data?.data() != null) {
                final ld = legacySnap.data!.data()!;
                if (ld['datos'] is List) {
                  try {
                    merged.addAll(
                        List<Map<String, dynamic>>.from(ld['datos'] as List));
                  } catch (_) {}
                }
              }
              merged.sort((a, b) {
                final an =
                    int.tryParse(a['NUMERO_CONTROL']?.toString() ?? '') ?? 0;
                final bn =
                    int.tryParse(b['NUMERO_CONTROL']?.toString() ?? '') ?? 0;
                return bn.compareTo(an);
              });

              final q = _busquedaController.text.trim();
              final filtered =
                  merged.where((c) => _coincideBusqueda(c, q)).toList();

              return Padding(
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
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('Aún no hay historial',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final carta = filtered[idx];
                                final fromCollection = colList.any((c) =>
                                    (c['NUMERO_CONTROL'] != null &&
                                        c['NUMERO_CONTROL'] ==
                                            carta['NUMERO_CONTROL']));
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
                                            if ((carta['NUMERO_CONTROL'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 10),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFB7E4C7),
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
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        carta['NUMERO_CONTROL'] ??
                                                            '',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                                Text('Fecha: ${carta['FECHA']}')
                                            ]),
                                        trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                  icon: const Icon(Icons.edit,
                                                      color: Colors.blue),
                                                  onPressed: () =>
                                                      _editarCarta(carta)),
                                              if (_esAdmin)
                                                IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red),
                                                    tooltip: 'Eliminar',
                                                    onPressed: () =>
                                                        _eliminarCarta(
                                                            carta, merged,
                                                            fromCollection:
                                                                fromCollection)),
                                              IconButton(
                                                  icon: Icon(
                                                      verDetalles
                                                          ? Icons.visibility_off
                                                          : Icons.visibility,
                                                      color: Colors.teal),
                                                  tooltip: verDetalles
                                                      ? 'Ocultar detalles'
                                                      : 'Ver detalles',
                                                  onPressed: () => setCard(() =>
                                                      verDetalles =
                                                          !verDetalles))
                                            ]),
                                      ),
                                      if (verDetalles &&
                                          carta['TABLE'] != null &&
                                          carta['TABLE'] is List &&
                                          (carta['TABLE'] as List).isNotEmpty)
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child:
                                                    Builder(builder: (context) {
                                                  final table =
                                                      carta['TABLE'] as List;
                                                  if (table.isEmpty)
                                                    return const SizedBox();
                                                  final firstRow = table.first;
                                                  List<DataColumn> columns;
                                                  if (firstRow is Map) {
                                                    columns = firstRow.keys
                                                        .map((k) => DataColumn(
                                                            label: Text(
                                                                k.toString())))
                                                        .toList();
                                                  } else if (firstRow is List &&
                                                      carta['COLUMNS']
                                                          is List) {
                                                    columns = (carta['COLUMNS']
                                                            as List)
                                                        .map<DataColumn>((k) =>
                                                            DataColumn(
                                                                label: Text(k
                                                                    .toString())))
                                                        .toList();
                                                  } else {
                                                    columns = [];
                                                  }
                                                  List<DataRow> rows =
                                                      table.map<DataRow>((row) {
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
                                });
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
