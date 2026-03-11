import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/firebase_cache_utils.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:universal_html/html.dart' as html;
import 'hoja_de_ruta_extra_page.dart';

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
  // --- CONTROLADORES Y ESTADO ---
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
  final List<double> colWidths = [
    80,
    50,
    60,
    50,
    120,
    300,
    80,
    130,
    120,
    120,
    120
  ];
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

  void _escucharChoferesRealtime() {
    // Aquí podrías cargar choferes desde Firestore si lo deseas
    // Por ahora, ejemplo estático:
    _choferes = [
      {'nombre': 'Juan Pérez', 'rfc': 'JUAP800101XXX'},
      {'nombre': 'Ana López', 'rfc': 'ANAL900202YYY'},
    ];
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
    setState(() {
      _numeroControlActual = null;
      _choferController.clear();
      _rfcController.clear();
      _unidadController.clear();
      _destinoController.clear();
      _controllers = List.generate(
          5,
          (_) =>
              List.generate(_columns.length, (_) => TextEditingController()));
      _focusNodes.clear();
      _focusNodes.addAll(List.generate(
          5, (_) => List.generate(_columns.length, (_) => FocusNode())));
    });
  }

  Future<String> _generarNumeroDeControl() async {
    final lista = await CartaPorteHistorialManager.loadAll();
    final RegExp exp = RegExp(r'^0078-CP-(\d{3})$');
    int maxNum = 0;
    for (final carta in lista) {
      final numCtrl = carta['NUMERO_CONTROL']?.toString() ?? '';
      final match = exp.firstMatch(numCtrl);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    final siguiente = maxNum + 1;
    final nuevoNum = '0078-CP-[31m${siguiente.toString().padLeft(3, '0')}[0m';
    return nuevoNum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
        title: Row(
          children: [
            Icon(Icons.local_shipping, color: Color(0xFF2D6A4F), size: 32),
            const SizedBox(width: 10),
            const Text(
              'Carta Porte',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar a Excel',
            onPressed: _exportarExcel,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando carta porte...',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botones superiores
                Row(
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
                          _focusNodes.add(List.generate(
                              _columns.length, (_) => FocusNode()));
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
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person),
                      label: const Text('Datos de Chofer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Aquí podrías mostrar un diálogo para editar choferes
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Encabezado superior editable
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna izquierda: Origen y Destino
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('78 GALERIAS GDL',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('DESTINO:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 180,
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
                            if (_numeroControlActual != null)
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 200),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB7E4C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Color(0xFF2D6A4F)),
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
                                              color: Color(0xFF2D6A4F)),
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
                              width: 160,
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
                              width: 120,
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
                              width: 150,
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
                              fontWeight: FontWeight.bold, fontSize: 20),
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
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Tabla de carta porte
                Container(
                  constraints: const BoxConstraints(minHeight: 400),
                  color: Colors.white,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: colWidths.reduce((a, b) => a + b) + 40,
                        child: Column(
                          children: [
                            // Encabezado
                            Row(
                              children: [
                                for (int i = 0; i < _columns.length; i++)
                                  Container(
                                    width: colWidths[i],
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 8),
                                    decoration: const BoxDecoration(
                                        color: Colors.white),
                                    child: Text(
                                      _columns[i],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D6A4F),
                                          fontSize: 16,
                                          letterSpacing: 1.1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            // Filas
                            for (int rowIdx = 0;
                                rowIdx <
                                    (_controllers.length < 5
                                        ? 5
                                        : _controllers.length);
                                rowIdx++)
                              Row(
                                children: [
                                  for (int colIdx = 0;
                                      colIdx < _columns.length;
                                      colIdx++)
                                    Container(
                                      width: colWidths[colIdx],
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              width: 0.7,
                                              color: Colors.grey.shade400),
                                          right: const BorderSide(
                                              width: 1,
                                              color: Color(0xFFB7B7B7)),
                                        ),
                                      ),
                                      child: colIdx == 1
                                          ? Text((rowIdx + 1).toString(),
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold))
                                          : colIdx == 0
                                              ? TextField(
                                                  controller: rowIdx <
                                                          _controllers.length
                                                      ? _controllers[rowIdx]
                                                          [colIdx]
                                                      : null,
                                                  focusNode: rowIdx <
                                                          _focusNodes.length
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
                                                            vertical: 8,
                                                            horizontal: 4),
                                                  ),
                                                  style: const TextStyle(
                                                      fontSize: 15),
                                                  onSubmitted: (value) async {
                                                    // ESCANEO automático: buscar en historial XD y hoja de ruta enviada
                                                    final dataXD =
                                                        await leerDatosConCache(
                                                            'hoja_de_xd_historial',
                                                            'main');
                                                    List<dynamic> historialXD =
                                                        [];
                                                    if (dataXD != null &&
                                                        dataXD['historial'] !=
                                                            null) {
                                                      historialXD =
                                                          List<dynamic>.from(
                                                              dataXD[
                                                                  'historial']);
                                                    }
                                                    Map<String, dynamic>?
                                                        xdReciente;
                                                    DateTime? fechaXD;
                                                    for (final h
                                                        in historialXD) {
                                                      final datos = h['datos']
                                                          as Map<String,
                                                              dynamic>?;
                                                      if (datos != null &&
                                                          (datos['CONTENEDOR O TARIMA'] !=
                                                                  null &&
                                                              datos['CONTENEDOR O TARIMA']
                                                                      .toString()
                                                                      .trim() ==
                                                                  value
                                                                      .trim())) {
                                                        final fecha =
                                                            DateTime.tryParse(
                                                                h['fecha'] ??
                                                                    '');
                                                        if (fechaXD == null ||
                                                            (fecha != null &&
                                                                fecha.isAfter(
                                                                    fechaXD))) {
                                                          xdReciente = h;
                                                          fechaXD = fecha;
                                                        }
                                                      }
                                                    }
                                                    await HojaDeRutaExtraPage
                                                        .loadSentHojaRutasCache();
                                                    final hojaList = HojaDeRutaExtraPage
                                                        .sentHojaRutas
                                                        .where((h) => (h[
                                                                    'caja'] !=
                                                                null &&
                                                            h['caja']
                                                                    .toString()
                                                                    .trim() ==
                                                                value.trim()))
                                                        .toList();
                                                    Map<String, dynamic>?
                                                        hojaReciente;
                                                    DateTime? fechaHoja;
                                                    for (final h in hojaList) {
                                                      final fecha =
                                                          DateTime.tryParse(
                                                              h['createdAt'] ??
                                                                  '');
                                                      if (fechaHoja == null ||
                                                          (fecha != null &&
                                                              fecha.isAfter(
                                                                  fechaHoja))) {
                                                        hojaReciente = h;
                                                        fechaHoja = fecha;
                                                      }
                                                    }
                                                    bool usarXD = false;
                                                    if (xdReciente != null &&
                                                        hojaReciente != null) {
                                                      usarXD = fechaXD !=
                                                              null &&
                                                          fechaHoja != null &&
                                                          fechaXD.isAfter(
                                                              fechaHoja);
                                                    } else if (xdReciente !=
                                                        null) {
                                                      usarXD = true;
                                                    }
                                                    setState(() {
                                                      if (usarXD &&
                                                          xdReciente != null) {
                                                        final datos =
                                                            xdReciente['datos']
                                                                as Map<String,
                                                                    dynamic>?;
                                                        _controllers[rowIdx][2]
                                                                .text =
                                                            datos?['TIPO'] ??
                                                                '';
                                                        _controllers[rowIdx][3]
                                                                .text =
                                                            datos?['SYS'] ?? '';
                                                        _controllers[rowIdx][4]
                                                                .text =
                                                            datos?['TU'] ?? '';
                                                        _controllers[rowIdx][5]
                                                            .text = datos?[
                                                                'MANIFIESTO'] ??
                                                            '';
                                                        _controllers[rowIdx][6]
                                                            .text = datos?[
                                                                'CANTIDAD DE LPS'] ??
                                                            '';
                                                        _controllers[rowIdx][7]
                                                                .text =
                                                            datos?['DESTINO'] ??
                                                                '';
                                                        _controllers[rowIdx][8]
                                                            .text = value;
                                                      } else if (hojaReciente !=
                                                          null) {
                                                        _controllers[rowIdx][2]
                                                            .text = hojaReciente[
                                                                    'tipo']
                                                                ?.toString() ??
                                                            '';
                                                        _controllers[rowIdx][3]
                                                            .text = hojaReciente[
                                                                    'tipo']
                                                                ?.toString() ??
                                                            '';
                                                        _controllers[rowIdx][4]
                                                            .text = hojaReciente[
                                                                    'manifiesto']
                                                                ?.toString() ??
                                                            '';
                                                        _controllers[rowIdx][5]
                                                            .text = hojaReciente[
                                                                    'tipo']
                                                                ?.toString() ??
                                                            '';
                                                        _controllers[rowIdx][6]
                                                            .text = hojaReciente[
                                                                    'bultos']
                                                                ?.toString() ??
                                                            '';
                                                        _controllers[rowIdx][7]
                                                            .text = hojaReciente[
                                                                    'destino']
                                                                ?.toString() ??
                                                            '';
                                                        _controllers[rowIdx][8]
                                                            .text = value;
                                                      } else {
                                                        for (int i = 2;
                                                            i < _columns.length;
                                                            i++) {
                                                          _controllers[rowIdx]
                                                                  [i]
                                                              .text = '';
                                                        }
                                                      }
                                                    });
                                                  },
                                                )
                                              : TextField(
                                                  controller: rowIdx <
                                                          _controllers.length
                                                      ? _controllers[rowIdx]
                                                          [colIdx]
                                                      : null,
                                                  focusNode: rowIdx <
                                                          _focusNodes.length
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
                                                            vertical: 8,
                                                            horizontal: 4),
                                                  ),
                                                  style: const TextStyle(
                                                      fontSize: 15),
                                                ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
// ...el resto del código ya está limpio y funcional...
}
