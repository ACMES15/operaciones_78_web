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
  Future<void> _autocompletarPorEscaneo(int filaIdx, int colIdx) async {
    try {
      final escaneo = filasControllers[filaIdx][0].text.trim();
      final escaneoLower = escaneo.toLowerCase();
      if (escaneo.isEmpty) return;

      // Buscar en hoja_ruta (todas las coincidencias)
      final hojaRutaSnap = await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .orderBy('fecha', descending: true)
          .get();
      final hojaRutaDocs = hojaRutaSnap.docs
          .where((doc) =>
              (doc.data()['caja'] ?? '').toString().trim().toLowerCase() ==
              escaneoLower)
          .toList();

      // Buscar en hoja_de_xd_historial (todas las coincidencias)
      final xdSnap = await FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .orderBy('fecha', descending: true)
          .get();
      List<dynamic> xd = xdSnap.docs
          .map((doc) => doc.data())
          .where((h) =>
              (h['datos']?['CONTENEDOR O TARIMA'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase() ==
              escaneoLower)
          .toList();

      // Si no hay resultados directos, buscar por 'CONTENEDOR' o 'TARIMA' en todos los docs de hoja_de_xd_historial
      if (xd.isEmpty) {
        xd = xdSnap.docs
            .map((doc) => doc.data())
            .where((h) => ((h['datos']?['CONTENEDOR O TARIMA'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase() ==
                    escaneoLower ||
                (h['datos']?['TARIMA'] ?? '').toString().trim().toLowerCase() ==
                    escaneoLower))
            .toList();
      }

      // Unificar todos los resultados en una lista con tipo y fecha
      final List<Map<String, dynamic>> resultados = [];
      for (final doc in hojaRutaDocs) {
        final data = doc.data();
        if (data['fecha'] != null) {
          resultados.add({
            'tipo': 'hoja_ruta',
            'fecha': data['fecha'],
            'data': data,
          });
        }
      }
      for (final h in xd) {
        resultados.add({
          'tipo': 'xd',
          'fecha': h['fecha'],
          'data': h,
        });
      }

      if (resultados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se encontró información para "$escaneo" en Firestore.')),
        );
        return;
      }

      DateTime _toDate(dynamic f) {
        if (f is DateTime) return f;
        if (f is Timestamp) return f.toDate();
        if (f is String) {
          try {
            return DateTime.parse(f);
          } catch (_) {
            return DateTime(1970);
          }
        }
        return DateTime(1970);
      }

      resultados.sort((a, b) {
        final fa = _toDate(a['fecha']);
        final fb = _toDate(b['fecha']);
        return fb.compareTo(fa);
      });
      final masReciente = resultados.first;

      if (masReciente['tipo'] == 'hoja_ruta') {
        final ruta = masReciente['data'];
        filasControllers[filaIdx][2].text = ruta['tipo'] ?? '';
        filasControllers[filaIdx][3].text = 'SAP';
        final rows = (ruta['rows'] as List?) ?? [];
        String embarque = '';
        for (final row in rows) {
          if (row is Map) {
            if ((row['No. Manifiesto o Remisión'] != null &&
                row['No. Manifiesto o Remisión'].toString().isNotEmpty)) {
              embarque = row['No. Manifiesto o Remisión'].toString();
              break;
            } else if ((row['Rem'] != null &&
                row['Rem'].toString().isNotEmpty)) {
              embarque = row['Rem'].toString();
              break;
            }
          } else if (row is List) {
            final columns = (ruta['columns'] as List?) ?? [];
            final idx = columns.indexWhere((c) =>
                c.toString().toLowerCase().contains('manifiesto') ||
                c.toString().toLowerCase().contains('rem'));
            if (idx >= 0 &&
                row.length > idx &&
                row[idx] != null &&
                row[idx].toString().isNotEmpty) {
              embarque = row[idx].toString();
              break;
            }
          }
        }
        filasControllers[filaIdx][4].text = embarque;
        filasControllers[filaIdx][5].text = ruta['tipo'] ?? '';
        int sumaBultos = 0;
        for (final row in rows) {
          if (row is Map && row['No. Bultos'] != null) {
            final val = int.tryParse(row['No. Bultos'].toString());
            if (val != null) sumaBultos += val;
          } else if (row is List) {
            final columns = (ruta['columns'] as List?) ?? [];
            final idx = columns.indexWhere(
                (c) => c.toString().toLowerCase().contains('bultos'));
            if (idx >= 0 && row.length > idx && row[idx] != null) {
              final val = int.tryParse(row[idx].toString());
              if (val != null) sumaBultos += val;
            }
          }
        }
        filasControllers[filaIdx][6].text =
            sumaBultos > 0 ? sumaBultos.toString() : '';
        String destino = '';
        for (final row in rows) {
          if (row is Map &&
              row['No. Alm.'] != null &&
              row['No. Alm.'].toString().isNotEmpty) {
            destino = row['No. Alm.'].toString();
            break;
          } else if (row is List) {
            final columns = (ruta['columns'] as List?) ?? [];
            final idx = columns
                .indexWhere((c) => c.toString().toLowerCase().contains('alm'));
            if (idx >= 0 &&
                row.length > idx &&
                row[idx] != null &&
                row[idx].toString().isNotEmpty) {
              destino = row[idx].toString();
              break;
            }
          }
        }
        filasControllers[filaIdx][7].text = destino;
        filasControllers[filaIdx][8].text = escaneo;
        final embarque1 = filasControllers[filaIdx][4].text;
        final embarque2 = filasControllers[filaIdx][9].text;
        filasControllers[filaIdx][10].text =
            embarque1.isNotEmpty ? embarque1 : embarque2;
        setState(() {});
        return;
      } else if (masReciente['tipo'] == 'xd') {
        final h = masReciente['data'];
        filasControllers[filaIdx][2].text = 'PAQ';
        final tu = (h['datos']?['TU'] ?? '').toString().trim();
        if (tu.isNotEmpty) {
          filasControllers[filaIdx][3].text = 'MAN';
          filasControllers[filaIdx][4].text = tu;
        } else {
          filasControllers[filaIdx][3].text = 'XD';
        }
        filasControllers[filaIdx][5].text = h['datos']?['MANIFIESTO'] ?? '';
        filasControllers[filaIdx][6].text =
            h['datos']?['CANTIDAD DE LPS'] ?? '';
        filasControllers[filaIdx][7].text = h['datos']?['DESTINO'] ?? '';
        filasControllers[filaIdx][8].text = escaneo;
        final embarque1 = filasControllers[filaIdx][4].text;
        final embarque2 = filasControllers[filaIdx][9].text;
        filasControllers[filaIdx][10].text =
            embarque1.isNotEmpty ? embarque1 : embarque2;
        setState(() {});
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  final List<String> columns = [
    'ESCANEO',
    'NO.',
    'TIPO',
    'CLASE',
    'EMBARQUE 1',
    'EMBARQUE 2',
    'NO. DE BULTOS',
    'DESTINO',
    'DESCRIPCIÓN / COMENTARIOS',
    'CONCENTRADO',
    'OTRO',
  ];

  late List<List<TextEditingController>> filasControllers;
  late List<FocusNode> escaneoFocusNodes;
  int filasCount = 1;

  @override
  void initState() {
    super.initState();
    filasControllers = List.generate(
      filasCount,
      (_) => List.generate(columns.length, (_) => TextEditingController()),
    );
    escaneoFocusNodes = List.generate(filasCount, (_) => FocusNode());
  }

  // Anchos personalizados para cada columna
  final List<double> colWidths = [
    120, // ESCANEO
    40, // NO.
    60, // TIPO
    60, // CLASE
    100, // EMBARQUE 1
    100, // EMBARQUE 2
    60, // NO. DE BULTOS
    80, // DESTINO
    100, // DESCRIPCIÓN / COMENTARIOS
    100, // CONCENTRADO
    100, // OTRO
  ];

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
                          return Container(
                            width: colWidths[colIdx],
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: TextField(
                              controller: filasControllers[filaIdx][colIdx],
                              focusNode: colIdx == 0
                                  ? escaneoFocusNodes[filaIdx]
                                  : null,
                              decoration:
                                  InputDecoration(labelText: columns[colIdx]),
                              maxLength: colIdx == 1
                                  ? 2 // NO.
                                  : colIdx == 6
                                      ? 4 // NO. DE BULTOS
                                      : colIdx == 7
                                          ? 4 // DESTINO
                                          : null,
                              buildCounter: (context,
                                      {required currentLength,
                                      required isFocused,
                                      maxLength}) =>
                                  null,
                              onChanged: (_) {
                                if (colIdx == 0) {
                                  _autocompletarPorEscaneo(filaIdx, colIdx);
                                }
                              },
                              onSubmitted: (value) async {
                                if (colIdx == 0) {
                                  await _autocompletarPorEscaneo(
                                      filaIdx, colIdx);
                                  if (filaIdx + 1 < filasCount) {
                                    FocusScope.of(context).requestFocus(
                                        escaneoFocusNodes[filaIdx + 1]);
                                  }
                                }
                              },
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
