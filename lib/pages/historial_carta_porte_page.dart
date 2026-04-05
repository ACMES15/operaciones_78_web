import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/exportar_excel.dart';
import 'carta_porte_edicion_page.dart';

class HistorialCartaPortePage extends StatefulWidget {
  const HistorialCartaPortePage({Key? key}) : super(key: key);

  @override
  State<HistorialCartaPortePage> createState() =>
      _HistorialCartaPortePageState();
}

class _HistorialCartaPortePageState extends State<HistorialCartaPortePage> {
  Future<void> _editarCartaDialog(Map<String, dynamic> carta) async {
    final manifiestoController = TextEditingController(
        text: carta['MANIFIESTO'] ?? carta['manifiesto'] ?? '');
    final destinoController =
        TextEditingController(text: carta['DESTINO'] ?? carta['destino'] ?? '');
    final fechaController =
        TextEditingController(text: carta['FECHA'] ?? carta['fecha'] ?? '');
    final nombreController =
        TextEditingController(text: carta['NOMBRE'] ?? carta['nombre'] ?? '');
    final usuarioController =
        TextEditingController(text: carta['USUARIO'] ?? carta['usuario'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Carta Porte'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: manifiestoController,
                  decoration: const InputDecoration(labelText: 'Manifiesto'),
                ),
                TextField(
                  controller: destinoController,
                  decoration: const InputDecoration(labelText: 'Destino'),
                ),
                TextField(
                  controller: fechaController,
                  decoration: const InputDecoration(labelText: 'Fecha'),
                ),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: usuarioController,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final docId = carta['id'];
                if (docId != null) {
                  await FirebaseFirestore.instance
                      .collection('cartas_porte')
                      .doc(docId)
                      .update({
                    'MANIFIESTO': manifiestoController.text,
                    'DESTINO': destinoController.text,
                    'FECHA': fechaController.text,
                    'NOMBRE': nombreController.text,
                    'USUARIO': usuarioController.text,
                  });
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Carta porte actualizada')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  final TextEditingController _busquedaController = TextEditingController();
  final TextEditingController _escaneoController = TextEditingController();

  Future<Map<String, dynamic>?> _buscarDatosExternos(String codigo) async {
    // Buscar en hoja de ruta enviada
    final rutaSnap = await FirebaseFirestore.instance
        .collection('hoja_de_ruta_enviada')
        .where('MANIFIESTO', isEqualTo: codigo)
        .limit(1)
        .get();
    if (rutaSnap.docs.isNotEmpty) {
      final data = rutaSnap.docs.first.data();
      return {
        'MANIFIESTO': data['MANIFIESTO'] ?? '',
        'DESTINO': data['DESTINO'] ?? '',
        'FECHA': data['FECHA'] ?? '',
        'NOMBRE': data['NOMBRE'] ?? '',
        'USUARIO': data['USUARIO'] ?? '',
      };
    }
    // Buscar en hoja de XD
    final xdSnap = await FirebaseFirestore.instance
        .collection('hoja_de_xd_historial')
        .where('MANIFIESTO', isEqualTo: codigo)
        .limit(1)
        .get();
    if (xdSnap.docs.isNotEmpty) {
      final data = xdSnap.docs.first.data();
      return {
        'MANIFIESTO': data['MANIFIESTO'] ?? '',
        'DESTINO': data['DESTINO'] ?? '',
        'FECHA': data['FECHA'] ?? '',
        'NOMBRE': data['NOMBRE'] ?? '',
        'USUARIO': data['USUARIO'] ?? '',
      };
    }
    return null;
  }

  Future<void> _escanearOBuscar() async {
    final codigo = _escaneoController.text.trim();
    if (codigo.isEmpty) return;
    // Buscar si ya existe en historial
    final snap = await FirebaseFirestore.instance
        .collection('cartas_porte')
        .where('MANIFIESTO', isEqualTo: codigo)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      // Editar existente
      final carta = snap.docs.first.data();
      carta['id'] = snap.docs.first.id;
      await _editarCartaDialog(carta);
    } else {
      // Buscar datos externos
      final datos = await _buscarDatosExternos(codigo);
      if (datos != null) {
        // Agregar nueva carta con datos externos
        await _editarCartaDialog(datos);
      } else {
        // Agregar nueva carta vacía con manifiesto prellenado
        await _editarCartaDialog({'MANIFIESTO': codigo});
      }
    }
    _escaneoController.clear();
  }

  Future<void> exportarAExcel(BuildContext context) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('cartas_porte').get();
      final cartas = snapshot.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return data;
      }).toList();
      if (cartas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos para exportar')),
        );
        return;
      }
      await exportarExcel(cartas: cartas);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportación exitosa')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: const Icon(Icons.local_shipping, color: Color(0xFF2D6A4F)),
        title: const Text(
          'Historial Carta Porte',
          style: TextStyle(
            color: Color(0xFF2D6A4F),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Color(0xFF2D6A4F)),
            tooltip: 'Exportar a Excel',
            onPressed: () async {
              await exportarAExcel(context);
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _escaneoController,
                    decoration: const InputDecoration(
                      labelText: 'Escanear/Buscar Manifiesto',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                    ),
                    onSubmitted: (_) => _escanearOBuscar(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                  onPressed: _escanearOBuscar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2D6A4F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('cartas_porte')
                    .orderBy('numero_control', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: \\${snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final busqueda =
                      _busquedaController.text.trim().toLowerCase();
                  final cartas = docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    data['id'] = d.id;
                    return data;
                  }).where((carta) {
                    if (busqueda.isEmpty) return true;
                    return carta.values.any((v) =>
                        v != null &&
                        v.toString().toLowerCase().contains(busqueda));
                  }).toList();
                  if (cartas.isEmpty) {
                    return const Center(child: Text('No hay cartas porte'));
                  }
                  return ListView.builder(
                    itemCount: cartas.length,
                    itemBuilder: (context, idx) {
                      final carta = cartas[idx];
                      final choferStr = (carta['chofer'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase();
                      final isPendiente = choferStr == 'PENDIENTE';
                      return Card(
                        color: isPendiente
                            ? Colors.orange.shade200
                            : const Color(0xFFF5F6FA),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                              'Manifiesto: ${carta['numero_control'] ?? '-'}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Destino: ${carta['destino'] ?? '-'}'),
                              Text('Fecha: ${carta['fecha'] ?? '-'}'),
                              Text('Chofer: ${carta['chofer'] ?? '-'}'),
                              Text('RFC: ${carta['rfc'] ?? '-'}'),
                              Text('Unidad: ${carta['unidad'] ?? '-'}'),
                              if (isPendiente)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Falta editar parámetros',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CartaPorteEdicionPage(
                                  carta: carta,
                                  docId: carta['id'],
                                ),
                              ),
                            );
                          },
                        ),
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
