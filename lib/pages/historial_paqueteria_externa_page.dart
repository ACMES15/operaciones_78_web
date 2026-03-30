import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'editar_registro_dialog.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'dart:convert';

class HistorialPaqueteriaExternaPage extends StatefulWidget {
  final String usuario;
  final String tipoUsuarioActual;
  const HistorialPaqueteriaExternaPage(
      {Key? key, required this.usuario, required this.tipoUsuarioActual})
      : super(key: key);

  @override
  State<HistorialPaqueteriaExternaPage> createState() =>
      _HistorialPaqueteriaExternaPageState();
}

class _HistorialPaqueteriaExternaPageState
    extends State<HistorialPaqueteriaExternaPage> {
  String _busqueda = '';

  // Función para descargar Excel
  void _descargarExcel() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('paqueteria_externa')
        .orderBy('fecha', descending: true)
        .get();
    final excel = Excel.createExcel();
    final sheet = excel['PaqueteriaExterna'];
    sheet.appendRow([
      'Paquetería',
      'Guía',
      'Bultos',
      'Pedido',
      'Contrarecibo',
      'Recibió',
      'Entregó',
      'Fecha'
    ]);
    for (final doc in snapshot.docs) {
      final data = doc.data();
      String pedidosExcel = '';
      if (data['pedido'] is List) {
        pedidosExcel = (data['pedido'] as List)
            .where((p) => p != null && p.toString().trim().isNotEmpty)
            .map((p) => p.toString())
            .join('\n');
      } else {
        pedidosExcel = data['pedido']?.toString() ?? '';
      }
      sheet.appendRow([
        data['paqueteria'] ?? '',
        data['guia'] ?? '',
        data['bultos'] ?? '',
        pedidosExcel,
        data['contrarecibo'] ?? '',
        data['nombreRecibe'] ?? '',
        data['usuario'] ?? '',
        (data['fecha'] as Timestamp?)?.toDate().toString() ?? '',
      ]);
    }
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final blob = html.Blob([fileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'historial_paqueteria_externa.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.white),
            const SizedBox(width: 10),
            const Text('Historial Paquetería Externa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 4,
                    ),
                  ],
                )),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar Excel',
            onPressed: _descargarExcel,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Usuario: ${widget.usuario}  |  Tipo: ${widget.tipoUsuarioActual}',
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por cualquier campo...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) =>
                  setState(() => _busqueda = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('paqueteria_externa')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay registros.'));
                }
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (_busqueda.isEmpty) return true;
                  return data.values.any((v) =>
                      v != null &&
                      v.toString().toLowerCase().contains(_busqueda));
                }).toList();
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final fecha = (data['fecha'] as Timestamp?)?.toDate();
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  data['paqueteria'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                const Spacer(),
                                if (fecha != null)
                                  Text(
                                      DateFormat('dd/MM/yyyy HH:mm')
                                          .format(fecha),
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Guía: ${data['guia'] ?? ''}',
                                style: const TextStyle(fontSize: 16)),
                            Text('Bultos: ${data['bultos'] ?? ''}',
                                style: const TextStyle(fontSize: 16)),
                            if (data['pedido'] is List)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pedidos:',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  ...List.from(data['pedido'])
                                      .map<Widget>((p) => Text(p.toString(),
                                          style: const TextStyle(fontSize: 16)))
                                      .toList(),
                                ],
                              )
                            else
                              Text('Pedido: ${data['pedido'] ?? ''}',
                                  style: const TextStyle(fontSize: 16)),
                            Text('Contrarecibo: ${data['contrarecibo'] ?? ''}',
                                style: const TextStyle(fontSize: 16)),
                            Text('Recibió: ${data['nombreRecibe'] ?? ''}',
                                style: const TextStyle(fontSize: 16)),
                            Text('Entregó: ${data['usuario'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D6A4F))),
                            if (data['usuarioEdito'] != null &&
                                data['usuarioEdito'].toString().isNotEmpty)
                              Text('Editó: ${data['usuarioEdito']}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF6C757D))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if ([
                                  'ADMIN OMNICANAL',
                                  'ADMIN ENVIOS',
                                  'ADMIN',
                                  'STAFF ENVIOS',
                                  'STAFF XD'
                                ].contains(widget.tipoUsuarioActual))
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Editar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                          255, 242, 245, 243),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => EditarRegistroDialog(
                                          docId: doc.id,
                                          data: data,
                                          usuarioActual: widget.usuario,
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                            // Mostrar imagen de la firma si existe (Uint8List, base64 o URL)
                            if (data['firma'] != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Builder(
                                        builder: (context) {
                                          final firma = data['firma'];
                                          // Mostrar valor de la firma para depuración (truncado)
                                          // Puedes quitar este Text cuando ya no lo necesites
                                          // Si la firma es muy larga, solo muestra los primeros 60 caracteres
                                          // y el tipo de dato
                                          //
                                          // Ejemplo: "Firma (String): iVBORw0KGgoAAAANSUhEUgAA..."
                                          //
                                          // Si no quieres mostrarlo al usuario final, puedes envolverlo en un Visibility
                                          //
                                          // Mostrar imagen de la firma
                                          if (firma is Uint8List) {
                                            return Image.memory(
                                              firma,
                                              height: 80,
                                              fit: BoxFit.contain,
                                            );
                                          } else if (firma is List) {
                                            // Si es una lista dinámica, intentar convertir a List<int>
                                            try {
                                              final lista = firma.cast<int>();
                                              return Image.memory(
                                                Uint8List.fromList(lista),
                                                height: 80,
                                                fit: BoxFit.contain,
                                              );
                                            } catch (e) {
                                              return Text(
                                                  'Firma no válida (lista): ${e.toString()}');
                                            }
                                          } else if (firma is String) {
                                            if (firma.startsWith('http')) {
                                              // Es una URL
                                              return Image.network(
                                                firma,
                                                height: 80,
                                                fit: BoxFit.contain,
                                              );
                                            } else {
                                              // Intentar decodificar base64
                                              try {
                                                final bytes =
                                                    base64Decode(firma);
                                                return Image.memory(
                                                  Uint8List.fromList(bytes),
                                                  height: 80,
                                                  fit: BoxFit.contain,
                                                );
                                              } catch (e) {
                                                return Text(
                                                    'Firma no válida: ${e.toString()}');
                                              }
                                            }
                                          } else {
                                            return Text(
                                                'Firma no soportada. Tipo: ${firma.runtimeType}');
                                          }
                                        },
                                      ),
                                    ),
                                    // const SizedBox(height: 4),
                                    // Widget de depuración de firma oculto
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
