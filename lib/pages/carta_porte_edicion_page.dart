import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../utils/skus_utils.dart' as skus_utils;
import 'carta_porte_imprimir_page.dart';

class CartaPorteEdicionPage extends StatefulWidget {
  final Map<String, dynamic> carta;
  final String docId;
  const CartaPorteEdicionPage(
      {Key? key, required this.carta, required this.docId})
      : super(key: key);

  @override
  @override
  State<CartaPorteEdicionPage> createState() => _CartaPorteEdicionPageState();
}

class _CartaPorteEdicionPageState extends State<CartaPorteEdicionPage> {
  late TextEditingController embarqueController;
  late TextEditingController choferController;
  late TextEditingController destinoController;
  late TextEditingController fechaController;
  late TextEditingController numeroControlController;
  late TextEditingController rfcController;
  late TextEditingController unidadController;
  late TextEditingController licenciaController;
  List<Map<String, dynamic>> filas = [];
  List<Map<String, dynamic>> choferes = [];
  String? choferSeleccionado;

  @override
  void initState() {
    super.initState();
    choferController =
        TextEditingController(text: widget.carta['chofer'] ?? '');
    destinoController =
        TextEditingController(text: widget.carta['destino'] ?? '');
    fechaController = TextEditingController(text: widget.carta['fecha'] ?? '');
    numeroControlController =
        TextEditingController(text: widget.carta['numero_control'] ?? '');
    embarqueController =
        TextEditingController(text: widget.carta['embarque'] ?? '');
    rfcController = TextEditingController(text: widget.carta['rfc'] ?? '');
    unidadController =
        TextEditingController(text: widget.carta['unidad'] ?? '');
    licenciaController =
        TextEditingController(text: widget.carta['licencia'] ?? '');
    final rawFilas = widget.carta['filas'];
    if (rawFilas is List) {
      filas = rawFilas.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    choferSeleccionado = widget.carta['chofer'];
    _cargarChoferes();
  }

  Future<void> _cargarChoferes() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('choferes').get();
    setState(() {
      choferes = snapshot.docs.map((d) {
        final data = d.data();
        return {
          'nombre': data['nombre'] ?? '',
          'rfc': data['rfc'] ?? '',
          'licencia': data['licencia'] ?? '',
        };
      }).toList();
    });
  }

