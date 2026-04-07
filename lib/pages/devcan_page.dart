import 'package:flutter/material.dart';
import 'entregas_devcan_page.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:excel/excel.dart' hide Border;

class DevCanPage extends StatefulWidget {
  final String usuario;
  const DevCanPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<DevCanPage> createState() => _DevCanPageState();
}

class _DevCanPageState extends State<DevCanPage> {
  String? _seccionActual;
  String? _jefaturaActual;
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocus = FocusNode();
  final TextEditingController _manifiestoController = TextEditingController();
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
  bool _listenerAgregado = false;
  Map<String, dynamic>? _ultimaEntregaGuardada;

  @override
  void initState() {
    super.initState();
    _cargarUltimaEntregaGuardada();
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
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(List.generate(_headers.length, (_) => TextEditingController()));
    });
  }

  Future<void> _importFromExcel() async {
    // Importar desde Excel: tomar siempre desde la segunda fila y solo los primeros 6 campos
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.xlsx';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) async {
        final data = reader.result;
        if (data is! Uint8List && data is! List<int>) return;
        try {
          final excel = Excel.decodeBytes(
              data is Uint8List ? data : Uint8List.fromList(data as List<int>));
          final sheet = excel.tables.values.first;
          final rows = sheet.rows;
          if (rows.length < 2) return;
          final newRows = <List<TextEditingController>>[];
          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            final controllers =
                List<TextEditingController>.generate(_headers.length, (j) {
              if (j < row.length) {
                return TextEditingController(
                    text: row[j]?.value?.toString() ?? '');
              } else {
                return TextEditingController();
              }
            });
            // Buscar y asignar JEFATURA si hay SECCION
            final idxSeccion = _headers.indexOf('SECCION');
            final idxJefatura = _headers.indexOf('JEFATURA');
            if (idxSeccion != -1 && idxJefatura != -1) {
              final seccion = controllers[idxSeccion].text.trim();
              if (seccion.isNotEmpty) {
                final nombre = await _buscarJefaturaFirestore(seccion);
                controllers[idxJefatura].text = nombre;
              }
            }
            if (controllers.any((c) => c.text.trim().isNotEmpty)) {
              newRows.add(controllers);
            }
          }
          setState(() {
            _rows.clear();
            _rows.addAll(newRows);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importación desde Excel exitosa.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error importando Excel: $e'),
                backgroundColor: Colors.red),
          );
        }
      });
    });
  }

  Future<void> _guardarEntregasYNotificar() async {
    // Validar que haya datos
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para guardar.')),
      );
      return;
    }

    // Validar que todas las filas tengan VALIDACION en 'true'
    final idxValidacion = _headers.indexOf('VALIDACION');
    for (final row in _rows) {
      final validacion = idxValidacion == -1
          ? ''
          : row[idxValidacion].text.trim().toLowerCase();
      if (validacion != 'true') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No puedes guardar: todas las filas deben tener VALIDACION en true.')),
        );
        return;
      }
    }
    final manifiesto = _manifiestoController.text.trim();
    final items = _rows.map((row) {
      Map<String, dynamic> map = {};
      for (int i = 0; i < _headers.length; i++) {
        map[_headers[i]] = row[i].text;
      }
      map['usuarioValido'] = widget.usuario;
      if (manifiesto.isNotEmpty) {
        map['MANIFIESTO'] = manifiesto;
      }
      return map;
    }).toList();

    // Buscar filas con FALTANTE o X en BOX
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
        map['usuarioValido'] = widget.usuario;
        if (manifiesto.isNotEmpty) {
          map['MANIFIESTO'] = manifiesto;
        }
        filasFaltantes.add(map);
      }
    }

    try {
      // Leer los items actuales de Firestore
      final doc = await FirebaseFirestore.instance
          .collection('entregas')
          .doc('devcan')
          .get();
      List<dynamic> existentes = [];
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!.containsKey('items')) {
        final data = doc.data()!['items'];
        if (data is List) {
          existentes = List.from(data);
        }
      }
      // Agregar los nuevos items
      final nuevosItems = [...existentes, ...items];
      await guardarDatosFirestoreYCache(
        'entregas',
        'devcan',
        {'items': nuevosItems},
      );
      setState(() {
        _ultimaEntregaGuardada = {'items': nuevosItems};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información guardada en DevCan.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando en Firestore: $e'),
          backgroundColor: Colors.red,
        ),
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

  void _buscarYMarcarLP(String codigo) {
    final idxLP = _headers.indexOf('LP');
    final idxValidacion = _headers.indexOf('VALIDACION');
    String normalizarLP(String lp) => lp.replaceFirst(RegExp(r'^0+'), '');
    final codigoNorm = normalizarLP(codigo);
    String? seccion;
    String? jefatura;
    setState(() {
      for (final row in _rows) {
        if (idxLP != -1 &&
            (row[idxLP].text.trim() == codigo ||
                normalizarLP(row[idxLP].text.trim()) == codigoNorm)) {
          if (idxValidacion != -1) {
            row[idxValidacion].text = '✔️';
          }
          final idxSeccion = _headers.indexOf('SECCION');
          final idxJefatura = _headers.indexOf('JEFATURA');
          seccion = idxSeccion != -1 ? row[idxSeccion].text : null;
          jefatura = idxJefatura != -1 ? row[idxJefatura].text : null;
          break;
        }
      }
      _seccionActual = seccion;
      _jefaturaActual = jefatura;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _scanController.clear();
      _scanFocus.requestFocus();
    });
  }

  void _cargarUltimaEntregaGuardada() {
    // Implementación de carga de última entrega guardada (placeholder)
    _ultimaEntregaGuardada = {};
  }

  bool _esMismaEntrega(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    // Implementación de comparación de entregas (placeholder)
    return true;
  }

  Map<String, dynamic> _generarEntregaActual() {
    // Implementación de generación de entrega actual (placeholder)
    return {};
  }

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
          title: Row(
            children: const [
              Icon(Icons.inventory_2, color: Color(0xFF2D6A4F), size: 28),
              SizedBox(width: 10),
              Text(
                'DevCan',
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
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Ver Entregas DevCan'),
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
                                EntregasDevCanPage(usuario: widget.usuario),
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
                    SizedBox(height: 18),
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
                    // Campo para ingresar el manifiesto
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manifiestoController,
                            decoration: const InputDecoration(
                              labelText:
                                  'MANIFIESTO (se guardará en cada línea)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if ((_seccionActual?.isNotEmpty ?? false) ||
                        (_jefaturaActual?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_seccionActual?.isNotEmpty ?? false)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                'SECCIÓN: ${_seccionActual ?? ''}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B4332),
                                ),
                              ),
                            ),
                          if (_jefaturaActual?.isNotEmpty ?? false)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                'JEFATURA: ${_jefaturaActual ?? ''}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB68900),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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
                                          final isJefatura =
                                              _headers[colIdx] == 'JEFATURA';
                                          final isSeccion =
                                              _headers[colIdx] == 'SECCION';
                                          final isValidacion =
                                              _headers[colIdx] == 'VALIDACION';
                                          final isBox =
                                              _headers[colIdx] == 'BOX';
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
                                                child: isBox
                                                    ? Checkbox(
                                                        value: _rows[rowIdx]
                                                                    [colIdx]
                                                                .text
                                                                .trim()
                                                                .toUpperCase() ==
                                                            'FALTANTE',
                                                        onChanged: (checked) {
                                                          setState(() {
                                                            _rows[rowIdx]
                                                                        [colIdx]
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
                                                              _rows[rowIdx]
                                                                      [colIdx]
                                                                  .text,
                                                              style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                      0xFF2D6A4F)),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
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
                                                                  final jefatura =
                                                                      await _buscarJefaturaFirestore(
                                                                          value
                                                                              .trim());
                                                                  setState(() {
                                                                    _rows[rowIdx][_headers.indexOf('JEFATURA')]
                                                                            .text =
                                                                        jefatura;
                                                                  });
                                                                },
                                                              )
                                                            : isValidacion
                                                                ? (_rows[rowIdx][colIdx]
                                                                            .text
                                                                            .trim() ==
                                                                        '✔️'
                                                                    ? const Icon(
                                                                        Icons
                                                                            .check,
                                                                        color: Colors
                                                                            .green,
                                                                        size:
                                                                            24)
                                                                    : TextField(
                                                                        controller:
                                                                            _rows[rowIdx][colIdx],
                                                                        decoration:
                                                                            const InputDecoration(
                                                                          border:
                                                                              InputBorder.none,
                                                                          isDense:
                                                                              true,
                                                                          contentPadding: EdgeInsets.symmetric(
                                                                              vertical: 8,
                                                                              horizontal: 4),
                                                                        ),
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                14),
                                                                      ))
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
                                                                      border: InputBorder
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
