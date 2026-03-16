import 'package:flutter/material.dart';
import 'entregas_devcan_page.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DevCanPage extends StatefulWidget {
  const DevCanPage({Key? key}) : super(key: key);

  @override
  State<DevCanPage> createState() => _DevCanPageState();
}

class _DevCanPageState extends State<DevCanPage> {
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

  // Datos de plantilla ejecutiva (simulación, se debe cargar igual que en plantilla ejecutiva)
  List<List<String>> plantillaEjecutivaDatos = [];

  // Cargar datos de plantilla ejecutiva desde localStorage
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
  void initState() {
    super.initState();
    _cargarPlantillaEjecutiva();
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
    for (final row in _rows) {
      if (idxLP != -1 && row[idxLP].text.trim() == codigo) {
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
                  ? row[i]?.value?.toString() ?? ''
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
              ctrl.text = i < fila.length ? fila[i] : '';
              return ctrl;
            });
            // Si hay valor en SECCION, buscar y asignar JEFATURA automáticamente
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
        print('Filas importadas: \n' + _rows.length.toString());
        setState(() {}); // Forzar reconstrucción tras importación
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
                Text('Filas importadas: \\${_rows.length}'),
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

  Future<void> _enviarAEntregasDevCan() async {
    print('[DEBUG] _enviarAEntregasDevCan llamado');
    final idxValidacion = _headers.indexOf('VALIDACION');
    final idxBox = _headers.indexOf('BOX');
    List<int> filasIncompletas = [];
    List<int> filasFaltantes = [];

    // Validar filas (solo advertir, no bloquear)
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final val = idxValidacion != -1 ? row[idxValidacion].text.trim() : '';
      print('[DEBUG] Fila \\${i + 1} VALIDACION: "' + val + '"');
      if (idxValidacion != -1 && val != '✔️') {
        filasIncompletas.add(i + 1);
      }
      if (idxBox != -1 &&
          (row[idxBox].text.trim().toUpperCase() == 'FALTANTE' ||
              row[idxBox].text.trim().toUpperCase() == 'X')) {
        filasFaltantes.add(i + 1);
      }
    }
    print('[DEBUG] Filas incompletas: ' + filasIncompletas.toString());

    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay filas para procesar.')),
      );
      print('[DEBUG] No hay filas para procesar.');
      return;
    }

    // Si hay filas incompletas, advertir pero permitir continuar
    if (filasIncompletas.isNotEmpty) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Advertencia'),
          content: Text(
              'Hay filas sin validar (VALIDACION sin paloma):\nFilas: \\${filasIncompletas.join(', ')}\n¿Deseas continuar y guardar de todos modos?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar de todos modos'),
            ),
          ],
        ),
      );
      if (continuar != true) {
        return;
      }
    }

    // Si hay faltantes, notificar antes de guardar
    if (filasFaltantes.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Advertencia de faltantes'),
          content: Text(
              'Hay filas marcadas como FALTANTE en BOX:\nFilas: \\${filasFaltantes.join(', ')}\n\nSe notificará a los usuarios ADMIN OMNICANAL o ADMIN ENVIOS.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      try {
        await _guardarNotificacionFaltantes(filasFaltantes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificación de faltantes enviada.')),
        );
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al notificar faltantes: \\${e.toString()}')),
        );
        return;
      }
    }

    // Construir lista de entregas válidas
    final entregasRecientes = _rows
        .where((row) => row.any((ctrl) => ctrl.text.trim().isNotEmpty))
        .map((row) {
      // Completar la fila si es más corta que headers
      if (row.length < _headers.length) {
        row.addAll(List.generate(
            _headers.length - row.length, (_) => TextEditingController()));
      }
      Map<String, dynamic> map = {};
      for (int i = 0; i < _headers.length; i++) {
        map[_headers[i]] = row[i].text;
      }
      return map;
    }).toList();

    if (entregasRecientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para enviar a entregas.')),
      );
      return;
    }

    // Guardar en Firestore
    try {
      print('[DEBUG] Intentando guardar en Firestore:');
      print(entregasRecientes);
      // Guardar cada entrega como documento individual en la colección 'entregas_devcan'
      final batch = FirebaseFirestore.instance.batch();
      final collection =
          FirebaseFirestore.instance.collection('entregas_devcan');
      for (final entrega in entregasRecientes) {
        final docRef = collection.doc();
        batch.set(docRef, entrega);
      }
      await batch.commit();
      print('[DEBUG] Guardado exitoso en Firestore (entregas_devcan).');
      setState(() {
        _ultimaFechaEntrega = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('¡Datos guardados correctamente en entregas_devcan!')),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              EntregasDevCanPage(entregasRecientes: entregasRecientes),
        ),
      );
    } catch (e, st) {
      print('[ERROR] Error al guardar en Firestore:');
      print(e);
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error al guardar en entregas_devcan: \\${e.toString()}')),
      );
    }
  }

  Future<void> _guardarNotificacionFaltantes(List<int> filasFaltantes) async {
    final datos = await leerDatosConCache('notificaciones', 'password');
    List<dynamic> lista = [];
    if (datos != null && datos['items'] != null) {
      lista = List<dynamic>.from(datos['items']);
    }
    for (final idx in filasFaltantes) {
      final row = _rows[idx - 1];
      final detalle = _headers
          .asMap()
          .entries
          .map((e) => '${e.value}: ${row[e.key].text}')
          .join('\n');
      lista.add({
        'usuario': 'ADMIN OMNICANAL / ADMIN ENVIOS',
        'fecha': DateTime.now().toIso8601String(),
        'mensaje': 'FALTANTE DevCan',
        'detalle': detalle,
      });
    }
    await guardarDatosFirestoreYCache(
        'notificaciones', 'password', {'items': lista});

    // Construir lista de entregas recientes para pasar a la nueva página
    List<Map<String, dynamic>> entregasRecientes = _rows.map((row) {
      Map<String, dynamic> map = {};
      for (int i = 0; i < _headers.length; i++) {
        map[_headers[i]] = row[i].text;
      }
      return map;
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            EntregasDevCanPage(entregasRecientes: entregasRecientes),
      ),
    );
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
                  ElevatedButton.icon(
                    onPressed: () async {
                      print(
                          '[DEBUG] Botón Enviar a Entregas DevCan presionado');
                      await _cargarUltimaEntregaGuardada();
                      final actual = _generarEntregaActual();
                      if (_esMismaEntrega(_ultimaEntregaGuardada, actual)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'La información que quieres enviar ya fue enviada.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      await _enviarAEntregasDevCan();
                      await _cargarUltimaEntregaGuardada();
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar a Entregas DevCan'),
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
                      onPressed: () async {
                        try {
                          final datos =
                              await leerDatosConCache('entregas', 'devcan');
                          final items =
                              (datos != null && datos['items'] is List)
                                  ? datos['items'] as List
                                  : null;
                          final entregas = (items != null)
                              ? items
                                  .map((e) =>
                                      Map<String, dynamic>.from(e as Map))
                                  .toList()
                              : <Map<String, dynamic>>[];
                          if (entregas.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'No hay entregas guardadas para mostrar.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EntregasDevCanPage(
                                  entregasRecientes: entregas),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Error al leer entregas: \\${e.toString()}')),
                          );
                        }
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
