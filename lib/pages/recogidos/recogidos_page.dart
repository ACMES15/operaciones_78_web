import 'package:flutter/material.dart';
import 'entregas_recogidos_page.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecogidosPage extends StatefulWidget {
  final String usuario;
  const RecogidosPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<RecogidosPage> createState() => _RecogidosPageState();
}

class _RecogidosPageState extends State<RecogidosPage> {
  bool _listenerAgregado = false;
  List<Map<String, dynamic>> _ultimaEntregaGuardada = [];

  Future<void> _cargarUltimaEntregaGuardada() async {
    final datos = await leerDatosConCache('entregas', 'recogidos');
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
  // List<Map<String, dynamic>> _entregasRecientes = [];
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

  List<List<String>> plantillaEjecutivaDatos = [];

  void _cargarPlantillaEjecutiva() {
    final encoded = html.window.localStorage['plantilla_ejecutiva_datos'];
    if (encoded != null && encoded.isNotEmpty) {
      final filas = encoded
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() {
        plantillaEjecutivaDatos = filas.map((f) => f.split('|')).toList();
      });
    }
  }

  void _addRow() {
    setState(() {
      _rows.add(List.generate(10, (_) => TextEditingController()));
    });
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
    final idxSeccion = _headers.indexOf('SECCION');
    final idxJefatura = _headers.indexOf('JEFATURA');
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
        final seccion = idxSeccion != -1 ? row[idxSeccion].text.trim() : '';
        String jefaturaNombre =
            idxJefatura != -1 ? row[idxJefatura].text.trim() : '';
        // Buscar en plantillaEjecutivaDatos si es un código
        if (jefaturaNombre.isNotEmpty && plantillaEjecutivaDatos.isNotEmpty) {
          // Buscar por código en la plantilla ejecutiva (asumiendo que la columna 0 es código y la 1 es nombre)
          final match = plantillaEjecutivaDatos.firstWhere(
            (fila) => fila.isNotEmpty && fila[0].trim() == jefaturaNombre,
            orElse: () => [],
          );
          if (match.isNotEmpty && match.length > 1) {
            jefaturaNombre = match[1].trim();
          }
        }
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
    if (!kIsWeb) return;
    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) {
        final result = reader.result;
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
                  ? row[i]?.value?.toString() ?? ''
                  : '',
            );
            datos.add(fila);
          }
          break;
        }
        setState(() {
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
            final idxSeccion = _headers.indexOf('SECCION');
            final idxJefatura = _headers.indexOf('JEFATURA');
            if (idxSeccion != -1 && idxJefatura != -1) {
              final seccion = ctrls[idxSeccion].text.trim();
              if (seccion.isNotEmpty) {
                String jefatura = '';
                for (final filaEjecutiva in plantillaEjecutivaDatos) {
                  final idxSec =
                      filaEjecutiva.indexWhere((e) => e.trim() == seccion);
                  if (idxSec != -1 && filaEjecutiva.length > idxSec + 1) {
                    jefatura = filaEjecutiva[idxSec + 1];
                    break;
                  }
                }
                ctrls[idxJefatura].text = jefatura;
              }
            }
            _rows.add(ctrls);
          }
          if (_rows.isEmpty) {
            _rows.add(
                List.generate(_headers.length, (_) => TextEditingController()));
          }
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
      });
    });
  }

  // The old function _enviarAEntregasRecogidos has been replaced by _guardarEntregasYNotificar

  Future<void> _guardarEntregasYNotificar() async {
    final idxValidacion = _headers.indexOf('VALIDACION');
    final idxBox = _headers.indexOf('BOX');
    List<int> filasIncompletas = [];
    List<int> filasFaltantes = [];

    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (idxValidacion != -1 && row[idxValidacion].text.trim() != '✔️') {
        filasIncompletas.add(i + 1);
      }
      if (idxBox != -1 &&
          (row[idxBox].text.trim().toUpperCase() == 'FALTANTE' ||
              row[idxBox].text.trim().toUpperCase() == 'X')) {
        filasFaltantes.add(i + 1);
      }
    }

    if (filasIncompletas.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Advertencia'),
          content: Text(
              'Hay filas sin validar (VALIDACION en blanco o sin paloma):\nFilas: ${filasIncompletas.join(', ')}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    if (filasFaltantes.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Advertencia de faltantes'),
          content: Text(
              'Hay filas marcadas como FALTANTE en BOX:\nFilas: ${filasFaltantes.join(', ')}\n\nSe notificará a los usuarios ADMIN OMNICANAL y ADMIN ENVIOS.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    }

    // Construir lista de entregas con usuarioValido
    List<Map<String, dynamic>> entregasRecientes = _rows.map((row) {
      Map<String, dynamic> map = {};
      for (int i = 0; i < _headers.length; i++) {
        map[_headers[i]] = row[i].text;
      }
      map['usuarioValido'] = widget.usuario;
      return map;
    }).toList();

    // Guardar entregas en Firestore
    try {
      await guardarDatosFirestoreYCache(
          'entregas', 'recogidos', {'items': entregasRecientes});
      setState(() {
        _ultimaEntregaGuardada = entregasRecientes;
        _ultimaFechaEntrega = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información guardada en Recogidos.')),
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
        for (final idx in filasFaltantes) {
          final row = _rows[idx - 1];
          Map<String, dynamic> detalle = {};
          for (int i = 0; i < _headers.length; i++) {
            detalle[_headers[i]] = row[i].text;
          }
          detalle['usuarioValido'] = widget.usuario;
          for (final destino in ['ADMIN OMNICANAL', 'ADMIN ENVIOS']) {
            final notifRef = await firestore.collection('notificaciones').add({
              'mensaje': 'FALTANTE Recogidos',
              'fecha': DateTime.now(),
              'leida': false,
              'para': destino,
              'detalle': detalle,
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

    // No navegar automáticamente, solo mostrar snackbar de éxito/error
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
                  'Si sales sin enviar los datos a Recogidos se perderán los datos. ¿Seguro que quieres salir?'),
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
                  Icon(Icons.archive, color: Color(0xFF2D6A4F), size: 32),
                  SizedBox(width: 10),
                  Text(
                    'Recogidos',
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
                        ? 'Datos recientes\nÚltima subida: \\${_ultimaFechaEntrega}'
                        : 'No hay entregas recientes',
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final data =
                            prefs.getString('entregas_recogidos') ?? '[]';
                        List<dynamic> lista;
                        try {
                          lista = jsonDecode(data);
                        } catch (e) {
                          lista = [];
                        }
                        final entregas = lista
                            .map<Map<String, dynamic>>(
                                (e) => Map<String, dynamic>.from(e))
                            .toList();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EntregasRecogidosPage(
                                entregasRecientes: entregas),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment_turned_in),
                      label: const Text('Ver Entregas Recogidos'),
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
                                            String jefatura = '';
                                            for (final fila
                                                in plantillaEjecutivaDatos) {
                                              final idxSeccion =
                                                  fila.indexWhere((e) =>
                                                      e.trim() == value.trim());
                                              if (idxSeccion != -1) {
                                                if (fila.length >
                                                    idxSeccion + 1) {
                                                  jefatura =
                                                      fila[idxSeccion + 1];
                                                }
                                                break;
                                              }
                                            }
                                            setState(() {
                                              _rows[rowIdx][_headers
                                                      .indexOf('JEFATURA')]
                                                  .text = jefatura;
                                            });
                                          },
                                        ),
                                      );
                                    } else if (isValidacion) {
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
