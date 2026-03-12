import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/firebase_cache_utils.dart';
import '../models/hoja_de_xd_historial.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeXDHistorialPage extends StatefulWidget {
  const HojaDeXDHistorialPage({super.key});

  // Local admin flag; adjust as needed or replace with real auth check.
  static bool isAdmin = false;

  @override
  State<HojaDeXDHistorialPage> createState() => _HojaDeXDHistorialPageState();
}

class _HojaDeXDHistorialPageState extends State<HojaDeXDHistorialPage> {
  List<HojaDeXDHistorial> historial = [];
  String filtro = '';

  Future<void> _saveHistorialToFirestore() async {
    // Guardar solo como documentos individuales, no en 'main'

    // NUEVO: Guardar cada historial como documento individual
    for (final h in historial) {
      final docId = '${h.fecha.toIso8601String()}_${h.usuario}_${h.fileName}'
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .doc(docId)
          .set(h.toJson());
    }
  }

  Future<void> _exportarExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['HistorialXD'];
    final headers = ['Usuario', 'Fecha', 'Archivo', ..._getAllKeys()];
    sheet.appendRow(headers);
    for (final h in historial) {
      final row = [h.usuario, h.fecha.toString(), h.fileName];
      for (final k in headers.skip(3)) {
        row.add(h.datos[k] ?? '');
      }
      sheet.appendRow(row);
    }
    final fileBytes = excel.encode()!;
    final blob = html.Blob([fileBytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'historial_hoja_xd.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  List<String> _getAllKeys() {
    final keys = <String>{};
    for (final h in historial) keys.addAll(h.datos.keys);
    final list = keys.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .snapshots(),
      builder: (context, snapshot) {
        List<HojaDeXDHistorial> lista = [];
        if (snapshot.hasData && snapshot.data != null) {
          final docs = snapshot.data!.docs;
          lista = docs
              .map((doc) => HojaDeXDHistorial.fromJson(doc.data()))
              .toList();
        }
        historial = lista;
        final filtroLower = filtro.toLowerCase();
        final historialFiltrado = filtro.isEmpty
            ? historial
            : historial.where((h) {
                return h.usuario.toLowerCase().contains(filtroLower) ||
                    h.datos.values
                        .any((v) => v.toLowerCase().contains(filtroLower));
              }).toList();

        return Scaffold(
          appBar: AppBar(
              backgroundColor: const Color(0xFF2D6A4F),
              elevation: 0,
              toolbarHeight: 0),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.assignment,
                        color: Color(0xFF2D6A4F), size: 32),
                    const SizedBox(width: 10),
                    const Text('Historial Hoja de XD',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            color: Color(0xFF2D6A4F),
                            letterSpacing: 0.5)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.table_view),
                        tooltip: 'Exportar a Excel',
                        onPressed: _exportarExcel),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: const InputDecoration(
                      labelText:
                          'Buscar por usuario, contenedor, TU, destino, SKU, fecha',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => filtro = v.trim()),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: historialFiltrado.length,
                  itemBuilder: (context, i) {
                    final h = historialFiltrado[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      child: ListTile(
                        title: Text('Usuario: ${h.usuario}'),
                        subtitle: Text('Fecha: ${h.fecha}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(h.fileName),
                            const SizedBox(width: 8),
                            if (HojaDeXDHistorialPage.isAdmin)
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Eliminar registro',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Eliminar registro'),
                                      content: const Text(
                                          '¿Estás seguro de eliminar este registro del historial? Esta acción no se puede deshacer.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Cancelar')),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red),
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('Eliminar')),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;

                                  try {
                                    final removed = historial
                                        .where((x) =>
                                            x.fecha == h.fecha &&
                                            x.usuario == h.usuario &&
                                            x.fileName == h.fileName)
                                        .toList();
                                    historial.removeWhere((x) =>
                                        x.fecha == h.fecha &&
                                        x.usuario == h.usuario &&
                                        x.fileName == h.fileName);
                                    setState(() {});

                                    bool undone = false;
                                    late final Timer commitTimer;
                                    commitTimer = Timer(
                                        const Duration(seconds: 5), () async {
                                      if (undone) return;
                                      try {
                                        await _saveHistorialToFirestore();
                                        try {
                                          await invalidateCache(
                                              'hoja_de_xd_historial', 'main');
                                        } catch (_) {}
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Error eliminando: $e')));
                                      }
                                    });

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: const Text('Registro eliminado'),
                                      action: SnackBarAction(
                                          label: 'Deshacer',
                                          onPressed: () async {
                                            undone = true;
                                            if (commitTimer.isActive)
                                              commitTimer.cancel();
                                            try {
                                              historial.addAll(removed);
                                              setState(() {});
                                              await _saveHistorialToFirestore();
                                              try {
                                                await invalidateCache(
                                                    'hoja_de_xd_historial',
                                                    'main');
                                              } catch (_) {}
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          'Error deshaciendo: $e')));
                                            }
                                          }),
                                    ));
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Error eliminando: $e')));
                                  }
                                },
                              ),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Detalle de registro'),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Usuario: ${h.usuario}'),
                                    Text('Fecha: ${h.fecha}'),
                                    Text('Archivo: ${h.fileName}'),
                                    const SizedBox(height: 12),
                                    ...h.datos.entries.map(
                                        (e) => Text('${e.key}: ${e.value}')),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cerrar')),
                                if (HojaDeXDHistorialPage.isAdmin)
                                  ElevatedButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Eliminar'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red),
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                        'Eliminar registro'),
                                                    content: const Text(
                                                        '¿Eliminar este registro del historial?'),
                                                    actions: [
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(ctx)
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
                                                              'Eliminar'))
                                                    ]));
                                        if (confirm != true) return;
                                        try {
                                          historial.removeWhere((x) =>
                                              x.fecha == h.fecha &&
                                              x.usuario == h.usuario &&
                                              x.fileName == h.fileName);
                                          await _saveHistorialToFirestore();
                                          try {
                                            await invalidateCache(
                                                'hoja_de_xd_historial', 'main');
                                          } catch (_) {}
                                          if (mounted) setState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Registro eliminado')));
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Error eliminando: $e')));
                                        }
                                      }),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
