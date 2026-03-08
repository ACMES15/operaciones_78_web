import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/word_exporter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/firebase_cache_utils.dart';

class HojaDeXDPage extends StatefulWidget {
  const HojaDeXDPage({super.key});

  @override
  State<HojaDeXDPage> createState() => _HojaDeXDPageState();
}

class _HojaDeXDPageState extends State<HojaDeXDPage> {
  bool _cargandoXD = false;
  String? _ultimoDocIdXD;
  // Controla si se descargó el Word para cada fila
  final Set<int> _filasExportadas = {};

  /// Guarda la tabla completa de Hoja de XD en Firestore y caché local
  Future<void> guardarTablaHojaXD() async {
    final sheet = <String, dynamic>{
      'usuario': _usuario,
      'fecha': DateTime.now().toIso8601String(),
      'headers': _columns,
      'rows': _controllers
          .map((r) => r.map((c) => c.text.trim()).toList())
          .toList(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    // Usar el usuario y la fecha como ID único (puedes ajustar esto según tu lógica)
    final docId = '${_usuario}_${DateTime.now().millisecondsSinceEpoch}';
    await guardarDatosFirestoreYCache('hojas_xd', docId, sheet);
  }

  /// Lee la tabla de Hoja de XD desde caché o Firestore
  Future<Map<String, dynamic>?> leerTablaHojaXD(String docId) async {
    return await leerDatosConCache('hojas_xd', docId);
  }

  final List<String> _columns = [
    'DESTINO',
    'NOMBRE',
    'CONTENEDOR O TARIMA',
    'MANIFIESTO',
    'TU',
    'SKU',
    'FECHA',
    'CANTIDAD DE LPS',
    'CANTIDAD DE REMISIONES',
    'HORA DE MANIFIESTO',
  ];

  List<List<TextEditingController>> _controllers = [];
  String _usuario = '';

  bool _initialized = false;
  // bool _cargandoXD = false;
  // String? _ultimoDocIdXD;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    String nuevoUsuario;
    if (modalRoute != null && modalRoute.settings.arguments is String) {
      nuevoUsuario = modalRoute.settings.arguments as String;
    } else {
      nuevoUsuario = 'Usuario';
    }
    if (_usuario != nuevoUsuario) {
      _usuario = nuevoUsuario;
      for (var row in _controllers) {
        row[1].text = _usuario;
      }
    }
    // Inicializar filas solo una vez
    if (!_initialized) {
      _cargarUltimaHojaXD();
      _initialized = true;
    }
  }

  /// Carga la última hoja de XD guardada (si existe) desde caché o Firestore
  Future<void> _cargarUltimaHojaXD() async {
    setState(() {
      _cargandoXD = true;
    });
    // Aquí podrías guardar el último docId en SharedPreferences para saber cuál cargar
    final prefs = await SharedPreferences.getInstance();
    final lastDocId = prefs.getString('hoja_xd_last_docId');
    if (lastDocId != null) {
      final data = await leerTablaHojaXD(lastDocId);
      if (data != null && data['rows'] != null && data['headers'] != null) {
        final List headers = data['headers'];
        final List rows = data['rows'];
        _controllers = rows
            .map<List<TextEditingController>>((row) => List.generate(
                headers.length,
                (i) => TextEditingController(text: row[i]?.toString() ?? '')))
            .toList();
      } else {
        // Si no hay datos, inicializar vacío
        _controllers = [];
        for (int i = 0; i < 5; i++) {
          _addRow();
        }
      }
      _ultimoDocIdXD = lastDocId;
    } else {
      // Si no hay docId, inicializar vacío
      _controllers = [];
      for (int i = 0; i < 5; i++) {
        _addRow();
      }
    }
    setState(() {
      _cargandoXD = false;
    });
  }

  @override
  void initState() {
    super.initState();
    // La inicialización de filas se mueve a didChangeDependencies
  }

  void _addRow() {
    final now = DateTime.now();
    final fecha = DateFormat('yyyy-MM-dd').format(now);
    final hora = DateFormat('HH:mm:ss').format(now);
    final row = List.generate(_columns.length, (_) => TextEditingController());
    row[1].text = _usuario; // NOMBRE
    row[6].text = fecha; // FECHA
    row[9].text = hora; // HORA DE MANIFIESTO
    setState(() {
      _controllers.add(row);
    });
  }

  @override
  void dispose() {
    for (var row in _controllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Eliminado screenWidth porque no se usa
    return WillPopScope(
      onWillPop: () async {
        // Si hay filas con datos no exportados, mostrar advertencia
        bool hayNoExportadas = false;
        for (int i = 0; i < _controllers.length; i++) {
          final row = _controllers[i];
          final tieneDatos = row.any((c) => c.text.trim().isNotEmpty);
          if (tieneDatos && !_filasExportadas.contains(i)) {
            hayNoExportadas = true;
            break;
          }
        }
        if (!hayNoExportadas) return true;
        final salir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Seguro que quieres salir?'),
            content: const Text('Se perderán los datos no descargados.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Salir'),
              ),
            ],
          ),
        );
        return salir == true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D6A4F),
          elevation: 0,
          toolbarHeight: 0,
        ),
        body: Column(
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
                    'Hoja de XD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFF2D6A4F),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Agregar fila',
                    onPressed: _addRow,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double tableWidth = constraints.maxWidth;
                    final double adaptiveColWidth = tableWidth /
                        (_columns.length + 1); // +1 para columna de acción
                    return Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Card(
                          elevation: 2,
                          child: Table(
                            columnWidths: {
                              for (int i = 0; i < _columns.length + 1; i++)
                                i: FixedColumnWidth(adaptiveColWidth),
                            },
                            border: TableBorder(
                              verticalInside: BorderSide(
                                  color: Colors.grey.shade400, width: 1),
                              horizontalInside: BorderSide(
                                  color: Colors.grey.shade300, width: 1),
                            ),
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                    color: Color(0xFFE0E0E0)),
                                children: [
                                  ..._columns.map((col) => Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 4),
                                        child: Text(
                                          col,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        ),
                                      )),
                                  const SizedBox.shrink(), // Columna de acción
                                ],
                              ),
                              ...List.generate(_controllers.length, (rowIdx) {
                                final rowCtrls = _controllers[rowIdx];
                                return TableRow(
                                  children: [
                                    ...List.generate(_columns.length, (colIdx) {
                                      final isNombre = colIdx == 1;
                                      final isFecha = colIdx == 6;
                                      final isHora = colIdx == 9;
                                      return Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 2),
                                        child: TextField(
                                          controller: rowCtrls[colIdx],
                                          textAlign: TextAlign.center,
                                          readOnly:
                                              isNombre || isFecha || isHora,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 6, horizontal: 2),
                                            fillColor:
                                                (isNombre || isFecha || isHora)
                                                    ? Colors.grey.shade100
                                                    : null,
                                            filled:
                                                isNombre || isFecha || isHora,
                                          ),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      );
                                    }),
                                    // Botón de exportar Word
                                    Container(
                                      alignment: Alignment.center,
                                      child: IconButton(
                                        icon: const Icon(Icons.description,
                                            color: Colors.blue),
                                        tooltip: 'Exportar carátula Word',
                                        onPressed: () async {
                                          final data = <String, String>{};
                                          for (int i = 0;
                                              i < _columns.length;
                                              i++) {
                                            data[_columns[i]] =
                                                rowCtrls[i].text;
                                          }
                                          final fecha =
                                              DateFormat('yyyyMMdd_HHmmss')
                                                  .format(DateTime.now());
                                          final fileName =
                                              'caratula_${rowCtrls[1].text}_$fecha.docx';
                                          await WordExporter.exportCaratula(
                                              data, fileName);
                                          // Guardar la tabla completa en Firestore y caché
                                          await guardarTablaHojaXD();
                                          // Guardar el último docId usado para poder cargarlo después
                                          final prefs = await SharedPreferences
                                              .getInstance();
                                          final docId =
                                              '${_usuario}_${DateTime.now().millisecondsSinceEpoch}';
                                          await prefs.setString(
                                              'hoja_xd_last_docId', docId);
                                          setState(() {
                                            _filasExportadas.add(rowIdx);
                                            _ultimoDocIdXD = docId;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
