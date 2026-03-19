import 'package:flutter/material.dart';
import 'entregas_mbodas_page.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import '../../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DevMbodasPage extends StatefulWidget {
  final String usuario;
  const DevMbodasPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<DevMbodasPage> createState() => _DevMbodasPageState();
}

class _DevMbodasPageState extends State<DevMbodasPage> {
  void _addRow() {
    setState(() {
      final ctrls =
          List.generate(_headers.length, (_) => TextEditingController());
      final idxMbodas = _headers.indexOf('MBODAS');
      final idxSku = _headers.indexOf('SKU');
      if (idxMbodas != -1 &&
          idxSku != -1 &&
          ctrls[idxSku].text.trim().isNotEmpty) {
        ctrls[idxMbodas].text = 'Fisico';
      }
      _rows.add(ctrls);
    });
  }

  void _buscarYMarcarLP(String codigo) {
    final idxLP = _headers.indexOf('LP');
    final idxSeccion = _headers.indexOf('SECCION');
    final idxJefatura = _headers.indexOf('JEFATURA');
    final idxValidacion = _headers.indexOf('VALIDACION');
    setState(() {
      _scanSeccion = '';
      _scanDepartamento = '';
    });
    bool encontrado = false;
    String normalizarLP(String lp) => lp.replaceFirst(RegExp(r'^0+'), '');
    final codigoNorm = normalizarLP(codigo);
    for (final row in _rows) {
      if (idxLP != -1 && normalizarLP(row[idxLP].text.trim()) == codigoNorm) {
        final seccion = idxSeccion != -1 ? row[idxSeccion].text.trim() : '';
        final jefaturaNombre =
            idxJefatura != -1 ? row[idxJefatura].text.trim() : '';
        if (idxValidacion != -1) {
          row[idxValidacion].text = '✔️';
        }
        _scanSeccion = seccion;
        _scanDepartamento = jefaturaNombre;
        encontrado = true;
        break;
      }
    }
    if (encontrado) {
      setState(() {});
    }
    Future.delayed(const Duration(milliseconds: 100), () {
      _scanController.clear();
      _scanFocus.requestFocus();
    });
  }

  bool _listenerAgregado = false;
  List<Map<String, dynamic>> _ultimaEntregaGuardada = [];
  DateTime? _ultimaFechaEntrega;
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocus = FocusNode();
  String _scanSeccion = '';
  String _scanDepartamento = '';
  final List<String> _headers = [
    // 'LP',
    'MBODAS',
    'SKU',
    'DESCRIPCION',
    'CANTIDAD',
    'SECCION',
    'JEFATURA',
    // 'VALIDACION',
    // 'BOX',
  ];
  final List<List<TextEditingController>> _rows = [];

  Future<void> _buscarJefaturaFirestore(
      String seccion, Function(String) onResult) async {
    final doc = await FirebaseFirestore.instance
        .collection('plantilla_ejecutiva')
        .doc('datos')
        .get();
    if (doc.exists && doc.data() != null) {
      final datos = doc.data()!['datos'] as List<dynamic>?;
      if (datos != null) {
        for (final fila in datos) {
          if (fila is Map<String, dynamic> &&
              fila['SECCION'].toString().trim().toUpperCase() ==
                  seccion.trim().toUpperCase()) {
            onResult(fila['NOMBRE']?.toString() ?? '');
            return;
          }
        }
      }
    }
    onResult('');
  }

  List<Map<String, dynamic>> _generarEntregaActual() {
    return _rows.map((row) {
      Map<String, dynamic> map = {};
      for (int i = 0; i < _headers.length; i++) {
        map[_headers[i]] = row[i].text;
      }
      return map;
    }).toList();
  }

