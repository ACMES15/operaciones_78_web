import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:universal_html/html.dart' as html;
import 'hoja_de_ruta_extra_page.dart';
// import 'hoja_de_xd_historial_page.dart';
import '../models/hoja_de_xd_historial.dart';

/// Manager para historial de carta porte usando Firestore + caché
class CartaPorteHistorialManager {
  static const String coleccion = 'historial_carta_porte';

  /// Agrega una carta al historial (Firestore + caché)
  static Future<void> addCarta(Map<String, dynamic> carta) async {
    final docId = carta['NUMERO_CONTROL'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await guardarDatosFirestoreYCache(coleccion, docId, carta);
  }

  /// Carga todas las cartas del historial (solo caché, si no hay, busca en Firestore y cachea)
  static Future<List<Map<String, dynamic>>> loadAll() async {
    // Para mantener compatibilidad, podrías guardar una lista de IDs en caché
    final prefs = await SharedPreferences.getInstance();
    final idsRaw = prefs.getString('${coleccion}_ids');
    List<String> ids = [];
    if (idsRaw != null) {
      ids = List<String>.from(jsonDecode(idsRaw));
    }
    List<Map<String, dynamic>> cartas = [];
    for (final id in ids) {
      final data = await leerDatosConCache(coleccion, id);
      if (data != null) cartas.add(data);
    }
    return cartas;
  }

  /// Guarda el ID de la carta en la lista de historial
  static Future<void> addCartaId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final idsRaw = prefs.getString('${coleccion}_ids');
    List<String> ids =
        idsRaw != null ? List<String>.from(jsonDecode(idsRaw)) : [];
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setString('${coleccion}_ids', jsonEncode(ids));
    }
  }
}

String? _numeroControlActual;

// Genera el siguiente número de control único y consecutivo basado en historial
Future<String> _generarNumeroDeControl() async {
  // Cargar historial desde Firestore para evitar repeticiones
  final snapshot = await FirebaseFirestore.instance
      .collection('historial_carta_porte')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .get();
  int maxNum = 0;
  if (snapshot.docs.isNotEmpty) {
    final last = snapshot.docs.first.data();
    final lastNum = (last['NUMERO_CONTROL'] ?? '').toString();
    if (lastNum.startsWith('0078-CP-')) {
      final numStr = lastNum.replaceFirst('0078-CP-', '');
      final num = int.tryParse(numStr);
      if (num != null && num > maxNum) maxNum = num;
    }
  }
  return '0078-CP-${(maxNum + 1).toString().padLeft(2, '0')}';
}

class CartaPorteTable extends StatefulWidget {
  const CartaPorteTable({super.key});

  @override
  State<CartaPorteTable> createState() => _CartaPorteTableState();
}

