import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:universal_html/html.dart' as html;
import 'hoja_de_ruta_extra_page.dart';
import '../models/hoja_de_xd_historial.dart';

/// Manager para historial de carta porte usando Firestore + caché
class CartaPorteHistorialManager {
  static const String coleccion = 'historial_carta_porte';

  static Future<void> addCarta(Map<String, dynamic> carta) async {
    final docId = carta['NUMERO_CONTROL'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await guardarDatosFirestoreYCache(coleccion, docId, carta);
  }

  static Future<List<Map<String, dynamic>>> loadAll() async {
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

class CartaPorteTable extends StatefulWidget {
  const CartaPorteTable({super.key});
  @override
  State<CartaPorteTable> createState() => _CartaPorteTableState();
}

class _CartaPorteTableState extends State<CartaPorteTable> {
  final TextEditingController _rfcController = TextEditingController();
  final TextEditingController _choferController = TextEditingController();
  final TextEditingController _unidadController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  List<Map<String, String>> _choferes = [];
  int? _choferSeleccionado;
  late String _fechaActual;
  late Future<void> _initFuture;
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

  // Ancho fijo para cada columna (debe tener la misma longitud que _columns)
  final List<double> colWidths = [
    80, // ESCANEO
    50, // NO.
    60, // TIPO
    50, // SYS
    120, // EMBARQUE (primero)
    300, // DESCRIPCIÓN / COMENTARIOS
    80, // NO. BULTO
    130, // DESTINO
    120, // CONTENEDOR
    120, // EMBARQUE (segundo)
    120, // CONCENTRADO
  ];

  // Margin usado en varios paddings de la UI
  final double horizontalMargin = 24.0;
  List<List<TextEditingController>> _controllers = [];
  final List<List<FocusNode>> _focusNodes = [];
  String? _numeroControlActual;

  @override
  void initState() {
    super.initState();
    _initFuture = _initControllers();
    final now = DateTime.now();
    _fechaActual =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _escucharChoferesRealtime();
  }

  @override
  void dispose() {
    _rfcController.dispose();
    _choferController.dispose();
    _unidadController.dispose();
    _destinoController.dispose();
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
    super.dispose();
  }

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

  Future<void> _initControllers() async {
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

  Future<void> _guardarChoferes() async {
    final Map<String, dynamic> data = {'items': _choferes};
    await guardarDatosFirestoreYCache('choferes', 'main', data);
  }

  void _mostrarDialogoChoferes() async {
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

  Future<void> _exportarExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['CartaPorte'];
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

  Future<void> _guardarCartaPorteEnHistorial() async {
    final rows = _controllers
        .map((rowCtrls) => rowCtrls.map((c) => c.text).toList())
        .toList();
    final numero = _numeroControlActual ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final carta = <String, dynamic>{
      'NUMERO_CONTROL': numero,
      'fecha': _fechaActual,
      'chofer': _choferController.text,
      'rfc': _rfcController.text,
      'unidad': _unidadController.text,
      'destino': _destinoController.text,
      'rows': rows,
    };
    await CartaPorteHistorialManager.addCarta(carta);
    await CartaPorteHistorialManager.addCartaId(numero);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Carta porte guardada correctamente'),
          backgroundColor: Colors.green),
    );
  }

  Future<String> _generarNumeroDeControl() async {
    // Genera un número de control único usando timestamp; si ya existe en historial añade sufijo
    final nuevo = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final lista = await CartaPorteHistorialManager.loadAll();
      final exists = lista.any((c) => c['NUMERO_CONTROL'] == nuevo);
      if (exists) {
        return '${nuevo}_${DateTime.now().microsecondsSinceEpoch}';
      }
    } catch (_) {}
    return nuevo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HOJA DE RUTA - ENVÍO MERCANCÍA'),
        backgroundColor: Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding:
            EdgeInsets.symmetric(vertical: 8.0, horizontal: horizontalMargin),
        child: Column(
          children: [
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
                                                          final origenHoja =
                                                              (hoja['origen'] ??
                                                                      '')
                                                                  .toString()
                                                                  .toUpperCase();
                                                          if (origenHoja ==
                                                              'EMBARQUE') {
                                                            // Para hojas de tipo EMBARQUE, priorizar
                                                            // campos de manifiesto/remisión y NO
                                                            // usar el número de control como valor
                                                            embarque = hoja[
                                                                        'remi']
                                                                    ?.toString() ??
                                                                hoja['manifiesto']
                                                                    ?.toString() ??
                                                                hoja['mani']
                                                                    ?.toString() ??
                                                                '';
                                                          } else {
                                                            // Comportamiento previo para otras hojas
                                                            embarque = hoja[
                                                                        'numeroControl']
                                                                    ?.toString() ??
                                                                hoja['remi']
                                                                    ?.toString() ??
                                                                '';
                                                          }
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
        ),
      ),
    );
  }
}
