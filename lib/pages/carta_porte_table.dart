import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import '../utils/firebase_cache_utils.dart';
import '../utils/exportar_excel.dart';
import 'carta_porte_printer.dart';
// import 'hoja_de_ruta_extra_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:math' as math;
import '../models/hoja_de_xd_historial.dart';

class CartaPorteTable extends StatefulWidget {
  const CartaPorteTable({super.key});
  @override
  State<CartaPorteTable> createState() => _CartaPorteTableState();
}

class _CartaPorteTableState extends State<CartaPorteTable> {
  int _numFilas = 5;
  // Campos ejecutivos principales
  // final _formKey = GlobalKey<FormState>();
  final TextEditingController _rfcController = TextEditingController();
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
    120,
    60,
    120,
    120,
    120,
    180,
    120,
    120,
    120,
    120,
    120
  ];

  Future<void> _autocompletarFilaPorEscaneo(int rowIdx) async {
    try {
      print('Iniciando autocompletarFilaPorEscaneo para fila $rowIdx');
      final escaneo = _controllers[rowIdx][0].text.trim();
      print('Valor de escaneo: "$escaneo"');
      if (escaneo.isEmpty) return;

      // 1. Buscar en Firestore: hoja_ruta
      final hojaRutaSnap = await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .where('caja', isEqualTo: escaneo)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();
      print(
          'Consulta hoja_ruta para $escaneo: ${hojaRutaSnap.docs.length} resultados');
      for (var doc in hojaRutaSnap.docs) {
        print('Documento hoja_ruta encontrado: ${doc.data()}');
        print('Comparando caja: "${doc.data()['caja']}" == "$escaneo"');
      }
      if (hojaRutaSnap.docs.isNotEmpty) {
        final ruta = hojaRutaSnap.docs.first.data();
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
      }

      // 2. Buscar en Firestore: hoja_de_xd_historial
      // 1. Buscar por 'CONTENEDOR O TARIMA'
      final xdSnap = await FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .where('CONTENEDOR O TARIMA', isEqualTo: escaneo)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();
      print('Consulta hoja_de_xd_historial: ${xdSnap.docs.length} documentos');
      List<HojaDeXDHistorial> xd = xdSnap.docs
          .map((doc) => HojaDeXDHistorial.fromJson(doc.data()))
          .where(
              (h) => (h.datos['CONTENEDOR O TARIMA'] ?? '').trim() == escaneo)
          .toList();
      print(
          'Coincidencias en hoja_de_xd_historial (CONTENEDOR O TARIMA): ${xd.length}');
      if (xd.isEmpty) {
        // 2. Si no hay resultados, buscar por 'CONTENEDOR' o 'TARIMA' en todos los docs
        final allDocs = await FirebaseFirestore.instance
            .collection('hoja_de_xd_historial')
            .orderBy('fecha', descending: true)
            .get();
        xd = allDocs.docs
            .map((doc) => HojaDeXDHistorial.fromJson(doc.data()))
            .where((h) =>
                ((h.datos['CONTENEDOR O TARIMA'] ?? '').trim() == escaneo ||
                    (h.datos['TARIMA'] ?? '').trim() == escaneo))
            .toList();
        print(
            'Coincidencias en hoja_de_xd_historial (CONTENEDOR/TARIMA): ${xd.length}');
      }
      xd.sort((a, b) => b.fecha.compareTo(a.fecha));
      if (xd.isNotEmpty) {
        final h = xd.first;
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

      // Si no encontró nada en ninguna fuente
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'No se encontró información para "$escaneo" en Firestore.')),
      );
      print('No se encontró información para "$escaneo" en ninguna fuente.');
    } catch (e, stack) {
      print('ERROR en autocompletarFilaPorEscaneo: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  void _actualizarRFC() {
    if (_choferesSeleccionados.isNotEmpty) {
      final rfcList = _choferes
          .where((c) => _choferesSeleccionados.contains(c['nombre']))
          .map((c) => c['rfc'])
          .toList();
      _rfcController.text = rfcList.join(', ');
    } else {
      _rfcController.text = '';
    }
  }

  Future<void> _guardarCartaPorte() async {
    final data = {
      'numero_control': _numeroControlActual,
      'fecha': _fechaActual,
      'chofer': _choferController.text,
      'rfc': _rfcController.text,
      'unidad': _unidadController.text,
      'destino': _destinoController.text,
      'filas':
          _controllers.map((row) => row.map((c) => c.text).toList()).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance.collection('cartas_porte').add(data);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Carta Porte guardada')));
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

  Future<void> _imprimirHoja() async {
    print('--- IMPRIMIR HOJA ---');
    print(
        'Chofer: ${_choferesSeleccionados.isNotEmpty ? _choferesSeleccionados.first : ''}');
    print('Unidad: ${_unidadController.text}');
    print('Destino: ${_destinoController.text}');
    print('RFC: ${_rfcController.text}');
    print('Fecha: $_fechaActual');
    print('Columns: $_columns');
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
    print('Tabla a imprimir:');
    for (final fila in table) {
      print(fila);
    }
    if (table.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para imprimir.')),
      );
      return;
    }
    CartaPortePrinter.printCartaPorte(
      chofer:
          _choferesSeleccionados.isNotEmpty ? _choferesSeleccionados.first : '',
      unidad: _unidadController.text,
      destino: _destinoController.text,
      rfc: _rfcController.text,
      fecha: _fechaActual,
      columns: columns,
      table: table,
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
              })
          .toList();
    });
  }

  Future<void> _mostrarDialogoChoferes() async {
    TextEditingController nombreController = TextEditingController();
    TextEditingController rfcController = TextEditingController();
    TextEditingController telController = TextEditingController();
    int? editIndex;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool camposLlenos = nombreController.text.trim().isNotEmpty &&
                rfcController.text.trim().isNotEmpty &&
                telController.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('Gestionar Choferes'),
              content: SizedBox(
                width: 350,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('choferes')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final choferes = snapshot.data?.docs ?? [];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < choferes.length; i++)
                          ListTile(
                            title: Text(choferes[i]['nombre'] ?? ''),
                            subtitle: Text(
                                '${choferes[i]['rfc'] ?? ''} | ${choferes[i]['telefono'] ?? ''}'),
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
                        const Divider(),
                        TextField(
                          controller: nombreController,
                          decoration:
                              const InputDecoration(labelText: 'Nombre'),
                          onChanged: (_) => setStateDialog(() {}),
                        ),
                        TextField(
                          controller: rfcController,
                          decoration: const InputDecoration(labelText: 'RFC'),
                          onChanged: (_) => setStateDialog(() {}),
                        ),
                        TextField(
                          controller: telController,
                          decoration:
                              const InputDecoration(labelText: 'Teléfono'),
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => setStateDialog(() {}),
                        ),
                      ],
                    );
                  },
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
                            });
                          } else {
                            // Agregar nuevo chofer
                            await FirebaseFirestore.instance
                                .collection('choferes')
                                .add({
                              'nombre': nombre,
                              'rfc': rfc,
                              'telefono': tel,
                            });
                          }
                          nombreController.clear();
                          rfcController.clear();
                          telController.clear();
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
                                                        ? TextFormField(
                                                            controller:
                                                                _controllers[
                                                                        rowIdx]
                                                                    [colIdx],
                                                            readOnly: true,
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
                                                                        if (rowIdx <
                                                                            _controllers.length -
                                                                                1) {
                                                                          FocusScope.of(context).requestFocus(_focusNodes[rowIdx + 1]
                                                                              [
                                                                              0]);
                                                                        } else if (isPenultima) {
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
