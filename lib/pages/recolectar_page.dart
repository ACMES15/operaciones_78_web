import 'dart:ui' as ui;
import 'firma_painter.dart';
// import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';

class RecolectarPage extends StatefulWidget {
  const RecolectarPage({Key? key}) : super(key: key);

  @override
  State<RecolectarPage> createState() => _RecolectarPageState();
}

class _RecolectarPageState extends State<RecolectarPage> {
  Future<String> _firmaToBase64(List<Offset?> points) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, 350, 120));
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(350, 120);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return '';
    return base64Encode(byteData.buffer.asUint8List());
  }

  String? _filtroJefatura;

  void _abrirDialogoFirma() async {
    final seleccionados = _seleccionados.map((i) => _pendientes[i]).toList();
    final entregoController = TextEditingController();
    String entrego = '';
    List<Offset?> firma = [];
    bool guardando = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.assignment_turned_in,
                      color: Colors.blueGrey, size: 28),
                  const SizedBox(width: 10),
                  const Text('Confirmar entrega',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Entregó',
                        labelStyle: TextStyle(fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      controller: entregoController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (v) {
                        final upper = v.toUpperCase();
                        if (v != upper) {
                          entregoController.value =
                              entregoController.value.copyWith(
                            text: upper,
                            selection:
                                TextSelection.collapsed(offset: upper.length),
                          );
                        }
                        setStateDialog(() {
                          entrego = upper;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text('Firma (dibuje en el recuadro):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      width: 370,
                      height: 130,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueGrey, width: 2),
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 2)
                        ],
                      ),
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setStateDialog(() {
                            RenderBox? box =
                                ctx.findRenderObject() as RenderBox?;
                            if (box != null) {
                              final local =
                                  box.globalToLocal(details.globalPosition);
                              firma.add(local);
                            }
                          });
                        },
                        onPanEnd: (_) {
                          setStateDialog(() {
                            firma.add(null);
                          });
                        },
                        child: CustomPaint(
                          painter: FirmaPainter(firma),
                          child: Container(),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setStateDialog(() {
                              firma.clear();
                            });
                          },
                          icon: const Icon(Icons.cleaning_services, size: 18),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: guardando ||
                          entregoController.text.trim().isEmpty ||
                          firma.where((p) => p != null).length < 2
                      ? null
                      : () async {
                          setStateDialog(() {
                            guardando = true;
                          });
                          final firmaBase64 = await _firmaToBase64(firma);
                          final now = DateTime.now();
                          final usuario = html.window.localStorage['usuario'] ??
                              'STAFF DEVOLUCION';
                          // Adaptar estructura para entregas_mkp_page
                          final registros = seleccionados.map((e) {
                            return {
                              // Estructura esperada por entregas_mkp_page
                              'empleado':
                                  e['NUMERO VENDEDOR'] ?? e['EMPLEADO'] ?? '',
                              'devolucion_mkp':
                                  e['REmision'] ?? e['REMISION'] ?? '',
                              'skus': [e['ARTICULO'] ?? e['SKU'] ?? ''],
                              'cantidad': 1,
                              'usuario': usuario,
                              'fecha': now.toIso8601String(),
                              // Extras para trazabilidad
                              'nombre_vendedor': e['NOMBRE DE VENDEDOR'] ?? '',
                              'jefatura': e['JEFATURA'] ?? '',
                              'firma': firmaBase64,
                              'entrego':
                                  entregoController.text.trim().toUpperCase(),
                              'estatus_actual': 'ENTREGADO',
                              'fecha_entrega': now.toIso8601String(),
                              // Otros campos originales por si se requieren
                              ...e,
                            };
                          }).toList();
                          final doc = await FirebaseFirestore.instance
                              .collection('entregas')
                              .doc('mkp')
                              .get();
                          final items = (doc.data()?['items'] ?? []) as List;
                          items.addAll(registros);
                          await FirebaseFirestore.instance
                              .collection('entregas')
                              .doc('mkp')
                              .set({'items': items});
                          setState(() {
                            _pendientes
                                .removeWhere((e) => seleccionados.contains(e));
                            _seleccionados.clear();
                          });
                          final nuevosPendientes = _pendientes;
                          html.window.localStorage['reporte_mkp_no_entregado'] =
                              jsonEncode(nuevosPendientes);
                          await FirebaseFirestore.instance
                              .collection('reporte_mkp_no_entregado')
                              .doc('pendientes')
                              .set({'items': nuevosPendientes});
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Entrega registrada y guardada.')),
                          );
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Set<int> _seleccionados = {};
  List<Map<String, dynamic>> _pendientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes({bool forzarFirestore = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      List<Map<String, dynamic>> datos = [];
      if (!forzarFirestore) {
        // Intentar leer de cache local (JSON)
        try {
          final cache = html.window.localStorage['reporte_mkp_no_entregado'];
          if (cache != null && cache.isNotEmpty) {
            final decoded = jsonDecode(cache);
            if (decoded is List) {
              datos = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            }
          }
        } catch (e) {}
      }
      if (datos.isEmpty) {
        // Leer de Firestore
        final doc = await FirebaseFirestore.instance
            .collection('reporte_mkp_no_entregado')
            .doc('pendientes')
            .get();
        final items = (doc.data()?['items'] ?? []) as List?;
        if (items != null) {
          for (final item in items) {
            datos.add(Map<String, dynamic>.from(item));
          }
        }
      }
      setState(() {
        _pendientes = datos;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar: ' + e.toString();
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jefaturas = _pendientes
        .map((e) => e['JEFATURA'] ?? '')
        .where((e) => e.toString().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final totalPendientes = _pendientes.length;
    final seleccionadosCount = _seleccionados.length;
    final pendientesFiltrados =
        _filtroJefatura == null || _filtroJefatura!.isEmpty
            ? _pendientes
            : _pendientes
                .where((e) => (e['JEFATURA'] ?? '') == _filtroJefatura)
                .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recolectar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: const ui.Color.fromARGB(255, 170, 194, 206),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Forzar recarga Firestore',
            onPressed: () => _cargarPendientes(forzarFirestore: true),
          ),
        ],
        elevation: 4,
      ),
      body: Container(
        color: Colors.blueGrey[50],
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: TextStyle(color: Colors.red, fontSize: 18)))
                : _pendientes.isEmpty
                    ? const Center(
                        child: Text('No hay registros pendientes.',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w500)))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 24),
                            color: Colors.blueGrey[800],
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Resumen de pendientes',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16)),
                                    Text('$totalPendientes registros',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22)),
                                  ],
                                ),
                                if (seleccionadosCount > 0)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.white),
                                    label: Text(
                                        'Firmar selección ($seleccionadosCount)',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      textStyle: const TextStyle(fontSize: 16),
                                      elevation: 2,
                                    ),
                                    onPressed: _abrirDialogoFirma,
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            child: Row(
                              children: [
                                const Text('Filtrar por Jefatura:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                DropdownButton<String>(
                                  value: _filtroJefatura,
                                  hint: const Text('Todas'),
                                  items: [
                                    const DropdownMenuItem<String>(
                                        value: null, child: Text('Todas')),
                                    ...jefaturas.map((j) =>
                                        DropdownMenuItem<String>(
                                            value: j,
                                            child: Text(j.toString()))),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _filtroJefatura = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListView.separated(
                                itemCount: pendientesFiltrados.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1, color: Colors.blueGrey[100]),
                                itemBuilder: (context, idx) {
                                  final item = pendientesFiltrados[idx];
                                  final realIdx = _pendientes.indexOf(item);
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: _seleccionados.contains(realIdx)
                                          ? Colors.green.withOpacity(0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: CheckboxListTile(
                                      value: _seleccionados.contains(realIdx),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _seleccionados.add(realIdx);
                                          } else {
                                            _seleccionados.remove(realIdx);
                                          }
                                        });
                                      },
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                                item['NOMBRE CENTRO'] ?? '',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18)),
                                          ),
                                          if ((item['JEFATURA'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey[100],
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(item['JEFATURA'],
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blueGrey)),
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if ((item['NOMBRE DE VENDEDOR'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Text(
                                                'Vendedor: ${item['NOMBRE DE VENDEDOR']}',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87)),
                                          Text(
                                              'Remisión: ${item['REmision'] ?? ''}',
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                          Text(
                                              'Artículo: ${item['ARTICULO'] ?? ''}',
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                          if ((item['OBSERVACIONES'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                  'Obs: ${item['OBSERVACIONES']}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black54)),
                                            ),
                                        ],
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: Colors.green.shade700,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 18, vertical: 8),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
// ...existing code up to el final del último widget correcto...
// Fin de _RecolectarPageState
  }
}
// Fin de _RecolectarPageState
