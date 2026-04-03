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

  void _abrirDialogoFirma() async {
    final seleccionados = _seleccionados.map((i) => _pendientes[i]).toList();
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
              title: const Text('Entrega de artículos'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Entregó'),
                      onChanged: (v) {
                        setStateDialog(() {
                          entrego = v.toUpperCase();
                        });
                      },
                      controller: TextEditingController(text: entrego),
                    ),
                    const SizedBox(height: 16),
                    const Text('Firma (dibuje en el recuadro):'),
                    Container(
                      width: 350,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        color: Colors.white,
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
                        TextButton(
                          onPressed: () {
                            setStateDialog(() {
                              firma.clear();
                            });
                          },
                          child: const Text('Limpiar'),
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
                ElevatedButton(
                  onPressed: guardando || entrego.isEmpty || firma.isEmpty
                      ? null
                      : () async {
                          setStateDialog(() {
                            guardando = true;
                          });
                          // Convertir firma a base64 PNG
                          final firmaBase64 = await _firmaToBase64(firma);
                          // Preparar datos para entregas mkp page
                          final registros = seleccionados
                              .map((e) => {
                                    ...e,
                                    'ENTREGO': entrego,
                                    'FIRMA': firmaBase64,
                                    'FECHA_ENTREGA':
                                        DateTime.now().toIso8601String(),
                                    'ESTATUS ACTUAL': 'ENTREGADO',
                                  })
                              .toList();
                          // Guardar en entregas mkp page (agregar a colección entregas/mkp/items)
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
                          // Eliminar seleccionados de la lista local
                          setState(() {
                            _pendientes
                                .removeWhere((e) => seleccionados.contains(e));
                            _seleccionados.clear();
                          });
                          // Limpiar cache y Firestore de pendientes
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
                  child: guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
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
    final totalPendientes = _pendientes.length;
    final seleccionadosCount = _seleccionados.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recolectar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.blueGrey[900],
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
                          const SizedBox(height: 8),
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListView.separated(
                                itemCount: _pendientes.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1, color: Colors.blueGrey[100]),
                                itemBuilder: (context, idx) {
                                  final item = _pendientes[idx];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: _seleccionados.contains(idx)
                                          ? Colors.green.withOpacity(0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: CheckboxListTile(
                                      value: _seleccionados.contains(idx),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _seleccionados.add(idx);
                                          } else {
                                            _seleccionados.remove(idx);
                                          }
                                        });
                                      },
                                      title: Text(
                                        item['NOMBRE CENTRO'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
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
  }
}
// Fin de _RecolectarPageState
