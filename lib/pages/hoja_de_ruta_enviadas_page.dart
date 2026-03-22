import 'dart:async';
import 'package:flutter/material.dart';
import 'hoja_de_ruta_extra_page.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeRutaEnviadasPage extends StatefulWidget {
  const HojaDeRutaEnviadasPage({super.key});

  @override
  State<HojaDeRutaEnviadasPage> createState() => _HojaDeRutaEnviadasPageState();
}

class _HojaDeRutaEnviadasPageState extends State<HojaDeRutaEnviadasPage> {
  void _showSheetDetail(BuildContext context, Map<String, dynamic> sheet) {
    // Alinear los datos de cada fila al orden de headers
    List<List<String>> rows = [];
    final List<String> columns =
        sheet['headers'] != null ? List<String>.from(sheet['headers']) : [];
    if (sheet['rows'] != null && sheet['rows'] is List && columns.isNotEmpty) {
      final rawRows = sheet['rows'] as List;
      for (final row in rawRows) {
        if (row is Map) {
          // Ordenar los valores según headers
          rows.add(columns.map((h) => row[h]?.toString() ?? '').toList());
        } else if (row is List) {
          rows.add(List<String>.from(row.map((e) => e.toString())));
        }
      }
    }
    final List<List<TextEditingController>> rowControllers = List.generate(
        rows.length,
        (i) => List.generate(
            rows[i].length, (j) => TextEditingController(text: rows[i][j])));

    void saveEdits(StateSetter setModalState) async {
      // Actualizar los datos en Firestore
      final newRows = rowControllers
          .map((r) => r.map((c) => c.text.trim()).toList())
          .toList();
      await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(sheet['numeroControl'])
          .update({'rows': newRows});
      Navigator.of(context).pop();
    }

    void deleteSheet(StateSetter setModalState) async {
      await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(sheet['numeroControl'])
          .delete();
      Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final double maxWidth = MediaQuery.of(context).size.width * 0.95;
          double colWidth =
              ((maxWidth - 48) / (columns.isNotEmpty ? columns.length : 1))
                  .clamp(70, 120);
          final double minTableWidth = columns.length * colWidth;

          // Build table columns and rows in variables to keep widget tree readable
          final tableColumns = List.generate(
            columns.length,
            (colIdx) => DataColumn(
              label: Container(
                alignment: Alignment.center,
                width: colWidth,
                decoration: BoxDecoration(
                  border: colIdx < columns.length - 1
                      ? const Border(
                          right: BorderSide(color: Color(0xFFE0E0E0), width: 1))
                      : null,
                ),
                child: Text(columns[colIdx],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          );

          final tableRows = List.generate(rowControllers.length, (rowIdx) {
            final rowCtrls = rowControllers[rowIdx];
            return DataRow(
              cells: List.generate(columns.length, (colIdx) {
                return DataCell(
                  Container(
                    alignment: Alignment.center,
                    width: colWidth,
                    decoration: BoxDecoration(
                      border: colIdx < columns.length - 1
                          ? const Border(
                              right: BorderSide(
                                  color: Color(0xFFE0E0E0), width: 1))
                          : null,
                    ),
                    child: HojaDeRutaExtraPage.isAdmin
                        ? TextField(
                            controller: rowCtrls[colIdx],
                            enabled: true,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 4)),
                            style: const TextStyle(fontSize: 13),
                          )
                        : Text(
                            rowCtrls[colIdx].text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                );
              }),
            );
          });

          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.95),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ORIGEN',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(sheet['origen'] ?? '',
                                      style: const TextStyle(fontSize: 15)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Text('No. de Caja:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                          width: 80,
                                          child: Text(sheet['caja'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 15))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Fecha de Envío:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Text(sheet['fecha'] ?? '')
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Núm. de control:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      if ((sheet['numeroControl'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(sheet['numeroControl'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tipo de hoja:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 8),
                                  Text(sheet['tipo'] ?? '',
                                      style: const TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minWidth: minTableWidth),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Card(
                                elevation: 1,
                                margin: const EdgeInsets.all(0),
                                child: DataTable(
                                  columnSpacing: 2,
                                  dataRowMinHeight: 28,
                                  dataRowMaxHeight: 32,
                                  headingRowHeight: 34,
                                  columns: tableColumns,
                                  rows: tableRows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (HojaDeRutaExtraPage.isAdmin) ...[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar cambios'),
                            onPressed: () => saveEdits(setModalState),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: const Text('Eliminar'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () => deleteSheet(setModalState),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Imprimir'),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _printSheet(context, sheet);
                          },
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _forzarRecarga() async {
    await invalidateCache('hoja_ruta', 'sentHojaRutas');
    setState(() {}); // Forzar rebuild para que FutureBuilder recargue
  }

  Future<void> _printSheet(
      BuildContext context, Map<String, dynamic> sheet) async {
    try {
      // ...lógica de impresión original aquí...
      // Si es web, abrir ventana, etc.
    } catch (e) {
      // Manejo de error opcional
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    // 1. Cargar primero del caché local
    return FutureBuilder<Map<String, dynamic>?>(
      future: leerDatosConCache('hoja_ruta', 'sentHojaRutas'),
      builder: (context, cacheSnapshot) {
        List<Map<String, dynamic>> sent = [];
        if (cacheSnapshot.hasData &&
            cacheSnapshot.data != null &&
            cacheSnapshot.data!['items'] != null) {
          sent = List<Map<String, dynamic>>.from(
              (cacheSnapshot.data!['items'] as List)
                  .map((e) => Map<String, dynamic>.from(e)));
        }
        debugPrint('Hojas de ruta enviadas (sent):\n' + sent.toString());
        List<Map<String, dynamic>> filtered = List.from(sent);

        // 2. Luego, actualizar con Firestore y refrescar caché si hay cambios
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hoja_ruta')
              .doc('sentHojaRutas')
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            if (snapshot.hasData && data != null && data['items'] != null) {
              final firestoreSent = List<Map<String, dynamic>>.from(
                  (data['items'] as List)
                      .map((e) => Map<String, dynamic>.from(e)));
              debugPrint('Firestore hojas de ruta (firestoreSent):\n' +
                  firestoreSent.toString());
              // Si hay diferencia, actualizar caché y la lista
              if (firestoreSent.length != sent.length ||
                  firestoreSent.toString() != sent.toString()) {
                guardarDatosFirestoreYCache(
                    'hoja_ruta', 'sentHojaRutas', {'items': firestoreSent});
                sent = firestoreSent;
                filtered = List.from(sent);
              }
            }

            return StatefulBuilder(
              builder: (context, setModalState) {
                void filterSheets(String query) {
                  final q = query.toLowerCase();
                  filtered = sent.where((sheet) {
                    bool match = (sheet['numeroControl']
                                ?.toString()
                                .toLowerCase()
                                .contains(q) ??
                            false) ||
                        (sheet['origen']
                                ?.toString()
                                .toLowerCase()
                                .contains(q) ??
                            false) ||
                        (sheet['tipo']?.toString().toLowerCase().contains(q) ??
                            false) ||
                        (sheet['caja']?.toString().toLowerCase().contains(q) ??
                            false) ||
                        (sheet['fecha']?.toString().toLowerCase().contains(q) ??
                            false);
                    if (!match && sheet['rows'] != null) {
                      for (final row in (sheet['rows'] as List)) {
                        for (final cell in (row is Map ? row.values : row)) {
                          if (cell.toString().toLowerCase().contains(q)) {
                            match = true;
                            break;
                          }
                        }
                        if (match) break;
                      }
                    }
                    return match;
                  }).toList();
                  setModalState(() {});
                }

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Hoja de ruta enviadas'),
                    backgroundColor: const Color.fromARGB(184, 69, 70, 69),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Forzar recarga',
                        onPressed: _forzarRecarga,
                      ),
                    ],
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                              labelText: 'Buscar hoja de ruta',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder()),
                          onChanged: filterSheets,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text('No hay hojas de ruta enviadas'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, idx) {
                                    final sheet = filtered[idx];
                                    return Card(
                                      child: ListTile(
                                        title:
                                            Text('Hoja: ${sheet['createdAt']}'),
                                        subtitle: Text(
                                            'Fecha: ${sheet['fecha']}  •  No. Control: ${sheet['numeroControl']}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.print),
                                              onPressed: () async {
                                                try {
                                                  await _printSheet(
                                                      context, sheet);
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              'Error al imprimir: $e')));
                                                }
                                              },
                                            ),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.visibility),
                                                onPressed: () =>
                                                    _showSheetDetail(
                                                        context, sheet)),
                                            if (HojaDeRutaExtraPage.isAdmin)
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                tooltip: 'Eliminar',
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Eliminar hoja de ruta'),
                                                      content: const Text(
                                                          '¿Estás seguro de eliminar esta hoja de ruta? Esta acción no se puede deshacer.'),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        ctx)
                                                                    .pop(false),
                                                            child: const Text(
                                                                'Cancelar')),
                                                        ElevatedButton(
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red),
                                                          onPressed: () =>
                                                              Navigator.of(ctx)
                                                                  .pop(true),
                                                          child: const Text(
                                                              'Eliminar'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm != true) return;

                                                  // Optimistic delete with undo
                                                  final removed =
                                                      HojaDeRutaExtraPage
                                                          .sentHojaRutas
                                                          .where((s) {
                                                    try {
                                                      return s['createdAt'] ==
                                                              sheet[
                                                                  'createdAt'] &&
                                                          s['numeroControl'] ==
                                                              sheet[
                                                                  'numeroControl'];
                                                    } catch (_) {
                                                      return false;
                                                    }
                                                  }).toList();

                                                  HojaDeRutaExtraPage
                                                      .sentHojaRutas
                                                      .removeWhere((s) {
                                                    try {
                                                      return s['createdAt'] ==
                                                              sheet[
                                                                  'createdAt'] &&
                                                          s['numeroControl'] ==
                                                              sheet[
                                                                  'numeroControl'];
                                                    } catch (_) {
                                                      return false;
                                                    }
                                                  });

                                                  setModalState(() {});

                                                  bool undone = false;
                                                  late final Timer commitTimer;
                                                  commitTimer = Timer(
                                                      const Duration(
                                                          seconds: 5),
                                                      () async {
                                                    if (undone) return;
                                                    try {
                                                      await guardarDatosFirestoreYCache(
                                                          'hoja_ruta',
                                                          'sentHojaRutas', {
                                                        'items':
                                                            HojaDeRutaExtraPage
                                                                .sentHojaRutas
                                                      });
                                                      try {
                                                        await invalidateCache(
                                                            'hoja_ruta',
                                                            'sentHojaRutas');
                                                      } catch (_) {}
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  'Error eliminando: $e')));
                                                    }
                                                  });

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: const Text(
                                                          'Hoja de ruta eliminada'),
                                                      action: SnackBarAction(
                                                        label: 'Deshacer',
                                                        onPressed: () async {
                                                          undone = true;
                                                          if (commitTimer
                                                              .isActive)
                                                            commitTimer
                                                                .cancel();
                                                          try {
                                                            HojaDeRutaExtraPage
                                                                .sentHojaRutas
                                                                .addAll(
                                                                    removed);
                                                            setModalState(
                                                                () {});
                                                            await guardarDatosFirestoreYCache(
                                                                'hoja_ruta',
                                                                'sentHojaRutas',
                                                                {
                                                                  'items':
                                                                      HojaDeRutaExtraPage
                                                                          .sentHojaRutas
                                                                });
                                                            try {
                                                              await invalidateCache(
                                                                  'hoja_ruta',
                                                                  'sentHojaRutas');
                                                            } catch (_) {}
                                                          } catch (e) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                                    SnackBar(
                                                                        content:
                                                                            Text('Error deshaciendo: $e')));
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  );
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
              },
            );
          },
        );
      },
    );
  }
}
