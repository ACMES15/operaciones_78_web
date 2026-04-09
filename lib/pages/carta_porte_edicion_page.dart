import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
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
              final nuevaFila =
                  await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (_) => CartaPorteAgregarFilaPage(
                    carta: widget.carta,
                  ),
                ),
              );
              if (nuevaFila != null) {
                setState(() {
                  filas.add(nuevaFila);
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
              controller: fechaController,
              decoration: const InputDecoration(labelText: 'Fecha'),
              enabled: false,
            ),
            TextField(
              controller: numeroControlController,
              decoration: const InputDecoration(labelText: 'Número de control'),
              enabled: false,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: rfcController,
                    decoration: const InputDecoration(labelText: 'RFC'),
                    enabled: false,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copiar RFC',
                  icon: const Icon(Icons.copy, size: 22),
                  onPressed: () {
                    final text = rfcController.text;
                    if (text.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('RFC copiado')),
                      );
                    }
                  },
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: licenciaController,
                    decoration: const InputDecoration(labelText: 'Licencia'),
                    enabled: false,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copiar licencia',
                  icon: const Icon(Icons.copy, size: 22),
                  onPressed: () {
                    final text = licenciaController.text;
                    if (text.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Licencia copiada')),
                      );
                    }
                  },
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
    // Copiar columnas y preparar controladores para 5 filas
    final ejemplo = (widget.carta['filas'] as List?)?.isNotEmpty == true
        ? Map<String, dynamic>.from((widget.carta['filas'] as List).first)
        : <String, dynamic>{'ESCANEO': '', 'CANTIDAD': '', 'DESCRIPCION': ''};
    columns = ejemplo.keys.toList();
    filasControllers = List.generate(
      filasCount,
      (_) => columns.map((k) => TextEditingController()).toList(),
    );
  }

  @override
  void dispose() {
    for (final fila in filasControllers) {
      for (final c in fila) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _autocompletarPorEscaneo(int filaIdx, int colIdx) async {
    try {
      final escaneo = filasControllers[filaIdx][colIdx].text.trim();
      final escaneoLower = escaneo.toLowerCase();
      if (escaneo.isEmpty) return;

      // Buscar en hoja_ruta
      final hojaRutaSnap = await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .orderBy('fecha', descending: true)
          .get();
      final hojaRutaDocs = hojaRutaSnap.docs
          .where((doc) =>
              (doc.data()['caja'] ?? '').toString().trim().toLowerCase() ==
              escaneoLower)
          .toList();

      // Buscar en hoja_de_xd_historial
      final xdSnap = await FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .orderBy('fecha', descending: true)
          .get();
      List<dynamic> xd = xdSnap.docs
          .map((doc) => doc.data())
          .where((h) => ((h['CONTENEDOR O TARIMA'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase() ==
              escaneoLower))
          .toList();

      // Si no hay resultados directos, buscar por TARIMA
      if (xd.isEmpty) {
        final allDocs = xdSnap;
        xd = allDocs.docs
            .map((doc) => doc.data())
            .where((h) => ((h['CONTENEDOR O TARIMA'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase() ==
                    escaneoLower ||
                (h['TARIMA'] ?? '').toString().trim().toLowerCase() ==
                    escaneoLower))
            .toList();
      }

      // Unificar resultados
      final List<Map<String, dynamic>> resultados = [];
      for (final doc in hojaRutaDocs) {
        final data = doc.data();
        if (data['fecha'] != null) {
          resultados
              .add({'tipo': 'hoja_ruta', 'fecha': data['fecha'], 'data': data});
        }
      }
      for (final h in xd) {
        resultados.add({'tipo': 'xd', 'fecha': h['fecha'], 'data': h});
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

      // Mapear columnas por nombre
      String getCol(String nombre) {
        final idx = columns.indexWhere((c) => c.toUpperCase() == nombre);
        return idx >= 0 ? columns[idx] : '';
      }

      if (masReciente['tipo'] == 'hoja_ruta') {
        final ruta = masReciente['data'];
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
            final columnsRuta = (ruta['columns'] as List?) ?? [];
            final idx = columnsRuta.indexWhere((c) =>
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
        // Asignar datos a los campos si existen
        for (int i = 0; i < columns.length; i++) {
          final col = columns[i].toUpperCase();
          if (col.contains('TIPO'))
            filasControllers[filaIdx][i].text = ruta['tipo'] ?? '';
          if (col.contains('SISTEMA'))
            filasControllers[filaIdx][i].text = 'SAP';
          if (col.contains('EMBARQUE'))
            filasControllers[filaIdx][i].text = embarque;
          if (col.contains('BULTOS')) {
            int sumaBultos = 0;
            for (final row in rows) {
              if (row is Map && row['No. Bultos'] != null) {
                final val = int.tryParse(row['No. Bultos'].toString());
                if (val != null) sumaBultos += val;
              } else if (row is List) {
                final columnsRuta = (ruta['columns'] as List?) ?? [];
                final idx = columnsRuta.indexWhere(
                    (c) => c.toString().toLowerCase().contains('bultos'));
                if (idx >= 0 && row.length > idx && row[idx] != null) {
                  final val = int.tryParse(row[idx].toString());
                  if (val != null) sumaBultos += val;
                }
              }
            }
            filasControllers[filaIdx][i].text =
                sumaBultos > 0 ? sumaBultos.toString() : '';
          }
          if (col.contains('DESTINO')) {
            String destino = '';
            for (final row in rows) {
              if (row is Map &&
                  row['No. Alm.'] != null &&
                  row['No. Alm.'].toString().isNotEmpty) {
                destino = row['No. Alm.'].toString();
                break;
              } else if (row is List) {
                final columnsRuta = (ruta['columns'] as List?) ?? [];
                final idx = columnsRuta.indexWhere(
                    (c) => c.toString().toLowerCase().contains('alm'));
                if (idx >= 0 &&
                    row.length > idx &&
                    row[idx] != null &&
                    row[idx].toString().isNotEmpty) {
                  destino = row[idx].toString();
                  break;
                }
              }
            }
            filasControllers[filaIdx][i].text = destino;
          }
          if (col.contains('ESCANEO'))
            filasControllers[filaIdx][i].text = escaneo;
        }
        setState(() {});
        return;
      } else if (masReciente['tipo'] == 'xd') {
        final h = masReciente['data'];
        for (int i = 0; i < columns.length; i++) {
          final col = columns[i].toUpperCase();
          if (col.contains('TIPO')) filasControllers[filaIdx][i].text = 'PAQ';
          if (col.contains('SISTEMA'))
            filasControllers[filaIdx][i].text =
                (h['TU'] ?? '').toString().trim().isNotEmpty ? 'MAN' : 'XD';
          if (col.contains('EMBARQUE'))
            filasControllers[filaIdx][i].text = h['MANIFIESTO'] ?? '';
          if (col.contains('BULTOS'))
            filasControllers[filaIdx][i].text = h['CANTIDAD DE LPS'] ?? '';
          if (col.contains('DESTINO'))
            filasControllers[filaIdx][i].text = h['DESTINO'] ?? '';
          if (col.contains('ESCANEO'))
            filasControllers[filaIdx][i].text = escaneo;
        }
        setState(() {});
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  bool _filaTieneDatos(List<TextEditingController> fila) {
    return fila.any((c) => c.text.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar filas (ejecutivo)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final col in columns)
                    Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        col,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              for (int filaIdx = 0; filaIdx < filasCount; filaIdx++)
                Row(
                  children: [
                    for (int colIdx = 0; colIdx < columns.length; colIdx++)
                      Container(
                        width: 140,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: TextField(
                          controller: filasControllers[filaIdx][colIdx],
                          decoration:
                              InputDecoration(labelText: columns[colIdx]),
                          onChanged: columns[colIdx]
                                  .toUpperCase()
                                  .contains('ESCANEO')
                              ? (_) => _autocompletarPorEscaneo(filaIdx, colIdx)
                              : null,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final filasValidas = <Map<String, dynamic>>[];
                  for (final fila in filasControllers) {
                    if (_filaTieneDatos(fila)) {
                      final map = <String, dynamic>{};
                      for (int i = 0; i < columns.length; i++) {
                        map[columns[i]] = fila[i].text;
                      }
                      filasValidas.add(map);
                    }
                  }
                  if (filasValidas.isEmpty) {
                    // Permitir regresar a editar carta porte si no hay datos
                    Navigator.of(context).pop();
                    return;
                  }
                  Navigator.of(context).pop(filasValidas);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