  @override
  void dispose() {
    choferController.dispose();
    destinoController.dispose();
    fechaController.dispose();
    numeroControlController.dispose();
    embarqueController.dispose();
    rfcController.dispose();
    unidadController.dispose();
    licenciaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final data = {
      'chofer': choferSeleccionado ?? '',
      'destino': destinoController.text,
      'fecha': fechaController.text,
      'numero_control': numeroControlController.text,
      'rfc': rfcController.text,
      'unidad': unidadController.text,
      'licencia': licenciaController.text,
      'filas': filas,
    };
    await FirebaseFirestore.instance
        .collection('cartas_porte')
        .doc(widget.docId)
        .update(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carta porte actualizada')),
      );
      Navigator.of(context).pop(true);
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
          'Editar Carta Porte',
          style: TextStyle(
            color: Color(0xFF2D6A4F),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF2D6A4F)),
            tooltip: 'Agregar fila',
            onPressed: () async {
              final nuevasFilas =
                  await Navigator.of(context).push<List<Map<String, dynamic>>>(
                MaterialPageRoute(
                  builder: (_) => CartaPorteAgregarFilaPage(
                    carta: widget.carta,
                  ),
                ),
              );
              if (nuevasFilas != null && nuevasFilas.isNotEmpty) {
                setState(() {
                  filas.addAll(nuevasFilas);
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFF2D6A4F)),
            tooltip: 'Guardar',
            onPressed: _guardar,
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF2D6A4F)),
            tooltip: 'Imprimir',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CartaPorteImprimirPage(
                    carta: {
                      ...widget.carta,
                      'chofer': choferSeleccionado ?? '',
                      'destino': destinoController.text,
                      'fecha': fechaController.text,
                      'numero_control': numeroControlController.text,
                      'embarque': embarqueController.text,
                      'rfc': rfcController.text,
                      'unidad': unidadController.text,
                      'filas': filas,
                    },
                  ),
                ),
              );
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: embarqueController,
              decoration: const InputDecoration(labelText: 'Embarque'),
              readOnly: false,
            ),
            DropdownButtonFormField<String>(
              value: choferSeleccionado,
              decoration: const InputDecoration(labelText: 'Chofer'),
              items: choferes.map((c) {
                final nombre = c['nombre'] ?? '';
                final rfc = c['rfc'] ?? '';
                final licencia = c['licencia'] ?? '';
                return DropdownMenuItem<String>(
                  value: nombre,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (rfc.isNotEmpty || licencia.isNotEmpty)
                        Text('RFC: $rfc   Licencia: $licencia',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (nuevo) {
                setState(() {
                  choferSeleccionado = nuevo;
                  final chofer = choferes.firstWhere(
                    (c) => c['nombre'] == nuevo,
                    orElse: () => {'rfc': '', 'licencia': ''},
                  );
                  rfcController.text = chofer['rfc'] ?? '';
                  licenciaController.text = chofer['licencia'] ?? '';
                });
              },
            ),
            TextField(
              controller: destinoController,
              decoration: const InputDecoration(labelText: 'Destino'),
            ),
            TextField(
              controller: rfcController,
              decoration: const InputDecoration(labelText: 'RFC'),
              readOnly: false,
            ),
            TextField(
              controller: licenciaController,
              decoration: const InputDecoration(labelText: 'Licencia'),
              readOnly: false,
            ),
            TextField(
              controller: unidadController,
              decoration: const InputDecoration(labelText: 'Unidad'),
              readOnly: false,
            ),
            TextField(
              controller: fechaController,
              decoration: const InputDecoration(labelText: 'Fecha'),
              enabled: false,
            ),
            TextField(
              controller: numeroControlController,
              decoration: const InputDecoration(labelText: 'Número de control'),
              enabled: false,
            ),
            // ...existing code...
            Row(
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar Concentrado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final concentrados = filas
                            .map((f) => f['CONCENTRADO']?.toString() ?? '')
                            .where((c) => c.isNotEmpty)
                            .join('\n');
                        if (concentrados.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: concentrados));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Todos los concentrados copiados')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No hay datos en la columna Concentrado')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder<List<List<String>>>(
                      future: () async {
                        // Buscar SKUs ligados por numero_control y embarque
                        final nc = numeroControlController.text;
                        final emb = embarqueController.text;
                        List<List<String>> skus = [];
                        if (nc.isNotEmpty) {
                          skus =
                              await skus_utils.obtenerSkusLigadosHojaDeRuta(nc);
                        }
                        if ((skus.isEmpty) && emb.isNotEmpty) {
                          skus = await skus_utils
                              .obtenerSkusLigadosHojaDeRuta(emb);
                        }
                        return skus;
                      }(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final skus = snapshot.data ?? [];
                        if (skus.isNotEmpty) {
                          return Tooltip(
                            message: 'Copiar SKUs ligados',
                            child: IconButton(
                              icon: const Icon(Icons.copy,
                                  size: 20, color: Colors.green),
                              onPressed: () {
                                final texto = skus_utils.skusToTexto(skus);
                                Clipboard.setData(ClipboardData(text: texto));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('SKUs ligados copiados')),
                                );
                              },
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Filas:', style: TextStyle(fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filas.length,
              itemBuilder: (context, idx) {
                final fila = filas[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: fila.entries
                                .map((e) => Text('${e.key}: ${e.value}'))
                                .toList(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar fila',
                          onPressed: () async {
                            final confirmar = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar fila'),
                                content: const Text(
                                    '¿Seguro que quieres eliminar este registro?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmar == true) {
                              setState(() {
                                filas.removeAt(idx);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Página para agregar una nueva fila reutilizando la lógica y vista de carta porte original
class CartaPorteAgregarFilaPage extends StatefulWidget {
  final Map<String, dynamic> carta;
  const CartaPorteAgregarFilaPage({Key? key, required this.carta})
      : super(key: key);

  @override
  State<CartaPorteAgregarFilaPage> createState() =>
      _CartaPorteAgregarFilaPageState();
}

class _CartaPorteAgregarFilaPageState extends State<CartaPorteAgregarFilaPage> {
  late List<String> columns;
  late List<List<TextEditingController>> filasControllers;
  final int filasCount = 5;

  @override
  void initState() {
    super.initState();
    // Usar el mismo orden y nombres de columnas que carta_porte_table.dart
    columns = [
      'ESCANEO',
      'NO.',
      'TIPO',
      'SYS',
      'EMBARQUE',
      'DESCRIPCIÓN / COMENTARIOS',
      'NO. DE BULTOS',
      'DESTINO',
      // Agrega aquí más columnas si tu tabla original tiene más
    ];
    filasControllers = List.generate(
      filasCount,
      (_) => List.generate(columns.length, (_) => TextEditingController()),
    );
  }

  Future<void> _autocompletarPorEscaneo(int filaIdx, int colIdx) async {
    try {
      final escaneo = filasControllers[filaIdx][0].text.trim();
      if (escaneo.isEmpty) return;
      // Aquí va la lógica de autollenado, ya alineada con carta_porte_table.dart
      // ...existing code de autollenado...
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Fila'),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Completa los datos de la nueva fila:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filasCount,
                itemBuilder: (context, filaIdx) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: List.generate(columns.length, (colIdx) {
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextField(
                                controller: filasControllers[filaIdx][colIdx],
                                decoration:
                                    InputDecoration(labelText: columns[colIdx]),
                                onChanged: (_) {
                                  if (colIdx == 0) {
                                    _autocompletarPorEscaneo(filaIdx, colIdx);
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Agregar'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F)),
                  onPressed: () {
                    final nuevasFilas = filasControllers
                        .map((fila) {
                          return Map.fromIterables(
                              columns, fila.map((c) => c.text));
                        })
                        .where((fila) => fila.values
                            .any((v) => v.toString().trim().isNotEmpty))
                        .toList();
                    Navigator.of(context).pop(nuevasFilas);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