class _CartaPorteTableState extends State<CartaPorteTable> {
  // Guardar carta porte en historial (Firestore + caché)
  Future<void> _guardarCartaPorteEnHistorial() async {
    try {
      if (_numeroControlActual == null) {
        _numeroControlActual = await _generarNumeroDeControl();
      }
      final Map<String, dynamic> carta = {
        'NUMERO_CONTROL': _numeroControlActual,
        'DESTINO': _destinoController.text.trim(),
        'CHOFER': _choferController.text.trim(),
        'UNIDAD': _unidadController.text.trim(),
        'RFC': _rfcController.text.trim(),
        'FECHA': _fechaActual,
        'CONCENTRADO': _controllers.isNotEmpty && _controllers[0].length > 10
            ? _controllers[0][10].text.trim()
            : '',
        'COLUMNS': _columns,
        'TABLE':
            _controllers.map((row) => row.map((c) => c.text).toList()).toList(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      await CartaPorteHistorialManager.addCarta(carta);
      await CartaPorteHistorialManager.addCartaId(_numeroControlActual!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Carta porte guardada en historial. Número de control: ${_numeroControlActual ?? ''}'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _numeroControlActual = null;
        // Limpiar campos principales
        _choferController.clear();
        _unidadController.clear();
        _destinoController.clear();
        _rfcController.clear();
        _choferSeleccionado = null;
        // Limpiar tabla
        for (var row in _controllers) {
          for (var c in row) {
            c.clear();
          }
        }
      });
    } on FirebaseException catch (e) {
      String msg = 'Error de Firebase: ';
      if (e.code == 'permission-denied') {
        msg += 'Permisos insuficientes para guardar en Firestore.';
      } else if (e.code == 'unavailable') {
        msg += 'No hay conexión con el servidor de Firestore.';
      } else {
        msg += e.message ?? e.code;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado al guardar en historial: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  final TextEditingController _rfcController = TextEditingController();
  List<Map<String, String>> _choferes = [];
  int? _choferSeleccionado;

  // Cargar choferes en tiempo real desde Firestore
  void _escucharChoferesRealtime() {
    FirebaseFirestore.instance
        .collection('choferes')
        .doc('main')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists &&
          snapshot.data() != null &&
          snapshot.data()!['items'] != null) {
        final items = snapshot.data()!['items'] as List;
        setState(() {
          _choferes = items
              .map<Map<String, String>>((e) => Map<String, String>.from(e))
              .toList();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _initControllers();
    final now = DateTime.now();
    _fechaActual =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _escucharChoferesRealtime();
  }

  Future<void> _guardarChoferes() async {
    // Guardar en Firestore y en caché local
    final Map<String, dynamic> data = {'items': _choferes};
    await guardarDatosFirestoreYCache('choferes', 'main', data);
  }

  void _mostrarDialogoChoferes() async {
    // Ya no es necesario cargar choferes manualmente, se sincronizan en tiempo real
    showDialog(
      context: context,
      builder: (context) {
        int? editingIndex;
        final nombreCtrl = TextEditingController();
        final rfcCtrl = TextEditingController();
        final telCtrl = TextEditingController();
        void limpiarCampos() {
          nombreCtrl.clear();
          rfcCtrl.clear();
          telCtrl.clear();
          editingIndex = null;
        }

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Base de Datos de Choferes'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _choferes.length,
                        itemBuilder: (context, idx) {
                          final chofer = _choferes[idx];
                          return ListTile(
                            title: Text(chofer['nombre'] ?? ''),
                            subtitle: Text(
                                'RFC: ${chofer['rfc'] ?? ''}\nTel: ${chofer['telefono'] ?? ''}'),
                            leading: Radio<int>(
                              value: idx,
                              groupValue: _choferSeleccionado,
                              onChanged: (val) {
                                setState(() {
                                  _choferSeleccionado = val;
                                });
                                Navigator.of(context).pop();
                              },
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    setStateDialog(() {
                                      nombreCtrl.text = chofer['nombre'] ?? '';
                                      rfcCtrl.text = chofer['rfc'] ?? '';
                                      telCtrl.text = chofer['telefono'] ?? '';
                                      editingIndex = idx;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setStateDialog(() {
                                      _choferes.removeAt(idx);
                                      if (_choferSeleccionado == idx)
                                        _choferSeleccionado = null;
                                    });
                                    _guardarChoferes();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    TextField(
                      controller: nombreCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nombre Chofer'),
                    ),
                    TextField(
                      controller: rfcCtrl,
                      decoration: const InputDecoration(labelText: 'RFC'),
                    ),
                    TextField(
                      controller: telCtrl,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nombre = nombreCtrl.text.trim();
                    final rfc = rfcCtrl.text.trim();
                    final tel = telCtrl.text.trim();
                    if (nombre.isEmpty) return;
                    setStateDialog(() {
                      if (editingIndex != null) {
                        _choferes[editingIndex!] = {
                          'nombre': nombre,
                          'rfc': rfc,
                          'telefono': tel,
                        };
                        editingIndex = null;
                      } else {
                        _choferes.add({
                          'nombre': nombre,
                          'rfc': rfc,
                          'telefono': tel,
                        });
                      }
                      limpiarCampos();
                    });
                    _guardarChoferes();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Exportar a Excel
  Future<void> _exportarExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['CartaPorte'];
    // Encabezados personalizados (agregar RFC después de Chofer)
    final encabezados = [
      'Fecha',
      'Chofer',
      'RFC',
      'Unidad',
      'Destino',
      ..._columns
    ];
    sheet.appendRow(encabezados);
    for (final rowCtrls in _controllers) {
      final row = [
        _fechaActual,
        _choferController.text,
        _rfcController.text,
        _unidadController.text,
        _destinoController.text,
        ...rowCtrls.map((c) => c.text)
      ];
      // Solo exportar filas con algún dato
      if (rowCtrls.any((c) => c.text.trim().isNotEmpty)) {
        sheet.appendRow(row);
      }
    }
    final fileBytes = excel.encode()!;
    final blob = html.Blob([fileBytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'carta_porte.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  final List<String> _columns = [
    'ESCANEO',
    'NO.',
    'TIPO',
    'SYS',
    'EMBARQUE',
    'DESCRIPCIÓN / COMENTARIOS',
    'NO. BULTO',
    'DESTINO',
    'CONTENEDOR',
    'EMBARQUE',
    'CONCENTRADO',
  ];

  List<List<TextEditingController>> _controllers = [];
  final List<List<FocusNode>> _focusNodes = [];
  late Future<void> _initFuture;

  // Controladores para encabezados editables
  final TextEditingController _choferController = TextEditingController();
  final TextEditingController _unidadController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  late String _fechaActual;

  Future<void> _initControllers() async {
    // Simula carga y reduce filas iniciales a 5 para evitar congelamiento
    await Future.delayed(const Duration(milliseconds: 600));
    _controllers = List.generate(
      5,
      (_) => List.generate(_columns.length, (_) => TextEditingController()),
    );
    _focusNodes.clear();
    _focusNodes.addAll(List.generate(
      5,
      (_) => List.generate(_columns.length, (_) => FocusNode()),
    ));
  }

  @override
  void dispose() {
    _rfcController.dispose();
    for (var row in _controllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    for (var row in _focusNodes) {
      for (var f in row) {
        f.dispose();
      }
    }
    _choferController.dispose();
    _unidadController.dispose();
    _destinoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ya no es necesario cargar choferes manualmente, se sincronizan en tiempo real
    final double screenWidth = MediaQuery.of(context).size.width;
    final double horizontalMargin = 24.0;
    // Ajuste: todos los encabezados visibles en pantalla
    final double minColWidth = 70.0;
    final double maxColWidth = 160.0;
    final double descColWidth = 170.0;
    final double totalWidth = screenWidth - horizontalMargin * 2;
    // ESCANEO y NO. fijos, DESCRIPCIÓN ancho especial, el resto proporcional
    final List<double> colWidths = [];
    double usedWidth = 0;
    for (int i = 0; i < _columns.length; i++) {
      if (i == 0 || i == 1) {
        colWidths.add(minColWidth);
        usedWidth += minColWidth;
      } else if (_columns[i] == 'DESCRIPCIÓN / COMENTARIOS') {
        colWidths.add(descColWidth);
        usedWidth += descColWidth;
      } else {
        // Se reparte el resto del ancho entre las columnas restantes
        colWidths.add(0); // Placeholder, se ajusta después
      }
    }
    // Calcular ancho para las columnas restantes
    int restantes = colWidths.where((w) => w == 0).length;
    double restantePorCol =
        ((totalWidth - usedWidth) / restantes).clamp(minColWidth, maxColWidth);
    for (int i = 0; i < colWidths.length; i++) {
      if (colWidths[i] == 0) {
        colWidths[i] = restantePorCol;
      }
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        // UI principal
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.assignment,
                      color: Color(0xFF2D6A4F), size: 32),
                  const SizedBox(width: 10),
                  const Text(
                    'Carta Porte',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFF2D6A4F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Botones superiores: Guardar, Agregar fila, Generar número de control, Exportar a Excel, Datos de Chofer
            Padding(
              padding:
                  const EdgeInsets.only(top: 8, left: 24, right: 24, bottom: 4),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _guardarCartaPorteEnHistorial,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar fila'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _controllers.add(List.generate(
                            _columns.length, (_) => TextEditingController()));
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.confirmation_number),
                    label: const Text('Generar número de control'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final nuevoNum = await _generarNumeroDeControl();
                      setState(() {
                        _numeroControlActual = nuevoNum;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Número de control generado: $nuevoNum'),
                            backgroundColor: Colors.blue),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_download),
                    label: const Text('Exportar a Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _exportarExcel,
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person),
                    label: const Text('Datos de Chofer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _mostrarDialogoChoferes,
                  ),
                ],
              ),
            ),
            // Encabezado superior editable rediseñado
            Padding(
              padding: EdgeInsets.symmetric(
                  vertical: 8.0, horizontal: horizontalMargin),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Columna izquierda: Origen y Destino
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORIGEN',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('78'),
                      const SizedBox(height: 2),
                      const Text('78 GALERIAS GDL'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('DESTINO:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 160,
                            child: TextField(
                              controller: _destinoController,
                              decoration: const InputDecoration(
                                hintText: 'Destino',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Mostrar número de control si existe
                          if (_numeroControlActual != null)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFFB7E4C7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF2D6A4F)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.confirmation_number,
                                        size: 18, color: Color(0xFF2D6A4F)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _numeroControlActual!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D6A4F),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('CHOFER:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<int>(
                              value: _choferSeleccionado,
                              items: [
                                for (int i = 0; i < _choferes.length; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(_choferes[i]['nombre'] ?? ''),
                                  ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _choferSeleccionado = val;
                                  if (val != null) {
                                    _choferController.text =
                                        _choferes[val]['nombre'] ?? '';
                                    _rfcController.text =
                                        _choferes[val]['rfc'] ?? '';
                                  } else {
                                    _choferController.text = '';
                                    _rfcController.text = '';
                                  }
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: 'Chofer',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text('UNIDAD:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _unidadController,
                              decoration: const InputDecoration(
                                hintText: 'Unidad',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text('RFC:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 130,
                            child: TextField(
                              controller: _rfcController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                hintText: 'RFC',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Centro: Título
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'HOJA DE RUTA - ENVÍO MERCANCÍA',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Derecha: Fecha
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(height: 2),
                      Text(_fechaActual,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            // ... (eliminar botón duplicado de exportar a Excel)
            // Tabla con encabezado sticky y filas como Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
              child: Column(
                children: [
                  // Encabezado sticky con scroll horizontal
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < _columns.length; i++)
                          Container(
                            width: colWidths[i],
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            decoration:
                                const BoxDecoration(color: Color(0xFF2D6A4F)),
                            child: Text(
                              _columns[i],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Filas scrolleables (ListView.builder) con scroll horizontal
                  SizedBox(
                    height: 320,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: colWidths.reduce((a, b) => a + b),
                          child: ListView.builder(
                            itemCount: _controllers.length,
                            itemBuilder: (context, rowIdx) {
                              final rowCtrls = _controllers[rowIdx];
                              return Row(
                                children: [
                                  for (int colIdx = 0;
                                      colIdx < _columns.length;
                                      colIdx++)
                                    Container(
                                      width: colWidths[colIdx],
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              width: 0.5,
                                              color: Colors.grey.shade400),
                                          right: BorderSide(
                                              width: 1,
                                              color: const Color(0xFFB7B7B7)),
                                        ),
                                      ),
                                      child: colIdx == 1
                                          ? Text(
                                              (rowIdx + 1).toString(),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold),
                                            )
                                          : colIdx == 0
                                              ? TextField(
                                                  controller: rowCtrls[colIdx],
                                                  focusNode:
                                                      _focusNodes.length >
                                                              rowIdx
                                                          ? _focusNodes[rowIdx]
                                                              [colIdx]
                                                          : null,
                                                  textAlign: TextAlign.center,
                                                  decoration:
                                                      const InputDecoration(
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 6,
                                                            horizontal: 4),
                                                  ),
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                  onSubmitted: (value) async {
                                                    // Si es la penúltima fila, agregar una nueva automáticamente
                                                    if (rowIdx ==
                                                        _controllers.length -
                                                            2) {
                                                      setState(() {
                                                        _controllers.add(
                                                            List.generate(
                                                                _columns.length,
                                                                (_) =>
                                                                    TextEditingController()));
                                                        _focusNodes.add(
                                                            List.generate(
                                                                _columns.length,
                                                                (_) =>
                                                                    FocusNode()));
                                                      });
                                                    }
                                                    // Buscar en hojas de ruta enviadas
                                                    final hojaList =
                                                        HojaDeRutaExtraPage
                                                            .sentHojaRutas;
                                                    final hoja =
                                                        hojaList.firstWhere(
                                                      (h) =>
                                                          h['caja']
                                                              ?.toString()
                                                              .trim() ==
                                                          value.trim(),
                                                      orElse: () =>
                                                          <String, dynamic>{},
                                                    );
                                                    DateTime? fechaHoja;
                                                    if (hoja.isNotEmpty) {
                                                      // Buscar fecha en hoja de ruta enviada
                                                      // Se intenta extraer de 'createdAt' o 'fecha' (ajusta si tu estructura es diferente)
                                                      final fechaStr =
                                                          hoja['createdAt'] ??
                                                              hoja['fecha'];
                                                      if (fechaStr != null) {
                                                        try {
                                                          fechaHoja =
                                                              DateTime.parse(
                                                                  fechaStr);
                                                        } catch (_) {}
                                                      }
                                                    }
                                                    // Buscar en historial de XD (cache primero, luego Firebase)
                                                    final dataXD =
                                                        await leerDatosConCache(
                                                            'hoja_de_xd_historial',
                                                            'main');
                                                    List<HojaDeXDHistorial>
                                                        historialXD = [];
                                                    if (dataXD != null &&
                                                        dataXD['historial'] !=
                                                            null) {
                                                      final List<dynamic> list =
                                                          dataXD['historial'];
                                                      historialXD = list
                                                          .map((e) =>
                                                              HojaDeXDHistorial
                                                                  .fromJson(e))
                                                          .toList();
                                                    }
                                                    final historialFiltrado =
                                                        historialXD
                                                            .where((h) =>
                                                                (h.datos['CONTENEDOR O TARIMA']
                                                                        ?.trim() ??
                                                                    '') ==
                                                                value.trim())
                                                            .toList();
                                                    HojaDeXDHistorial?
                                                        xdReciente;
                                                    if (historialFiltrado
                                                        .isNotEmpty) {
                                                      historialFiltrado.sort(
                                                          (a, b) => b.fecha
                                                              .compareTo(
                                                                  a.fecha));
                                                      xdReciente =
                                                          historialFiltrado
                                                              .first;
                                                    }
                                                    // Comparar fechas y decidir cuál usar
                                                    final bool usarXD =
                                                        xdReciente != null &&
                                                            (fechaHoja ==
                                                                    null ||
                                                                xdReciente.fecha
                                                                    .isAfter(
                                                                        fechaHoja));
                                                    if (hoja.isEmpty &&
                                                        xdReciente == null) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                              'Favor de validar: este contenedor no contiene información.'),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                      setState(() {
                                                        for (int i = 2;
                                                            i < _columns.length;
                                                            i++) {
                                                          if (i == 9)
                                                            continue; // EMBARQUE editable
                                                          rowCtrls[i].text = '';
                                                        }
                                                      });
                                                      if (_focusNodes.length >
                                                          rowIdx + 1) {
                                                        FocusScope.of(context)
                                                            .requestFocus(
                                                                _focusNodes[
                                                                    rowIdx +
                                                                        1][0]);
                                                      }
                                                      return;
                                                    }
                                                    setState(() {
                                                      if (usarXD) {
                                                        // Usar historial XD
                                                        rowCtrls[2].text = 'PQ';
                                                        final tu = xdReciente!
                                                                .datos['TU'] ??
                                                            '';
                                                        rowCtrls[3].text =
                                                            tu.isNotEmpty
                                                                ? 'MN'
                                                                : 'SAP';
                                                        rowCtrls[4].text =
                                                            tu.isNotEmpty
                                                                ? tu
                                                                : '';
                                                        rowCtrls[5]
                                                            .text = xdReciente
                                                                    .datos[
                                                                'MANIFIESTO'] ??
                                                            '';
                                                        rowCtrls[6]
                                                            .text = xdReciente
                                                                    .datos[
                                                                'CANTIDAD DE LPS'] ??
                                                            '';
                                                        rowCtrls[7]
                                                            .text = xdReciente
                                                                    .datos[
                                                                'DESTINO'] ??
                                                            '';
                                                        rowCtrls[8].text =
                                                            value;
                                                        String embarque1 =
                                                            rowCtrls[4].text;
                                                        String embarque2 =
                                                            rowCtrls[9].text;
                                                        rowCtrls[10].text =
                                                            embarque1.isNotEmpty
                                                                ? embarque1
                                                                : embarque2;
                                                      } else {
                                                        // Usar hoja de ruta enviada
                                                        rowCtrls[2]
                                                            .text = hoja['tipo']
                                                                ?.toString() ??
                                                            '';
                                                        rowCtrls[3].text =
                                                            'SAP';
                                                        String embarque = '';
                                                        if (hoja['headers'] !=
                                                                null &&
                                                            hoja['rows'] !=
                                                                null &&
                                                            hoja['rows']
                                                                .isNotEmpty) {
                                                          final headers = List<
                                                                  String>.from(
                                                              hoja['headers']);
                                                          int idxManiRemi = headers
                                                              .indexWhere((h) =>
                                                                  h
                                                                      .toLowerCase()
                                                                      .contains(
                                                                          'manifiesto') ||
                                                                  h
                                                                      .toLowerCase()
                                                                      .contains(
                                                                          'remision'));
                                                          if (idxManiRemi !=
                                                              -1) {
                                                            embarque = hoja['rows']
                                                                            [0][
                                                                        idxManiRemi]
                                                                    ?.toString() ??
                                                                '';
                                                          }
                                                        }
                                                        if (embarque.isEmpty) {
                                                          embarque = hoja[
                                                                      'numeroControl']
                                                                  ?.toString() ??
                                                              hoja['remi']
                                                                  ?.toString() ??
                                                              '';
                                                        }
                                                        rowCtrls[4].text =
                                                            embarque;
                                                        rowCtrls[5]
                                                            .text = hoja['tipo']
                                                                ?.toString() ??
                                                            '';
                                                        int bultos = 0;
                                                        if (hoja['rows'] !=
                                                            null) {
                                                          int idxBulto = 6;
                                                          if (hoja['headers'] !=
                                                              null) {
                                                            final headers = List<
                                                                    String>.from(
                                                                hoja[
                                                                    'headers']);
                                                            idxBulto = headers
                                                                .indexWhere((h) => h
                                                                    .toLowerCase()
                                                                    .contains(
                                                                        'bulto'));
                                                            if (idxBulto == -1)
                                                              idxBulto = 6;
                                                          }
                                                          for (final r
                                                              in hoja['rows']) {
                                                            if (r is List &&
                                                                r.length >
                                                                    idxBulto) {
                                                              final val = int
                                                                  .tryParse(r[
                                                                          idxBulto]
                                                                      .toString());
                                                              if (val != null)
                                                                bultos += val;
                                                            }
                                                          }
                                                        }
                                                        rowCtrls[6].text =
                                                            bultos > 0
                                                                ? bultos
                                                                    .toString()
                                                                : '';
                                                        String destino = hoja[
                                                                    'destino']
                                                                ?.toString() ??
                                                            '';
                                                        if (destino.isEmpty &&
                                                            hoja['rows'] !=
                                                                null &&
                                                            hoja['headers'] !=
                                                                null) {
                                                          final headers = List<
                                                                  String>.from(
                                                              hoja['headers']);
                                                          int idxDestino = headers
                                                              .indexWhere((h) => h
                                                                  .toLowerCase()
                                                                  .contains(
                                                                      'destino'));
                                                          if (idxDestino !=
                                                                  -1 &&
                                                              hoja['rows']
                                                                  .isNotEmpty) {
                                                            destino = hoja['rows']
                                                                            [0][
                                                                        idxDestino]
                                                                    ?.toString() ??
                                                                '';
                                                          }
                                                        }
                                                        rowCtrls[7].text =
                                                            destino;
                                                        rowCtrls[8].text =
                                                            value;
                                                        String embarque1 =
                                                            rowCtrls[4].text;
                                                        String embarque2 =
                                                            rowCtrls[9].text;
                                                        rowCtrls[10].text =
                                                            embarque1.isNotEmpty
                                                                ? embarque1
                                                                : embarque2;
                                                      }
                                                    });
                                                    if (_focusNodes.length >
                                                        rowIdx + 1) {
                                                      FocusScope.of(context)
                                                          .requestFocus(
                                                              _focusNodes[
                                                                  rowIdx +
                                                                      1][0]);
                                                    }
                                                  },
                                                )
                                              : colIdx == 9
                                                  ? TextField(
                                                      controller:
                                                          rowCtrls[colIdx],
                                                      textAlign:
                                                          TextAlign.center,
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 6,
                                                                    horizontal:
                                                                        4),
                                                      ),
                                                      style: const TextStyle(
                                                          fontSize: 13),
                                                      onChanged: (value) {
                                                        // Cuando se edita el segundo EMBARQUE, actualizar CONCENTRADO
                                                        setState(() {
                                                          String embarque1 =
                                                              rowCtrls[4].text;
                                                          String embarque2 =
                                                              value;
                                                          rowCtrls[10]
                                                              .text = embarque1
                                                                  .isNotEmpty
                                                              ? embarque1
                                                              : embarque2;
                                                        });
                                                      },
                                                    )
                                                  : colIdx == 10
                                                      ? AbsorbPointer(
                                                          child: TextField(
                                                            controller:
                                                                rowCtrls[
                                                                    colIdx],
                                                            textAlign: TextAlign
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
                                                                          6,
                                                                      horizontal:
                                                                          4),
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .grey),
                                                          ),
                                                        )
                                                      : TextField(
                                                          controller:
                                                              rowCtrls[colIdx],
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
                                                                            6,
                                                                        horizontal:
                                                                            4),
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 13),
                                                        ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ... (botones inferiores eliminados, ya están arriba)
          ],
        );
      },
    );
  }
}
