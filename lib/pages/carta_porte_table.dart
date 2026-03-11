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
    // Siempre mantener al menos 5 filas visibles
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
    // Limpiar todos los campos y dejar lista la carta porte para nuevos datos
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
    // Formato: 0078-CP-XXX (con ceros a la izquierda)
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
    final nuevoNum = '0078-CP-${siguiente.toString().padLeft(3, '0')}';
    return nuevoNum;
  }

  @override
  Widget build(BuildContext context) {
    // Ajuste visual: título y fondo
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
                fontSize: 24,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Container(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 24.0),
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
                          onPressed: () {
                            // TODO: lógica de guardado
                          },
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
                              _controllers.add(List.generate(_columns.length,
                                  (_) => TextEditingController()));
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
                                content: Text(
                                    'Número de control generado: $nuevoNum'),
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
                            // TODO: mostrar diálogo de choferes
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
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
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
                                        border: Border.all(
                                            color: Color(0xFF2D6A4F)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.confirmation_number,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
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
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 160,
                                  child: DropdownButtonFormField<int>(
                                    value: _choferSeleccionado,
                                    items: [
                                      for (int i = 0; i < _choferes.length; i++)
                                        DropdownMenuItem(
                                          value: i,
                                          child: Text(
                                              _choferes[i]['nombre'] ?? ''),
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
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
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
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
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
                            child: ListView(
                              shrinkWrap: true,
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
                                                      fontWeight:
                                                          FontWeight.bold))
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
              ),
            );
          },
        ),
      ),
    );
  }
}
