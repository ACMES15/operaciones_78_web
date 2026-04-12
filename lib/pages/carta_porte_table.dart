import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import '../utils/firebase_cache_utils.dart';
import '../utils/exportar_excel.dart';
import 'carta_porte_printer.dart';
import 'carta_porte_imprimir_page.dart';
// import 'hoja_de_ruta_extra_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:math' as math;
import '../models/hoja_de_xd_historial.dart';
import '../utils/skus_utils.dart' as skus_utils;

class CartaPorteTable extends StatefulWidget {
  const CartaPorteTable({super.key});
  @override
  State<CartaPorteTable> createState() => _CartaPorteTableState();
}

class _CartaPorteTableState extends State<CartaPorteTable> {
  void _copiarColumnaConcentrado() {
    final idx = _columns.indexWhere(
        (c) => c.toUpperCase().replaceAll('.', '').trim() == 'CONCENTRADO');
    if (idx == -1) return;
    final valores = _controllers
        .map((row) => row[idx].text)
        .where((v) => v.trim().isNotEmpty)
        .join('\n');
    Clipboard.setData(ClipboardData(text: valores));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Columna CONCENTRADO copiada')));
  }

  Future<void> _imprimirHoja() async {
    final columns = _columns;
    final table = <List<String>>[];
    for (int rowIdx = 0; rowIdx < _controllers.length; rowIdx++) {
      final row = <String>[];
      bool tieneDato = false;
      for (int colIdx = 0; colIdx < columns.length; colIdx++) {
        String valor;
        if (columns[colIdx].toUpperCase().replaceAll('.', '').trim() == 'NO') {
          valor = (rowIdx + 1).toString();
        } else if (_controllers[rowIdx].length > colIdx) {
          valor = _controllers[rowIdx][colIdx].text;
        } else {
          valor = '';
        }
        if (valor.trim().isNotEmpty &&
            columns[colIdx].toUpperCase().replaceAll('.', '').trim() != 'NO') {
          tieneDato = true;
        }
        row.add(valor);
      }
      if (tieneDato) {
        table.add(row);
      }
    }
    if (table.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para imprimir.')),
      );
      return;
    }
    final hoja = {
      'fecha': _fechaActual,
      'chofer':
          _choferesSeleccionados.isNotEmpty ? _choferesSeleccionados.first : '',
      'unidad': _unidadController.text,
      'destino': _destinoController.text,
      'rfc': _rfcController.text,
      'licencia': _licenciaSeleccionada,
      'numero_control': _numeroControlActual ?? '',
      'filas': [
        for (final fila in table) Map.fromIterables(columns, fila),
      ],
    };
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartaPorteImprimirPage(carta: hoja),
      ),
    );
  }

  Future<void> _imprimirHojaEspecial(String destino, String titulo) async {
    final columns = _columns;
    final table = <List<String>>[];
    for (int rowIdx = 0; rowIdx < _controllers.length; rowIdx++) {
      final row = <String>[];
      bool tieneDato = false;
      for (int colIdx = 0; colIdx < columns.length; colIdx++) {
        String valor;
        if (columns[colIdx].toUpperCase().replaceAll('.', '').trim() == 'NO') {
          valor = (rowIdx + 1).toString();
        } else if (_controllers[rowIdx].length > colIdx) {
          valor = _controllers[rowIdx][colIdx].text;
        } else {
          valor = '';
        }
        if (valor.trim().isNotEmpty &&
            columns[colIdx].toUpperCase().replaceAll('.', '').trim() != 'NO') {
          tieneDato = true;
        }
        row.add(valor);
      }
      // Filtrar solo filas con el destino indicado
      final idxDestino = columns.indexOf('DESTINO');
      if (tieneDato && idxDestino != -1 && row[idxDestino].trim() == destino) {
        table.add(row);
      }
    }
    if (table.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No hay datos para imprimir para destino $destino.')),
      );
      return;
    }
    final hoja = {
      'fecha': _fechaActual,
      'chofer':
          _choferesSeleccionados.isNotEmpty ? _choferesSeleccionados.first : '',
      'unidad': _unidadController.text,
      'destino': titulo,
      'rfc': _rfcController.text,
      'licencia': _licenciaSeleccionada,
      'numero_control': _numeroControlActual ?? '',
      'filas': [
        for (final fila in table) Map.fromIterables(columns, fila),
      ],
    };
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartaPorteImprimirPage(carta: hoja),
      ),
    );
  }

  int _numFilas = 5;
  // Campos ejecutivos principales
  // final _formKey = GlobalKey<FormState>();
  final TextEditingController _rfcController = TextEditingController();
  String _licenciaSeleccionada = '';
  final TextEditingController _choferController = TextEditingController();
  final TextEditingController _unidadController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  List<Map<String, dynamic>> _choferes = [];
  List<String> _choferesSeleccionados = [];
  String? _numeroControlActual;
  late String _fechaActual;
  final List<String> _columns = [
    'ESCANEO',
    'NO.',
    'TIPO',
    'SYS',
    'EMBARQUE',
    'DESCRIPCIÓN / COMENTARIOS',
    'NO. DE BULTOS',
    'DESTINO',
    'CONTENEDOR',
    'EMBARQUE',
    'CONCENTRADO',
  ];
  List<List<TextEditingController>> _controllers = [];
  List<List<FocusNode>> _focusNodes = [];
  List<double> colWidths = [
    120, // ESCANEO
    50, // NO.
    120, // TIPO
    120, // SYS
    120, // EMBARQUE
    282, // DESCRIPCIÓN / COMENTARIOS (ajustado para que quepa en pantalla)
    70, // NO. DE BULTOS (más pequeño)
    60, // DESTINO (más pequeño)
    120, // CONTENEDOR
    120, // EMBARQUE
    120 // CONCENTRADO
  ];

  Future<void> _autocompletarFilaPorEscaneo(int rowIdx) async {
    try {
      print('Iniciando autocompletarFilaPorEscaneo para fila $rowIdx');
      final escaneo = _controllers[rowIdx][0].text.trim();
      final escaneoLower = escaneo.toLowerCase();
      print('Valor de escaneo: "$escaneo"');
      if (escaneo.isEmpty) return;

      // Buscar en hoja_ruta (todas las coincidencias)
      final hojaRutaSnap = await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .orderBy('fecha', descending: true)
          .get();
      final hojaRutaDocs = hojaRutaSnap.docs
          .where((doc) =>
              (doc.data()['caja'] ?? '').toString().trim().toLowerCase() ==
              escaneoLower)
          .toList();

      // Buscar en hoja_de_xd_historial (todas las coincidencias)
      final xdSnap = await FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .orderBy('fecha', descending: true)
          .get();
      List<HojaDeXDHistorial> xd = xdSnap.docs
          .map((doc) => HojaDeXDHistorial.fromJson(doc.data()))
          .where((h) =>
              (h.datos['CONTENEDOR O TARIMA'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase() ==
              escaneoLower)
          .toList();

      // Si no hay resultados directos, buscar por 'CONTENEDOR' o 'TARIMA' en todos los docs de hoja_de_xd_historial
      if (xd.isEmpty) {
        final allDocs = await FirebaseFirestore.instance
            .collection('hoja_de_xd_historial')
            .orderBy('fecha', descending: true)
            .get();
        xd = allDocs.docs
            .map((doc) => HojaDeXDHistorial.fromJson(doc.data()))
            .where((h) => ((h.datos['CONTENEDOR O TARIMA'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase() ==
                    escaneoLower ||
                (h.datos['TARIMA'] ?? '').toString().trim().toLowerCase() ==
                    escaneoLower))
            .toList();
      }

      // Unificar todos los resultados en una lista con tipo y fecha
      final List<Map<String, dynamic>> resultados = [];
      for (final doc in hojaRutaDocs) {
        final data = doc.data();
        if (data['fecha'] != null) {
          resultados.add({
            'tipo': 'hoja_ruta',
            'fecha': data['fecha'],
            'data': data,
          });
        }
      }
      for (final h in xd) {
        resultados.add({
          'tipo': 'xd',
          'fecha': h.fecha,
          'data': h,
        });
      }

      if (resultados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se encontró información para "$escaneo" en Firestore.')),
        );
        print('No se encontró información para "$escaneo" en ninguna fuente.');
        return;
      }

      // Elegir el resultado más reciente
      DateTime _toDate(dynamic f) {
        if (f is DateTime) return f;
        if (f is Timestamp) return f.toDate();
        if (f is String) {
          try {
            return DateTime.parse(f);
          } catch (_) {
            return DateTime(1970);
          }
        }
        return DateTime(1970);
      }

      resultados.sort((a, b) {
        final fa = _toDate(a['fecha']);
        final fb = _toDate(b['fecha']);
        return fb.compareTo(fa);
      });
      final masReciente = resultados.first;

      if (masReciente['tipo'] == 'hoja_ruta') {
        final ruta = masReciente['data'];
        print('Datos hoja_ruta usados: $ruta');
        _controllers[rowIdx][2].text = ruta['tipo'] ?? '';
        _controllers[rowIdx][3].text = 'SAP';
        final rows = (ruta['rows'] as List?) ?? [];
        String embarque = '';
        for (final row in rows) {
          if (row is Map) {
            if ((row['No. Manifiesto o Remisión'] != null &&
                row['No. Manifiesto o Remisión'].toString().isNotEmpty)) {
              embarque = row['No. Manifiesto o Remisión'].toString();
              break;
            } else if ((row['Rem'] != null &&
                row['Rem'].toString().isNotEmpty)) {
              embarque = row['Rem'].toString();
              break;
            }
          } else if (row is List) {
            final columns = (ruta['columns'] as List?) ?? [];
            final idx = columns.indexWhere((c) =>
                c.toString().toLowerCase().contains('manifiesto') ||
                c.toString().toLowerCase().contains('rem'));
            if (idx >= 0 &&
                row.length > idx &&
                row[idx] != null &&
                row[idx].toString().isNotEmpty) {
              embarque = row[idx].toString();
              break;
            }
          }
        }
        _controllers[rowIdx][4].text = embarque;
        _controllers[rowIdx][5].text = ruta['tipo'] ?? '';
        int sumaBultos = 0;
        for (final row in rows) {
          if (row is Map && row['No. Bultos'] != null) {
            final val = int.tryParse(row['No. Bultos'].toString());
            if (val != null) sumaBultos += val;
          } else if (row is List) {
            final columns = (ruta['columns'] as List?) ?? [];
            final idx = columns.indexWhere(
                (c) => c.toString().toLowerCase().contains('bultos'));
            if (idx >= 0 && row.length > idx && row[idx] != null) {
              final val = int.tryParse(row[idx].toString());
              if (val != null) sumaBultos += val;
            }
          }
        }
        _controllers[rowIdx][6].text =
            sumaBultos > 0 ? sumaBultos.toString() : '';
        String destino = '';
        for (final row in rows) {
          if (row is Map &&
              row['No. Alm.'] != null &&
              row['No. Alm.'].toString().isNotEmpty) {
            destino = row['No. Alm.'].toString();
            break;
          } else if (row is List) {
            final columns = (ruta['columns'] as List?) ?? [];
            final idx = columns
                .indexWhere((c) => c.toString().toLowerCase().contains('alm'));
            if (idx >= 0 &&
                row.length > idx &&
                row[idx] != null &&
                row[idx].toString().isNotEmpty) {
              destino = row[idx].toString();
              break;
            }
          }
        }
        _controllers[rowIdx][7].text = destino;
        _controllers[rowIdx][8].text = escaneo;
        final embarque1 = _controllers[rowIdx][4].text;
        final embarque2 = _controllers[rowIdx][9].text;
        _controllers[rowIdx][10].text =
            embarque1.isNotEmpty ? embarque1 : embarque2;
        setState(() {});
        return;
      } else if (masReciente['tipo'] == 'xd') {
        final HojaDeXDHistorial h = masReciente['data'];
        print('Datos hoja_de_xd_historial encontrados: ${h.datos}');
        _controllers[rowIdx][2].text = 'PAQ';
        // Lógica SYS según TU
        final tu = (h.datos['TU'] ?? '').trim();
        if (tu.isNotEmpty) {
          _controllers[rowIdx][3].text = 'MAN';
        } else {
          _controllers[rowIdx][3].text = 'XD';
        }
        _controllers[rowIdx][5].text = h.datos['MANIFIESTO'] ?? '';
        _controllers[rowIdx][6].text = h.datos['CANTIDAD DE LPS'] ?? '';
        _controllers[rowIdx][7].text = h.datos['DESTINO'] ?? '';
        _controllers[rowIdx][8].text = escaneo;
        final embarque1 = _controllers[rowIdx][4].text;
        final embarque2 = _controllers[rowIdx][9].text;
        _controllers[rowIdx][10].text =
            embarque1.isNotEmpty ? embarque1 : embarque2;
        setState(() {});
        return;
      }
    } catch (e, stack) {
      print('ERROR en autocompletarFilaPorEscaneo: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  void _actualizarRFC() {
    if (_choferesSeleccionados.isNotEmpty) {
      final chofer = _choferes.firstWhere(
        (c) => _choferesSeleccionados.contains(c['nombre']),
        orElse: () => {'rfc': '', 'licencia': ''},
      );
      _rfcController.text = chofer['rfc'] ?? '';
      _licenciaSeleccionada = chofer['licencia'] ?? '';
    } else {
      _rfcController.text = '';
      _licenciaSeleccionada = '';
    }
    setState(() {});
  }

  Future<void> _guardarCartaPorte() async {
    // Validación de campos obligatorios
    if (_numeroControlActual == null ||
        _choferesSeleccionados.isEmpty ||
        _unidadController.text.trim().isEmpty ||
        _destinoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Por favor, completa todos los campos obligatorios.')),
      );
      return;
    }

    // Validar que haya al menos una fila con datos relevantes
    final filas = _controllers
        .map((row) => Map.fromIterables(_columns, row.map((c) => c.text)))
        .where((fila) =>
            fila.values.any((valor) => valor.toString().trim().isNotEmpty))
        .toList();
    if (filas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una fila con datos.')),
      );
      return;
    }

    final data = {
      'numero_control': _numeroControlActual,
      'fecha': _fechaActual,
      'chofer':
          _choferesSeleccionados.isNotEmpty ? _choferesSeleccionados.first : '',
      'rfc': _rfcController.text,
      'unidad': _unidadController.text,
      'destino': _destinoController.text,
      'filas': filas,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('cartas_porte').add(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carta Porte guardada exitosamente.')),
      );
      // Limpiar campos y filas
      setState(() {
        _numeroControlActual = null;
        _choferController.clear();
        _rfcController.clear();
        _unidadController.clear();
        _destinoController.clear();
        _choferesSeleccionados.clear();
        _numFilas = 5;
        _controllers = List.generate(
            _numFilas,
            (_) =>
                List.generate(_columns.length, (_) => TextEditingController()));
        _focusNodes = List.generate(_numFilas,
            (_) => List.generate(_columns.length, (_) => FocusNode()));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Future<void> _generarNumeroControl() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('cartas_porte')
        .orderBy('numero_control', descending: true)
        .limit(1)
        .get();
    int next = 1;
    if (snapshot.docs.isNotEmpty) {
      final last = snapshot.docs.first['numero_control'] as String?;
      if (last != null && last.startsWith('0078-CP-')) {
        final numStr = last.substring(8);
        final num = int.tryParse(numStr) ?? 0;
        next = num + 1;
      }
    }
    _numeroControlActual = '0078-CP-${next.toString().padLeft(3, '0')}';
    setState(() {});
  }

  Future<void> _exportarExcel() async {
    final carta = {
      'NUMERO_CONTROL': _numeroControlActual ?? '',
      'FECHA': _fechaActual,
      'CHOFER':
          _choferesSeleccionados.isNotEmpty ? _choferesSeleccionados.first : '',
      'RFC': _rfcController.text,
      'UNIDAD': _unidadController.text,
      'DESTINO': _destinoController.text,
      'COLUMNS': _columns,
      'TABLE':
          _controllers.map((row) => row.map((c) => c.text).toList()).toList(),
    };
    await exportarExcel(
        cartas: [carta],
        fileName: 'carta_porte_${DateTime.now().millisecondsSinceEpoch}.xlsx');
  }

  Future<void> _imprimirHoja1() async {
    final columns = _columns;
    final table = <List<String>>[];
    for (int rowIdx = 0; rowIdx < _controllers.length; rowIdx++) {
      final row = <String>[];
      bool tieneDato = false;
      for (int colIdx = 0; colIdx < columns.length; colIdx++) {
        String valor;
        if (columns[colIdx].toUpperCase().replaceAll('.', '').trim() == 'NO') {
          valor = (rowIdx + 1).toString();
        } else if (_controllers[rowIdx].length > colIdx) {
          valor = _controllers[rowIdx][colIdx].text;
        } else {
          valor = '';
        }
        if (valor.trim().isNotEmpty &&
            columns[colIdx].toUpperCase().replaceAll('.', '').trim() != 'NO') {
          tieneDato = true;
        }
        row.add(valor);
      }
      if (tieneDato) {
        table.add(row);
      }
    }
    if (table.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para imprimir.')),
      );
      return;
    }
    final hoja = {
      'fecha': _fechaActual,
      'chofer':
          _choferesSeleccionados.isNotEmpty ? _choferesSeleccionados.first : '',
      'unidad': _unidadController.text,
      'destino': _destinoController.text,
      'rfc': _rfcController.text,
      'licencia': _licenciaSeleccionada,
      'numero_control': _numeroControlActual ?? '',
      'filas': [
        for (final fila in table) Map.fromIterables(columns, fila),
      ],
    };
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartaPorteImprimirPage(carta: hoja),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fechaActual = DateTime.now().toString().substring(0, 10);
    _cargarChoferes();
    // Inicializa controladores para las filas iniciales
    _controllers = List.generate(_numFilas,
        (_) => List.generate(_columns.length, (_) => TextEditingController()));
    _focusNodes = List.generate(
        _numFilas, (_) => List.generate(_columns.length, (_) => FocusNode()));
  }

  Future<void> _cargarChoferes() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('choferes').get();
    setState(() {
      _choferes = snapshot.docs
          .map((doc) => {
                'nombre': doc['nombre'],
                'rfc': doc['rfc'],
                'telefono': doc['telefono'],
                'licencia': doc['licencia'] ?? '',
              })
          .toList();
    });
  }

  Future<void> _mostrarDialogoChoferes() async {
    TextEditingController nombreController = TextEditingController();
    TextEditingController rfcController = TextEditingController();
    TextEditingController telController = TextEditingController();
    TextEditingController licenciaController = TextEditingController();
    int? editIndex;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool camposLlenos = nombreController.text.trim().isNotEmpty &&
                rfcController.text.trim().isNotEmpty &&
                telController.text.trim().isNotEmpty &&
                licenciaController.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('Gestionar Choferes'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lista scrollable de choferes
                    SizedBox(
                      height: 250,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('choferes')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final choferes = snapshot.data?.docs ?? [];
                          return ListView.separated(
                            itemCount: choferes.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, i) => ListTile(
                              title: Text(choferes[i]['nombre'] ?? ''),
                              subtitle: Text(
                                  '${choferes[i]['rfc'] ?? ''} | ${choferes[i]['telefono'] ?? ''} | Licencia: ${choferes[i]['licencia'] ?? ''}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () {
                                      nombreController.text =
                                          choferes[i]['nombre'] ?? '';
                                      rfcController.text =
                                          choferes[i]['rfc'] ?? '';
                                      telController.text =
                                          choferes[i]['telefono'] ?? '';
                                      licenciaController.text =
                                          choferes[i]['licencia'] ?? '';
                                      editIndex = i;
                                      setStateDialog(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('choferes')
                                          .doc(choferes[i].id)
                                          .delete();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    // Formulario siempre visible
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    TextField(
                      controller: rfcController,
                      decoration: const InputDecoration(labelText: 'RFC'),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    TextField(
                      controller: telController,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    TextField(
                      controller: licenciaController,
                      decoration: const InputDecoration(labelText: 'Licencia'),
                      onChanged: (_) => setStateDialog(() {}),
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
                  onPressed: camposLlenos
                      ? () async {
                          final nombre = nombreController.text.trim();
                          final rfc = rfcController.text.trim();
                          final tel = telController.text.trim();
                          final licencia = licenciaController.text.trim();
                          if (editIndex != null) {
                            // Editar chofer
                            final snapshot = await FirebaseFirestore.instance
                                .collection('choferes')
                                .get();
                            final docId = snapshot.docs[editIndex!].id;
                            await FirebaseFirestore.instance
                                .collection('choferes')
                                .doc(docId)
                                .update({
                              'nombre': nombre,
                              'rfc': rfc,
                              'telefono': tel,
                              'licencia': licencia,
                            });
                          } else {
                            // Agregar nuevo chofer
                            await FirebaseFirestore.instance
                                .collection('choferes')
                                .add({
                              'nombre': nombre,
                              'rfc': rfc,
                              'telefono': tel,
                              'licencia': licencia,
                            });
                          }
                          nombreController.clear();
                          rfcController.clear();
                          telController.clear();
                          licenciaController.clear();
                          editIndex = null;
                          setStateDialog(() {});
                          _cargarChoferes();
                        }
                      : null,
                  child: Text(editIndex != null ? 'Actualizar' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const Icon(Icons.local_shipping, color: Colors.white, size: 32),
            const SizedBox(width: 10),
            const Text(
              'Carta Porte',
              style: TextStyle(
                color: Colors.white,
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
            color: Colors.white,
            onPressed: _exportarExcel,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir hoja',
            color: Colors.white,
            onPressed: _imprimirHoja,
          ),
          IconButton(
            icon: const Icon(Icons.description),
            tooltip: 'Hojas de ruta especial 880',
            color: Colors.white,
            onPressed: () async {
              await _imprimirHojaEspecial('880', 'HOJA DE RUTA : 880 PLAN N5');
            },
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Hojas de ruta especial 94',
            color: Colors.white,
            onPressed: () async {
              await _imprimirHojaEspecial('94', 'HOJA DE RUTA : 94 BAJIO');
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Choferes',
            color: Colors.white,
            onPressed: _mostrarDialogoChoferes,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado ejecutivo
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('78 GALERIAS GDL',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 1.1)),
                  SizedBox(
                    width: isMobile ? double.infinity : 180,
                    child: TextFormField(
                      controller: _destinoController,
                      style: const TextStyle(
                          color: Color(0xFF2D6A4F),
                          fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Destino',
                        isDense: true,
                        border: InputBorder.none,
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 180,
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _choferesSeleccionados.isNotEmpty
                                ? _choferesSeleccionados.first
                                : null,
                            items: _choferes
                                .map((c) => DropdownMenuItem<String>(
                                      value: c['nombre'],
                                      child: Text(c['nombre']),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _choferesSeleccionados =
                                    value != null ? [value] : [];
                                _actualizarRFC();
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Chofer',
                              isDense: true,
                              border: InputBorder.none,
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            style: const TextStyle(
                                color: Color(0xFF2D6A4F),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.people,
                              color: Color(0xFF2D6A4F)),
                          tooltip: 'Gestionar Choferes',
                          onPressed: _mostrarDialogoChoferes,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 120,
                    child: TextFormField(
                      controller: _unidadController,
                      style: const TextStyle(
                          color: Color(0xFF2D6A4F),
                          fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        isDense: true,
                        border: OutlineInputBorder(),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 150,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rfcController,
                            readOnly: true,
                            style: const TextStyle(
                                color: Color(0xFF2D6A4F),
                                fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: 'RFC',
                              isDense: true,
                              border: OutlineInputBorder(),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            controller: TextEditingController(
                                text: _licenciaSeleccionada),
                            style: const TextStyle(
                                color: Color(0xFF2D6A4F),
                                fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: 'Licencia',
                              isDense: true,
                              border: OutlineInputBorder(),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(_fechaActual,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Tabla ejecutiva
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFB),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                padding: const EdgeInsets.all(12),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: colWidths.reduce((a, b) => a + b) + 40,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Copiar columna CONCENTRADO',
                                icon: const Icon(Icons.copy),
                                color: Color(0xFF2D6A4F),
                                onPressed: _copiarColumnaConcentrado,
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                          // Sticky header
                          Material(
                            elevation: 2,
                            color: const Color(0xFF2D6A4F),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                            child: Row(
                              children: [
                                for (int i = 0; i < _columns.length; i++)
                                  Container(
                                    width: i == _columns.length - 1
                                        ? colWidths[i] + 8
                                        : colWidths[i],
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: i == _columns.length - 1
                                          ? null
                                          : const Border(
                                              right: BorderSide(
                                                  color: Color(0xFFE0E0E0),
                                                  width: 1)),
                                    ),
                                    child: Text(
                                      _columns[i],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 16,
                                          letterSpacing: 1.1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Filas ejecutivas
                          Expanded(
                            child: ListView.builder(
                              itemCount: _numFilas,
                              itemBuilder: (context, rowIdx) {
                                return MouseRegion(
                                  cursor: SystemMouseCursors.text,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: rowIdx % 2 == 0
                                          ? const Color(0xFFF1F3F6)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE0E0E0),
                                          width: 0.5),
                                    ),
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        for (int colIdx = 0;
                                            colIdx < _columns.length;
                                            colIdx++)
                                          Container(
                                            width: colWidths[colIdx],
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: colIdx <
                                                      _columns.length - 1
                                                  ? const Border(
                                                      right: BorderSide(
                                                          color:
                                                              Color(0xFFE0E0E0),
                                                          width: 1))
                                                  : null,
                                            ),
                                            child:
                                                _columns[colIdx]
                                                            .toUpperCase()
                                                            .replaceAll('.', '')
                                                            .trim() ==
                                                        'NO'
                                                    ? Text(
                                                        (rowIdx + 1).toString(),
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15,
                                                            color: Color(
                                                                0xFF2D6A4F)),
                                                      )
                                                    : _columns[colIdx]
                                                                .toUpperCase()
                                                                .replaceAll(
                                                                    '.', '')
                                                                .trim() ==
                                                            'CONCENTRADO'
                                                        ? Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    SelectableText(
                                                                  _controllers[
                                                                              rowIdx]
                                                                          [
                                                                          colIdx]
                                                                      .text,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          15,
                                                                      color: Color(
                                                                          0xFF2D6A4F)),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                ),
                                                              ),
                                                              FutureBuilder<
                                                                  List<
                                                                      List<
                                                                          String>>>(
                                                                future: _numeroControlActual !=
                                                                            null &&
                                                                        _controllers[rowIdx][colIdx]
                                                                            .text
                                                                            .isNotEmpty
                                                                    ? skus_utils.obtenerSkusLigadosHojaDeRuta(
                                                                        _controllers[rowIdx][colIdx]
                                                                            .text)
                                                                    : Future
                                                                        .value(
                                                                            []),
                                                                builder: (context,
                                                                    snapshot) {
                                                                  if (snapshot
                                                                          .connectionState ==
                                                                      ConnectionState
                                                                          .waiting) {
                                                                    return const SizedBox(
                                                                        width:
                                                                            24,
                                                                        height:
                                                                            24,
                                                                        child: CircularProgressIndicator(
                                                                            strokeWidth:
                                                                                2));
                                                                  }
                                                                  final skus =
                                                                      snapshot.data ??
                                                                          [];
                                                                  if (skus
                                                                      .isNotEmpty) {
                                                                    return Tooltip(
                                                                      message:
                                                                          'Copiar SKUs ligados',
                                                                      child:
                                                                          IconButton(
                                                                        icon: const Icon(
                                                                            Icons
                                                                                .copy,
                                                                            size:
                                                                                20,
                                                                            color:
                                                                                Colors.green),
                                                                        onPressed:
                                                                            () {
                                                                          final texto =
                                                                              skus_utils.skusToTexto(skus);
                                                                          Clipboard.setData(
                                                                              ClipboardData(text: texto));
                                                                          ScaffoldMessenger.of(context)
                                                                              .showSnackBar(
                                                                            const SnackBar(content: Text('SKUs ligados copiados')),
                                                                          );
                                                                        },
                                                                      ),
                                                                    );
                                                                  }
                                                                  return const SizedBox
                                                                      .shrink();
                                                                },
                                                              ),
                                                            ],
                                                          )
                                                        : TextFormField(
                                                            controller: _controllers
                                                                            .length >
                                                                        rowIdx &&
                                                                    _controllers[rowIdx]
                                                                            .length >
                                                                        colIdx
                                                                ? _controllers[
                                                                        rowIdx]
                                                                    [colIdx]
                                                                : null,
                                                            focusNode: _focusNodes
                                                                            .length >
                                                                        rowIdx &&
                                                                    _focusNodes[rowIdx]
                                                                            .length >
                                                                        colIdx
                                                                ? _focusNodes[
                                                                        rowIdx]
                                                                    [colIdx]
                                                                : null,
                                                            textAlign: TextAlign
                                                                .center,
                                                            decoration:
                                                                const InputDecoration(
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      vertical:
                                                                          8,
                                                                      horizontal:
                                                                          4),
                                                              fillColor:
                                                                  Colors.white,
                                                              filled: true,
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                            ),
                                                            style: const TextStyle(
                                                                fontSize: 15,
                                                                color: Color(
                                                                    0xFF2D6A4F)),
                                                            onChanged: colIdx ==
                                                                        4 ||
                                                                    colIdx == 9
                                                                ? (value) {
                                                                    // Actualizar concentrado automáticamente
                                                                    final embarque1 =
                                                                        _controllers[rowIdx][4]
                                                                            .text;
                                                                    final embarque2 =
                                                                        _controllers[rowIdx][9]
                                                                            .text;
                                                                    _controllers[rowIdx]
                                                                            [10]
                                                                        .text = embarque1
                                                                            .isNotEmpty
                                                                        ? embarque1
                                                                        : embarque2;
                                                                    // Forzar actualización visual
                                                                    setState(
                                                                        () {});
                                                                  }
                                                                : null,
                                                            onFieldSubmitted:
                                                                colIdx == 0
                                                                    ? (_) async {
                                                                        await _autocompletarFilaPorEscaneo(
                                                                            rowIdx);
                                                                        final isPenultima =
                                                                            rowIdx ==
                                                                                _controllers.length - 2;
                                                                        if (isPenultima) {
                                                                          setState(
                                                                              () {
                                                                            _numFilas++;
                                                                            _controllers.add(List.generate(_columns.length,
                                                                                (_) => TextEditingController()));
                                                                            _focusNodes.add(List.generate(_columns.length,
                                                                                (_) => FocusNode()));
                                                                          });
                                                                          Future.delayed(
                                                                              const Duration(milliseconds: 100),
                                                                              () {
                                                                            FocusScope.of(context).requestFocus(_focusNodes[rowIdx +
                                                                                1][0]);
                                                                          });
                                                                        } else if (rowIdx <
                                                                            _controllers.length -
                                                                                1) {
                                                                          FocusScope.of(context).requestFocus(_focusNodes[rowIdx + 1]
                                                                              [
                                                                              0]);
                                                                        }
                                                                      }
                                                                    : null,
                                                          ),
                                          ),
                                      ],
                                    ),
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
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.confirmation_number),
                  label: const Text('Número de Control'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 242, 244, 243)),
                  onPressed: _generarNumeroControl,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 246, 248, 247)),
                  onPressed: _guardarCartaPorte,
                ),
              ],
            ),
            if (_numeroControlActual != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text(
                  'Número de Control: $_numeroControlActual',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1B4332)),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar fila'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 243, 245, 244)),
                  onPressed: () {
                    setState(() {
                      _numFilas++;
                      _controllers.add(List.generate(
                          _columns.length, (_) => TextEditingController()));
                      _focusNodes.add(
                          List.generate(_columns.length, (_) => FocusNode()));
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