  bool _esMismaEntrega(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toString() != b[i].toString()) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !_listenerAgregado) {
      html.window.onBeforeUnload.listen((event) {
        if (!_esMismaEntrega(_ultimaEntregaGuardada, _generarEntregaActual())) {
          js.context.callMethod('eval', [
            "window.event.returnValue = 'Advertencia: Si sales sin guardar los datos de MBODAS se perderán.';"
          ]);
        }
      });
      _listenerAgregado = true;
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scanFocus.dispose();
    for (var row in _rows) {
      for (var ctrl in row) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  void _importFromExcel() {
    if (!kIsWeb) return;
    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) async {
        await _procesarExcel(reader.result);
      });
    });
  }

  Future<void> _procesarExcel(Object? result) async {
    final Uint8List bytes =
        result is ByteBuffer ? result.asUint8List() : (result as Uint8List);
    final excel = ex.Excel.decodeBytes(bytes);
    final List<List<String>> datos = [];
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        // Solo tomar SKU, DESCRIPCION, CANTIDAD y SECCION
        final fila = <String>[];
        final sku = row.length > 0 && row[0] != null
            ? row[0]?.value?.toString() ?? ''
            : '';
        final descripcion = row.length > 1 && row[1] != null
            ? row[1]?.value?.toString() ?? ''
            : '';
        final cantidad = row.length > 2 && row[2] != null
            ? row[2]?.value?.toString() ?? ''
            : '';
        final seccion = row.length > 3 && row[3] != null
            ? row[3]?.value?.toString() ?? ''
            : '';
        // El orden debe coincidir con _headers
        fila.add(sku.isNotEmpty ? 'Fisico' : ''); // MBODAS: Fisico si hay SKU
        fila.add(sku);
        fila.add(descripcion);
        fila.add(cantidad);
        fila.add(seccion);
        fila.add(''); // JEFATURA vacío, se llenará luego
        datos.add(fila);
      }
      break;
    }
    // Procesar filas de forma asíncrona y luego hacer un solo setState
    List<List<TextEditingController>> nuevasFilas = [];
    for (final fila in datos) {
      final List<TextEditingController> ctrls =
          List.generate(_headers.length, (i) {
        final ctrl = TextEditingController();
        ctrl.text = i < fila.length ? fila[i] : '';
        return ctrl;
      });
      // Si SKU tiene datos y MBODAS está vacío, poner Fisico
      final idxMbodas = _headers.indexOf('MBODAS');
      final idxSku = _headers.indexOf('SKU');
      if (idxMbodas != -1 &&
          idxSku != -1 &&
          ctrls[idxMbodas].text.isEmpty &&
          ctrls[idxSku].text.trim().isNotEmpty) {
        ctrls[idxMbodas].text = 'Fisico';
      }
      final idxSeccion = _headers.indexOf('SECCION');
      final idxJefatura = _headers.indexOf('JEFATURA');
      if (idxSeccion != -1 && idxJefatura != -1) {
        final seccion = ctrls[idxSeccion].text.trim();
        if (seccion.isNotEmpty) {
          await _buscarJefaturaFirestore(seccion, (nombre) {
            ctrls[idxJefatura].text = nombre;
          });
        }
      }
      nuevasFilas.add(ctrls);
    }
    if (nuevasFilas.isEmpty) {
      nuevasFilas
          .add(List.generate(_headers.length, (_) => TextEditingController()));
    }
    // Liberar memoria de filas previas y actualizar de una vez
    setState(() {
      for (var row in _rows) {
        for (var ctrl in row) {
          ctrl.dispose();
        }
      }
      _rows.clear();
      _rows.addAll(nuevasFilas);
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnóstico de importación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Encabezados detectados:'),
            SelectableText(_headers.join(', ')),
            const SizedBox(height: 8),
            Text('Filas importadas: ${_rows.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // (Eliminado el bloque duplicado y fuera de lugar)
  Future<void> _guardarMbodasYNotificar() async {
    final items = _rows.map((row) {
      Map<String, dynamic> map = {};
      for (int i = 0; i < _headers.length; i++) {
        map[_headers[i]] = row[i].text;
      }
      map['usuarioValido'] = widget.usuario;
      return map;
    }).toList();

    final idxBox = _headers.indexOf('BOX');
    final filasFaltantes = <Map<String, dynamic>>[];
    for (final row in _rows) {
      if (idxBox != -1 &&
          (row[idxBox].text.trim().toUpperCase() == 'FALTANTE' ||
              row[idxBox].text.trim().toUpperCase() == 'X')) {
        Map<String, dynamic> map = {};
        for (int i = 0; i < _headers.length; i++) {
          map[_headers[i]] = row[i].text;
        }
        filasFaltantes.add(map);
      }
    }

    // Guardar MBODAS
    try {
      await guardarDatosFirestoreYCache('entregas', 'mbodas', {'items': items});
      setState(() {
        _ultimaFechaEntrega = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información guardada en MBODAS.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error guardando en Firestore: $e'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Notificación de faltantes: crear documento individual para cada fila faltante y para ambos usuarios
    if (filasFaltantes.isNotEmpty) {
      try {
        final firestore = FirebaseFirestore.instance;
        for (final map in filasFaltantes) {
          for (final destino in ['ADMIN OMNICANAL', 'ADMIN ENVIOS']) {
            final notifRef = await firestore.collection('notificaciones').add({
              'mensaje': 'FALTANTE MBODAS',
              'fecha': DateTime.now(),
              'leida': false,
              'para': destino,
              'detalle': map,
            });
            await notifRef.update({'id': notifRef.id});
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Notificación de faltantes enviada a la campana para ambos usuarios.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error notificando faltantes: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileSmall = MediaQuery.of(context).size.shortestSide <= 600;
    return WillPopScope(
      onWillPop: () async {
        if (!_esMismaEntrega(_ultimaEntregaGuardada, _generarEntregaActual())) {
          final salir = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Advertencia'),
              content: const Text(
                  'Si sales sin guardar los datos de MBODAS se perderán. ¿Seguro que quieres salir?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Salir'),
                ),
              ],
            ),
          );
          return salir == true;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F9F6),
        appBar: AppBar(
          title: Row(
            children: const [
              Icon(Icons.cake, color: Color(0xFF2D6A4F), size: 28),
              SizedBox(width: 10),
              Text(
                'Dev Mbodas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: Color(0xFF2D6A4F),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFE9ECEF),
          elevation: 0,
        ),
        body: isMobileSmall
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Ver Entregas MBODAS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 18),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                EntregasMbodasPage(usuario: widget.usuario),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    // Botones de proceso MBODAS
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _importFromExcel,
                          child: const Text('Importar Excel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _guardarMbodasYNotificar,
                          child: const Text('Guardar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addRow,
                          child: const Text('Agregar fila'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EntregasMbodasPage(usuario: widget.usuario),
                              ),
                            );
                          },
                          child: const Text('Ver entregas MBODAS'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _headers.length * 140,
                          child: Column(
                            children: [
                              Container(
                                color: const Color(0xFFE9ECEF),
                                child: Row(
                                  children: List.generate(_headers.length, (i) {
                                    // Ocultar LP, VALIDACION y BOX
                                    if (_headers[i] == 'LP' ||
                                        _headers[i] == 'VALIDACION' ||
                                        _headers[i] == 'BOX') {
                                      return const SizedBox.shrink();
                                    }
                                    final isJefatura =
                                        _headers[i] == 'JEFATURA';
                                    return Expanded(
                                      flex: isJefatura ? 2 : 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: const Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            left: i == 0
                                                ? const BorderSide(
                                                    color: Color(0xFFBDBDBD),
                                                    width: 1)
                                                : BorderSide.none,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _headers[i],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              letterSpacing: 0.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _rows.length,
                                  itemBuilder: (context, rowIdx) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: const Border(
                                          bottom: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1),
                                        ),
                                      ),
                                      child: Row(
                                        children: List.generate(_headers.length,
                                            (colIdx) {
                                          // Ocultar LP, VALIDACION y BOX
                                          if (_headers[colIdx] == 'LP' ||
                                              _headers[colIdx] ==
                                                  'VALIDACION' ||
                                              _headers[colIdx] == 'BOX') {
                                            return const SizedBox.shrink();
                                          }
                                          final isJefatura =
                                              _headers[colIdx] == 'JEFATURA';
                                          final isSeccion =
                                              _headers[colIdx] == 'SECCION';
                                          final isMbodas =
                                              _headers[colIdx] == 'MBODAS';
                                          return Expanded(
                                            flex: isJefatura ? 2 : 1,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(
                                                    color:
                                                        const Color(0xFFBDBDBD),
                                                    width: 1,
                                                  ),
                                                  left: colIdx == 0
                                                      ? const BorderSide(
                                                          color:
                                                              Color(0xFFBDBDBD),
                                                          width: 1)
                                                      : BorderSide.none,
                                                ),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 2),
                                                child: isJefatura
                                                    ? Center(
                                                        child: Text(
                                                          _rows[rowIdx][colIdx]
                                                              .text,
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xFF2D6A4F)),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      )
                                                    : isMbodas
                                                        ? DropdownButton<
                                                            String>(
                                                            value: _rows[rowIdx]
                                                                        [colIdx]
                                                                    .text
                                                                    .isEmpty
                                                                ? null
                                                                : _rows[rowIdx]
                                                                        [colIdx]
                                                                    .text,
                                                            isExpanded: true,
                                                            underline: SizedBox
                                                                .shrink(),
                                                            items: const [
                                                              DropdownMenuItem(
                                                                  value:
                                                                      'Fisico',
                                                                  child: Text(
                                                                      'Fisico')),
                                                              DropdownMenuItem(
                                                                  value:
                                                                      'Virtual',
                                                                  child: Text(
                                                                      'Virtual')),
                                                            ],
                                                            onChanged: (value) {
                                                              setState(() {
                                                                _rows[rowIdx][
                                                                            colIdx]
                                                                        .text =
                                                                    value ?? '';
                                                              });
                                                            },
                                                          )
                                                        : isSeccion
                                                            ? TextField(
                                                                controller:
                                                                    _rows[rowIdx]
                                                                        [
                                                                        colIdx],
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                decoration:
                                                                    const InputDecoration(
                                                                  border:
                                                                      InputBorder
                                                                          .none,
                                                                  isDense: true,
                                                                  contentPadding:
                                                                      EdgeInsets.symmetric(
                                                                          vertical:
                                                                              8,
                                                                          horizontal:
                                                                              4),
                                                                ),
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            14),
                                                                onChanged:
                                                                    (value) async {
                                                                  await _buscarJefaturaFirestore(
                                                                      value
                                                                          .trim(),
                                                                      (jefatura) {
                                                                    setState(
                                                                        () {
                                                                      _rows[rowIdx][_headers.indexOf('JEFATURA')]
                                                                              .text =
                                                                          jefatura;
                                                                    });
                                                                  });
                                                                },
                                                              )
                                                            : TextField(
                                                                controller:
                                                                    _rows[rowIdx]
                                                                        [
                                                                        colIdx],
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                decoration:
                                                                    const InputDecoration(
                                                                  border:
                                                                      InputBorder
                                                                          .none,
                                                                  isDense: true,
                                                                  contentPadding:
                                                                      EdgeInsets.symmetric(
                                                                          vertical:
                                                                              8,
                                                                          horizontal:
                                                                              4),
                                                                ),
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            14),
                                                              ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
