import 'package:flutter/material.dart';
import 'entregas_devcan_page.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import '../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DevCanPage extends StatefulWidget {
  final String usuario;
  const DevCanPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<DevCanPage> createState() => _DevCanPageState();
}

class _DevCanPageState extends State<DevCanPage> {
  Future<void> _guardarEntregasYNotificar() async {
    final items = _rows.map((row) {
      Map<String, dynamic> map = {};
      for (int i = 0; i < _headers.length; i++) {
        map[_headers[i]] = row[i].text;
      }
      // Agregar usuarioValido automáticamente
      map['usuarioValido'] = widget.usuario;
      return map;
    }).toList();

    // Buscar filas con FALTANTE en BOX
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

    // Guardar entregas
    try {
      await guardarDatosFirestoreYCache('entregas', 'devcan', {'items': items});
      setState(() {
        _ultimaFechaEntrega = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información guardada en entregas.')),
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
              'mensaje': 'FALTANTE DevCan',
              'fecha': DateTime.now(),
              'leida': false,
              'para': destino,
              'detalle': map, // todos los datos del faltante
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

  // Para evitar múltiples listeners en web
  bool _listenerAgregado = false;
  List<Map<String, dynamic>> _ultimaEntregaGuardada = [];

  Future<void> _cargarUltimaEntregaGuardada() async {
    final datos = await leerDatosConCache('entregas', 'devcan');
    if (datos != null && datos['items'] != null) {
      setState(() {
        _ultimaEntregaGuardada =
            List<Map<String, dynamic>>.from(datos['items']);
      });
    }
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
      if (!mapEquals(a[i], b[i])) return false;
    }
    return true;
  }

  DateTime? _ultimaFechaEntrega;
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocus = FocusNode();
  String _scanSeccion = '';
  String _scanDepartamento = '';
  final List<String> _headers = [
    'LP',
    'DEVOLUCION',
    'SKU',
    'DESCRIPCION',
    'CANTIDAD',
    'SECCION',
    'JEFATURA',
    'VALIDACION',
    'BOX'
  ];
  final List<List<TextEditingController>> _rows = [];

  // Buscar NOMBRE en plantilla_ejecutiva/datos por SECCION y ponerlo en JEFATURA
  Future<String> _buscarJefaturaFirestore(String seccion) async {
    if (seccion.isEmpty) return '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();
      final data = doc.data();
      if (data != null && data['datos'] is List) {
        final List<dynamic> lista = data['datos'];
        final encontrado = lista.firstWhere(
          (item) =>
              (item['SECCION'] != null
                  ? item['SECCION'].toString().trim()
                  : '') ==
              seccion.trim(),
          orElse: () => null,
        );
        if (encontrado != null && encontrado['NOMBRE'] != null) {
          return encontrado['NOMBRE'].toString();
        }
      }
    } catch (e) {
      print('Error buscando NOMBRE/JEFATURA en Firestore: $e');
    }
    return '';
  }

  void _addRow() {
    setState(() {
      _rows.add(List.generate(10, (_) => TextEditingController()));
    });
  }

  @override
  void initState() {
    super.initState();
    // Ya no se usa plantillaEjecutivaDatos, ahora todo es Firestore
    _cargarUltimaEntregaGuardada();

    // Advertencia al cerrar/navegar en web solo si hay datos sin enviar
    if (kIsWeb && !_listenerAgregado) {
      html.window.onBeforeUnload.listen((event) {
        if (!_esMismaEntrega(_ultimaEntregaGuardada, _generarEntregaActual())) {
          js.context.callMethod('eval', [
            "window.event.returnValue = 'Advertencia: Si sales sin enviar los datos a Entregas DevCan se perderán los datos.';"
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

  void _buscarYMarcarLP(String codigo) {
    final idxLP = _headers.indexOf('LP');
    final idxSeccionDevCan = _headers.indexOf('SECCION');
    final idxJefaturaDevCan = _headers.indexOf('JEFATURA');
    final idxValidacion = _headers.indexOf('VALIDACION');

    setState(() {
      _scanSeccion = '';
      _scanDepartamento = '';
    });

    bool encontrado = false;
    // Normalizar el código escaneado y el de la tabla quitando ceros a la izquierda para comparar
    String normalizarLP(String lp) => lp.replaceFirst(RegExp(r'^0+'), '');
    final codigoNorm = normalizarLP(codigo);
    for (final row in _rows) {
      if (idxLP != -1 && normalizarLP(row[idxLP].text.trim()) == codigoNorm) {
        final seccion =
            idxSeccionDevCan != -1 ? row[idxSeccionDevCan].text.trim() : '';
        final jefaturaNombre =
            idxJefaturaDevCan != -1 ? row[idxJefaturaDevCan].text.trim() : '';
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

  void _importFromExcel() {
    if (!kIsWeb) return; // Solo para web
    print('Abriendo selector de archivos...');
    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      print('Evento onChange disparado.');
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) async {
        final result = reader.result;
        // reader.result can be ByteBuffer or Uint8List depending on browser
        final Uint8List bytes =
            result is ByteBuffer ? result.asUint8List() : (result as Uint8List);
        final excel = ex.Excel.decodeBytes(bytes);
        final List<List<String>> datos = [];
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;
          for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
            final row = sheet.row(rowIndex);
            final fila = List<String>.generate(
              _headers.length,
              (i) => i < row.length && row[i] != null
                  ? row[i]!.value.toString()
                  : '',
            );
            datos.add(fila);
          }
          break; // Solo la primera hoja
        }
        // Limpiar filas previas y liberar memoria
        for (var row in _rows) {
          for (var ctrl in row) {
            ctrl.dispose();
          }
        }
        List<List<TextEditingController>> nuevasFilas = [];
        for (final fila in datos) {
          final List<TextEditingController> ctrls =
              List.generate(_headers.length, (i) {
            final ctrl = TextEditingController();
            // Si es la columna LP, rellenar a 10 dígitos
            if (_headers[i] == 'LP' && i < fila.length) {
              final lp = fila[i].padLeft(10, '0');
              ctrl.text = lp;
            } else {
              ctrl.text = i < fila.length ? fila[i] : '';
            }
            return ctrl;
          });
          // Si hay valor en SECCION, buscar y asignar JEFATURA automáticamente desde Firestore
          final idxSeccion = _headers.indexOf('SECCION');
          final idxJefatura = _headers.indexOf('JEFATURA');
          if (idxSeccion != -1 && idxJefatura != -1) {
            final seccion = ctrls[idxSeccion].text.trim();
            if (seccion.isNotEmpty) {
              final jefatura = await _buscarJefaturaFirestore(seccion);
              ctrls[idxJefatura].text = jefatura;
            }
          }
          nuevasFilas.add(ctrls);
        }
        if (nuevasFilas.isEmpty) {
          nuevasFilas.add(
              List.generate(_headers.length, (_) => TextEditingController()));
        }
        setState(() {
          _rows.clear();
          _rows.addAll(nuevasFilas);
        });
        print('Filas importadas: \\n' + _rows.length.toString());
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
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_esMismaEntrega(_ultimaEntregaGuardada, _generarEntregaActual())) {
          final salir = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Advertencia'),
              content: const Text(
                  'Si sales sin enviar los datos a Entregas DevCan se perderán los datos. ¿Seguro que quieres salir?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
          return salir ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'DevCan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25,
              color: Color(0xFF2D6A4F),
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.left,
          ),
          centerTitle: true,
          backgroundColor: Color(0xFFE9ECEF),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Campo escáner LP
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _scanController,
                      focusNode: _scanFocus,
                      decoration: const InputDecoration(
                        labelText: 'Escanear código LP',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (codigo) {
                        _buscarYMarcarLP(codigo.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        _buscarYMarcarLP(_scanController.text.trim()),
                    child: const Text('Buscar LP'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Botones de proceso DevCan
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _importFromExcel,
                    child: const Text('Importar Excel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _guardarEntregasYNotificar,
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
                              EntregasDevCanPage(usuario: widget.usuario),
                        ),
                      );
                    },
                    child: const Text('Ver entregas DevCan'),
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
                              final isJefatura = _headers[i] == 'JEFATURA';
                              return Expanded(
                                flex: isJefatura ? 2 : 1,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                        color: Color(0xFFBDBDBD), width: 1),
                                  ),
                                ),
                                child: Row(
                                  children:
                                      List.generate(_headers.length, (colIdx) {
                                    final isJefatura =
                                        _headers[colIdx] == 'JEFATURA';
                                    final isSeccion =
                                        _headers[colIdx] == 'SECCION';
                                    final isValidacion =
                                        _headers[colIdx] == 'VALIDACION';
                                    final isBox = _headers[colIdx] == 'BOX';
                                    return Expanded(
                                      flex: isJefatura ? 2 : 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: const Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            left: colIdx == 0
                                                ? const BorderSide(
                                                    color: Color(0xFFBDBDBD),
                                                    width: 1)
                                                : BorderSide.none,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6, horizontal: 2),
                                          child: isBox
                                              ? Checkbox(
                                                  value: _rows[rowIdx][colIdx]
                                                          .text
                                                          .trim()
                                                          .toUpperCase() ==
                                                      'FALTANTE',
                                                  onChanged: (checked) {
                                                    setState(() {
                                                      _rows[rowIdx][colIdx]
                                                              .text =
                                                          checked!
                                                              ? 'FALTANTE'
                                                              : '';
                                                    });
                                                  },
                                                )
                                              : isJefatura
                                                  ? Center(
                                                      child: Text(
                                                        _rows[rowIdx][colIdx]
                                                            .text,
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF2D6A4F)),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    )
                                                  : isSeccion
                                                      ? TextField(
                                                          controller:
                                                              _rows[rowIdx]
                                                                  [colIdx],
                                                          textAlign:
                                                              TextAlign.center,
                                                          decoration:
                                                              const InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            isDense: true,
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        vertical:
                                                                            8,
                                                                        horizontal:
                                                                            4),
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 14),
                                                          onChanged:
                                                              (value) async {
                                                            final jefatura =
                                                                await _buscarJefaturaFirestore(
                                                                    value
                                                                        .trim());
                                                            setState(() {
                                                              _rows[rowIdx][_headers
                                                                      .indexOf(
                                                                          'JEFATURA')]
                                                                  .text = jefatura;
                                                            });
                                                          },
                                                        )
                                                      : isValidacion
                                                          ? (_rows[rowIdx][
                                                                          colIdx]
                                                                      .text
                                                                      .trim() ==
                                                                  '✔️'
                                                              ? const Icon(
                                                                  Icons.check,
                                                                  color: Colors
                                                                      .green,
                                                                  size: 24)
                                                              : TextField(
                                                                  controller: _rows[
                                                                          rowIdx]
                                                                      [colIdx],
                                                                  decoration:
                                                                      const InputDecoration(
                                                                    border:
                                                                        InputBorder
                                                                            .none,
                                                                    isDense:
                                                                        true,
                                                                    contentPadding: EdgeInsets.symmetric(
                                                                        vertical:
                                                                            8,
                                                                        horizontal:
                                                                            4),
                                                                  ),
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                                ))
                                                          : TextField(
                                                              controller:
                                                                  _rows[rowIdx]
                                                                      [colIdx],
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
