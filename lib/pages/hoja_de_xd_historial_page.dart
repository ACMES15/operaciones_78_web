import 'package:flutter/material.dart';
import '../utils/firebase_cache_utils.dart';
import '../models/hoja_de_xd_historial.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeXDHistorialPage extends StatefulWidget {
  const HojaDeXDHistorialPage({super.key});

  @override
  State<HojaDeXDHistorialPage> createState() => _HojaDeXDHistorialPageState();
}

class _HojaDeXDHistorialPageState extends State<HojaDeXDHistorialPage> {
  /// Guarda el historial completo en Firestore y cache
  /// (Esta función puede ser llamada desde otras páginas al agregar registros)
  // ignore: unused_element
  Future<void> _guardarHistorial() async {
    final data = {
      'historial': historial.map((e) => e.toJson()).toList(),
    };
    await guardarDatosFirestoreYCache('hoja_de_xd_historial', 'main', data);
  }

  Future<void> _exportarExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['HistorialXD'];
    // Encabezados
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
    for (final h in historial) {
      keys.addAll(h.datos.keys);
    }
    final list = keys.toList();
    list.sort();
    return list;
  }

  List<HojaDeXDHistorial> historial = [];
  String filtro = '';

  // Ya no se usa initState ni _cargarHistorial, todo será reactivo con StreamBuilder

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .doc('main')
          .snapshots(),
      builder: (context, snapshot) {
        List<HojaDeXDHistorial> historial = [];
        final data = snapshot.data?.data();
        if (snapshot.hasData && data != null && data['historial'] != null) {
          final List<dynamic> list = data['historial'];
          historial = list.map((e) => HojaDeXDHistorial.fromJson(e)).toList();
        }
        // Mantener copia en el estado para que otras funciones (exportar) la usen
        this.historial = historial;
        final filtroLower = filtro.toLowerCase();
        final historialFiltrado = filtro.isEmpty
            ? historial
            : historial.where((h) {
                return h.usuario.toLowerCase().contains(filtroLower) ||
                    h.datos['CONTENEDOR O TARIMA']
                            ?.toLowerCase()
                            .contains(filtroLower) ==
                        true ||
                    h.datos['DESTINO']?.toLowerCase().contains(filtroLower) ==
                        true ||
                    h.datos['SKU']?.toLowerCase().contains(filtroLower) ==
                        true ||
                    h.datos['FECHA']?.toLowerCase().contains(filtroLower) ==
                        true ||
                    h.datos['TU']?.toLowerCase().contains(filtroLower) == true;
              }).toList();
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF2D6A4F),
            elevation: 0,
            toolbarHeight: 0,
          ),
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
                    const Text(
                      'Historial Hoja de XD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: Color(0xFF2D6A4F),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: const Icon(Icons.table_view),
                      tooltip: 'Exportar a Excel',
                      onPressed: _exportarExcel,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText:
                        'Buscar por usuario, contenedor, TU, destino, SKU, fecha',
                    prefixIcon: Icon(Icons.search),
                  ),
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
                        trailing: Text(h.fileName),
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
                                  child: const Text('Cerrar'),
                                ),
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
