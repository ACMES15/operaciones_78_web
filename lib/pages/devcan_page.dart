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
      reader.onLoadEnd.listen((event) {
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
        setState(() {
          // Limpiar filas previas y liberar memoria
          for (var row in _rows) {
            for (var ctrl in row) {
              ctrl.dispose();
            }
          }
          _rows.clear();
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
                ctrls[idxJefatura].text = '';
                _buscarJefaturaFirestore(seccion).then((jefatura) {
                  if (jefatura.isNotEmpty) {
                    ctrls[idxJefatura].text = jefatura;
                  }
                });
              }
            }
            _rows.add(ctrls);
          }
          if (_rows.isEmpty) {
            _rows.add(
                List.generate(_headers.length, (_) => TextEditingController()));
          }
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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.assignment_return,
                      color: Color(0xFF2D6A4F), size: 32),
                  SizedBox(width: 10),
                  Text(
                    'Devoluciones y Cancelaciones',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFF2D6A4F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Campo de escaneo y resultados
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _scanController,
                      focusNode: _scanFocus,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Escanear código LP',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        _buscarYMarcarLP(value.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('SECCION:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 22)),
                          const SizedBox(width: 6),
                          Text(_scanSeccion,
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 22)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('JEFATURA:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 22)),
                          const SizedBox(width: 6),
                          Text(_scanDepartamento,
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 22)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar fila'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 224, 230, 227),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _importFromExcel,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Importar desde Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 216, 222, 220),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón Guardar se agregará aquí
                  ElevatedButton.icon(
                    onPressed: _guardarEntregasYNotificar,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: _ultimaFechaEntrega != null
                        ? 'Datos recientes\nÚltima subida: ${_ultimaFechaEntrega}'
                        : 'No hay entregas recientes',
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                EntregasDevCanPage(usuario: widget.usuario),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment_turned_in),
                      label: const Text('Ver Entregas DevCan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFBDBDBD),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: (_headers.length - 1) * 110 + 300,
                    child: Column(
                      children: [
                        // Encabezados fijos
                        Container(
                          color: const Color(0xFFE9ECEF),
                          child: Row(
                            children: List.generate(_headers.length, (i) {
                              final isJefatura = _headers[i] == 'JEFATURA';
                              return Container(
                                width: isJefatura ? 300 : 110,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: const Border(
                                    right: BorderSide(
                                      color: Color(0xFFBDBDBD),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _headers[i],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }),
                          ),
                        ),
                        // Lista de filas
                        Expanded(
                          child: ListView.builder(
                              itemCount: _rows.length,
                              itemBuilder: (context, rowIdx) {
                                return Row(
                                  children:
                                      List.generate(_headers.length, (colIdx) {
                                    final isJefatura =
                                        _headers[colIdx] == 'JEFATURA';
                                    final isSeccion =
                                        _headers[colIdx] == 'SECCION';
                                    final isValidacion =
                                        _headers[colIdx] == 'VALIDACION';
                                    final isBox = _headers[colIdx] == 'BOX';
                                    final cellWidth =
                                        isJefatura ? 300.0 : 110.0;
                                    if (isJefatura) {
                                      // Mostrar el valor actual del controlador de JEFATURA (no editable)
                                      return Container(
                                        width: cellWidth,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border: const Border(
                                            right: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            bottom: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Text(
                                            _rows[rowIdx][colIdx].text,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2D6A4F)),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    } else if (isSeccion) {
                                      // TextField para SECCION, al cambiar busca y actualiza JEFATURA
                                      return Container(
                                        width: cellWidth,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border: const Border(
                                            right: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            bottom: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _rows[rowIdx][colIdx],
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    vertical: 8, horizontal: 4),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          onChanged: (value) {
                                            // Buscar JEFATURA en Firestore al editar SECCION
                                            _rows[rowIdx][_headers
                                                    .indexOf('JEFATURA')]
                                                .text = '';
                                            _buscarJefaturaFirestore(
                                                    value.trim())
                                                .then((jefatura) {
                                              setState(() {
                                                _rows[rowIdx][_headers
                                                        .indexOf('JEFATURA')]
                                                    .text = jefatura;
                                              });
                                            });
                                          },
                                        ),
                                      );
                                    } else if (isValidacion) {
                                      // VALIDACION: mostrar paloma y fondo verde si está validado
                                      final validado =
                                          _rows[rowIdx][colIdx].text.trim() ==
                                              '✔️';
                                      return Container(
                                        width: cellWidth,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: validado
                                              ? Colors.green[200]
                                              : null,
                                          border: const Border(
                                            right: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            bottom: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: validado
                                            ? const Icon(Icons.check,
                                                color: Colors.green, size: 24)
                                            : TextField(
                                                controller: _rows[rowIdx]
                                                    [colIdx],
                                                decoration:
                                                    const InputDecoration(
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 4),
                                                ),
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                      );
                                    } else if (isBox) {
                                      // Checkbox para marcar faltante
                                      return Container(
                                        width: cellWidth,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border: const Border(
                                            right: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            bottom: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Checkbox(
                                          value: _rows[rowIdx][colIdx]
                                                  .text
                                                  .trim()
                                                  .toUpperCase() ==
                                              'FALTANTE',
                                          onChanged: (checked) {
                                            setState(() {
                                              _rows[rowIdx][colIdx].text =
                                                  checked! ? 'FALTANTE' : '';
                                            });
                                          },
                                        ),
                                      );
                                    } else {
                                      // Otras columnas: TextField normal
                                      return Container(
                                        width: cellWidth,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border: const Border(
                                            right: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                            bottom: BorderSide(
                                              color: Color(0xFFBDBDBD),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _rows[rowIdx][colIdx],
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    vertical: 8, horizontal: 4),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }
                                  }),
                                );
                              }),
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
