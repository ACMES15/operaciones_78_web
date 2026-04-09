import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recolectar_page.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'dart:html' as html;

class ReporteMkpPage extends StatefulWidget {
  const ReporteMkpPage({Key? key}) : super(key: key);

  @override
  State<ReporteMkpPage> createState() => _ReporteMkpPageState();
}

class _ReporteMkpPageState extends State<ReporteMkpPage> {
  // Guardar registros NO ENTREGADO en Firestore y cache local
  Future<void> _guardarNoEntregado() async {
    // Validar que haya datos
    if (_controllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para guardar.')),
      );
      return;
    }
    final noEntregados = <Map<String, dynamic>>[];
    for (final ctrls in _controllers) {
      final estatusIdx = _headers.indexOf('ESTATUS ACTUAL');
      if (estatusIdx != -1 &&
          ctrls[estatusIdx].text.trim().toUpperCase() != 'ENTREGADO') {
        final row = <String, dynamic>{};
        for (int i = 0; i < _headers.length; i++) {
          if (_headers[i] != 'DIAS') {
            row[_headers[i]] = ctrls[i].text;
          }
        }
        noEntregados.add(row);
      }
    }
    if (noEntregados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para guardar.')),
      );
      return;
    }
    // Guardar en Firestore
    await FirebaseFirestore.instance
        .collection('reporte_mkp_no_entregado')
        .doc('pendientes')
        .set({'items': noEntregados});
    // Guardar en cache local (localStorage) como JSON
    try {
      html.window.localStorage['reporte_mkp_no_entregado'] =
          jsonEncode(noEntregados);
    } catch (e) {}
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registros NO ENTREGADO guardados.')),
    );
  }

  // Set de pares (REmision, ARTICULO) que están entregados
  Set<String> _entregados = {};

  // Normaliza valores quitando ceros a la izquierda y espacios
  String _normalizeKey(String value) {
    return value.trim().replaceFirst(RegExp(r'^0+'), '');
  }

  // Cargar entregas MKP para validación
  Future<void> _cargarEntregasMKP() async {
    final doc = await FirebaseFirestore.instance
        .collection('entregas')
        .doc('mkp')
        .get();
    final items = (doc.data()?['items'] ?? []) as List;
    final entregados = <String>{};
    for (final item in items) {
      final dev = _normalizeKey((item['devolucion_mkp'] ?? '').toString());
      final skus = (item['skus'] ?? []) as List?;
      if (skus != null) {
        for (final sku in skus) {
          final normSku = _normalizeKey(sku.toString());
          entregados.add('$dev|$normSku');
        }
      }
    }
    setState(() {
      _entregados = entregados;
    });
  }

  // Mapa SECCION -> NOMBRE (JEFATURA) desde Plantilla Ejecutiva
  Map<String, String> _seccionToJefatura = {};
  String _normalizeSeccion(String s) => s.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _cargarJefaturas();
    _cargarEntregasMKP();
  }

  Future<void> _cargarJefaturas() async {
    // Leer correctamente la colección y documento reales
    final doc = await FirebaseFirestore.instance
        .collection('plantilla_ejecutiva')
        .doc('datos')
        .get();
    print('DEBUG FIRESTORE: doc.data = ' + doc.data().toString());
    final map = <String, String>{};
    final datos = (doc.data()?['datos'] ?? []) as List?;
    print('DEBUG FIRESTORE: datos = ' + datos.toString());
    if (datos != null) {
      for (final item in datos) {
        print('DEBUG FIRESTORE: item = ' + item.toString());
        final seccionRaw = item['SECCION'];
        final nombreRaw = item['NOMBRE'];
        if (seccionRaw == null || nombreRaw == null) {
          print('ADVERTENCIA: item sin SECCION o NOMBRE: ' + item.toString());
          continue;
        }
        final seccion = seccionRaw.toString().trim().toUpperCase();
        final nombre = nombreRaw.toString().trim();
        if (seccion.isEmpty || nombre.isEmpty) {
          print('ADVERTENCIA: SECCION o NOMBRE vacío en: ' + item.toString());
          continue;
        }
        map[seccion] = nombre;
      }
    }
    setState(() {
      _seccionToJefatura = map;
      print('DEBUG: Jefaturas cargadas:');
      _seccionToJefatura.forEach((k, v) => print('  [$k] => $v'));
    });
  }

  // Encabezados ejecutivos
  final List<String> _headers = [
    'NOMBRE CENTRO',
    'REmision',
    'ARTICULO',
    'NUMERO VENDEDOR',
    'NOMBRE DEL VENDEDOR',
    'ESTATUS ACTUAL',
    'FECHA',
    'SECCION',
    'JEFATURA',
    'DIAS',
  ];

  // Controladores para edición
  final List<List<TextEditingController>> _controllers = [];

  // Importar desde Excel (ignora encabezado, deja primera fila vacía, mapea por posición)
  Future<void> _importarExcel() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(files[0]);
        reader.onLoadEnd.listen((event) async {
          final bytes = reader.result as Uint8List;
          final excelFile = excel.Excel.decodeBytes(bytes);
          final sheet = excelFile.tables.values.first;
          final rows = sheet.rows;
          if (rows.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El archivo está vacío.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          setState(() {
            _controllers.clear();
            // Tomar datos desde la primera fila (índice 0) en adelante, sin dejar fila vacía
            for (int i = 1; i < rows.length; i++) {
              final row = rows[i];
              final ctrls = List.generate(_headers.length, (colIdx) {
                // DIAS siempre vacío, se calcula en build
                if (_headers[colIdx] == 'DIAS')
                  return TextEditingController(text: '');
                String val = '';
                if (colIdx < row.length && row[colIdx] != null) {
                  final cell = row[colIdx]!;
                  // Si es la columna FECHA, intentar convertir serial Excel, DateTime o string
                  if (_headers[colIdx] == 'FECHA') {
                    DateTime? fecha;
                    // 1. Si es DateTime
                    if (cell.value is DateTime) {
                      fecha = cell.value as DateTime;
                    } else if (cell.value is num) {
                      // 2. Si es serial Excel (número)
                      // Excel: días desde 1899-12-30
                      final excelEpoch = DateTime(1899, 12, 30);
                      fecha = excelEpoch
                          .add(Duration(days: (cell.value as num).floor()));
                    } else if (cell.value is String) {
                      // 3. Si es string, intentar parsear varios formatos
                      final raw = cell.value.toString().trim();
                      // yyyy-MM-dd, yyyy/MM/dd, dd/MM/yyyy, MM/dd/yyyy, etc.
                      final formats = [
                        RegExp(
                            r'^(\d{4})[\/-](\d{2})[\/-](\d{2})$'), // yyyy-MM-dd o yyyy/MM/dd
                        RegExp(
                            r'^(\d{2})[\/-](\d{2})[\/-](\d{4})$'), // dd/MM/yyyy o MM/dd/yyyy
                        RegExp(
                            r'^(\d{4})[\/-](\d{2})[\/-](\d{2})$'), // yyyy/MM/dd
                        RegExp(
                            r'^(\d{2})[\/-](\d{2})[\/-](\d{2})$'), // dd/MM/yy
                      ];
                      bool parsed = false;
                      for (final f in formats) {
                        final m = f.firstMatch(raw);
                        if (m != null) {
                          try {
                            if (f.pattern.startsWith(r'^(\d{4})')) {
                              // yyyy-MM-dd o yyyy/MM/dd
                              final y = int.parse(m.group(1)!);
                              final mth = int.parse(m.group(2)!);
                              final d = int.parse(m.group(3)!);
                              fecha = DateTime(y, mth, d);
                            } else if (f.pattern.startsWith(r'^(\d{2})')) {
                              // dd/MM/yyyy o MM/dd/yyyy
                              final d1 = int.parse(m.group(1)!);
                              final d2 = int.parse(m.group(2)!);
                              final y = int.parse(m.group(3)!);
                              // Si el año > 31, asumimos dd/MM/yyyy, si no, MM/dd/yyyy
                              if (y > 31) {
                                fecha = DateTime(y, d2, d1);
                              } else {
                                fecha = DateTime(y + 2000, d2, d1);
                              }
                            }
                            parsed = true;
                            break;
                          } catch (_) {}
                        }
                      }
                      if (!parsed) {
                        // Intentar parseo directo
                        try {
                          fecha = DateTime.tryParse(raw);
                        } catch (_) {}
                      }
                    }
                    if (fecha != null) {
                      val =
                          '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
                    } else {
                      val = cell.value.toString();
                    }
                  } else {
                    val = cell.value.toString();
                  }
                }
                return TextEditingController(text: val);
              });
              // Listener para recalcular JEFATURA al editar SECCION
              final seccionIdx = _headers.indexOf('SECCION');
              final jefaturaIdx = _headers.indexOf('JEFATURA');
              if (seccionIdx != -1 && jefaturaIdx != -1) {
                ctrls[seccionIdx].addListener(() {
                  final clave = _normalizeSeccion(ctrls[seccionIdx].text);
                  final nuevaJefatura = _seccionToJefatura[clave] ?? '';
                  ctrls[jefaturaIdx].text = nuevaJefatura;
                  setState(() {});
                });
              }
              _controllers.add(ctrls);
            }
            // JEFATURA y ESTATUS ACTUAL se calculan igual que antes
            for (final ctrls in _controllers) {
              final remisionIdx = _headers.indexOf('REmision');
              final articuloIdx = _headers.indexOf('ARTICULO');
              final estatusIdx = _headers.indexOf('ESTATUS ACTUAL');
              // ESTATUS ACTUAL
              if (remisionIdx != -1 && articuloIdx != -1 && estatusIdx != -1) {
                final remision = ctrls[remisionIdx].text;
                final articulo = ctrls[articuloIdx].text;
                final key =
                    '${_normalizeKey(remision)}|${_normalizeKey(articulo)}';
                if (_entregados.contains(key)) {
                  ctrls[estatusIdx].text = 'ENTREGADO';
                } else if (ctrls[estatusIdx].text == 'ENTREGADO') {
                  ctrls[estatusIdx].text = '';
                }
              }
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Importación exitosa: ${rows.length - 1} filas.'),
              backgroundColor: Colors.green,
            ),
          );
        });
      }
    });
  }

  void _agregarFila() {
    setState(() {
      final ctrls =
          List.generate(_headers.length, (i) => TextEditingController());
      _controllers.add(ctrls);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobileNarrow = mediaQuery.size.shortestSide <= 600;
    int fechaIdx = _headers.indexOf('FECHA');
    int diasIdx = _headers.indexOf('DIAS');
    int estatusIdx = _headers.indexOf('ESTATUS ACTUAL');
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.assignment, color: Color(0xFF2D6A4F), size: 30),
            SizedBox(width: 10),
            Text('Reporte MKP', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: isMobileNarrow
          ? Center(
              child: SizedBox(
                width: 260,
                height: 80,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.assignment_turned_in, size: 38),
                  label: const Text('Recolectar',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecolectarPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Importar Excel'),
                        onPressed: _importarExcel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar fila'),
                        onPressed: _agregarFila,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                        onPressed: _guardarNoEntregado,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.assignment_turned_in),
                        label: const Text('Recolectar'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RecolectarPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade700,
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1400,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Container(
                              // constraints: const BoxConstraints(maxWidth: 1400),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Table(
                                border: TableBorder(
                                  horizontalInside: BorderSide(
                                      color: Colors.grey.shade300, width: 1),
                                  verticalInside: BorderSide(
                                      color: Colors.grey.shade400, width: 1),
                                ),
                                columnWidths: {
                                  for (int i = 0; i < _headers.length; i++)
                                    i: const FlexColumnWidth(),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF2D6A4F)),
                                    children: _headers
                                        .map((col) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 4),
                                              child: Text(col,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15)),
                                            ))
                                        .toList(),
                                  ),
                                  ...List.generate(
                                    _controllers.isEmpty
                                        ? 1
                                        : _controllers.length,
                                    (rowIdx) {
                                      final rowCtrls = _controllers.isEmpty
                                          ? List.generate(_headers.length,
                                              (i) => TextEditingController())
                                          : _controllers[rowIdx];
                                      // Calcular DIAS dinámicamente
                                      int dias = 0;
                                      if (diasIdx != -1 && fechaIdx != -1) {
                                        final fechaStr =
                                            rowCtrls[fechaIdx].text.trim();
                                        if (fechaStr.isNotEmpty) {
                                          DateTime? fecha;
                                          try {
                                            // Detectar formato ISO 8601: yyyy-MM-ddTHH:mm:ss.sss
                                            final isoMatch = RegExp(
                                                    r'^(\d{4})-(\d{2})-(\d{2})[T ]')
                                                .firstMatch(fechaStr);
                                            if (isoMatch != null) {
                                              // Extraer solo la parte de la fecha
                                              final y = int.tryParse(
                                                  isoMatch.group(1)!);
                                              final m = int.tryParse(
                                                  isoMatch.group(2)!);
                                              final d = int.tryParse(
                                                  isoMatch.group(3)!);
                                              if (y != null &&
                                                  m != null &&
                                                  d != null) {
                                                fecha = DateTime(y, m, d);
                                              }
                                            } else {
                                              // Buscar patrón flexible: dd[sep]MM[sep]yyyy, d[sep]M[sep]yy, etc.
                                              final regex = RegExp(
                                                  r'(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})');
                                              final match =
                                                  regex.firstMatch(fechaStr);
                                              if (match != null) {
                                                final d = int.tryParse(
                                                    match.group(1)!);
                                                final m = int.tryParse(
                                                    match.group(2)!);
                                                var y = int.tryParse(
                                                    match.group(3)!);
                                                if (d != null &&
                                                    m != null &&
                                                    y != null) {
                                                  // Si el año es de 2 dígitos, asumir 2000+
                                                  if (y < 100) y += 2000;
                                                  fecha = DateTime(y, m, d);
                                                }
                                              } else {
                                                // Intentar parseo directo
                                                fecha =
                                                    DateTime.tryParse(fechaStr);
                                              }
                                            }
                                            if (fecha != null) {
                                              dias = DateTime.now()
                                                  .difference(fecha)
                                                  .inDays;
                                            }
                                          } catch (_) {}
                                        }
                                      }
                                      return TableRow(
                                        decoration: BoxDecoration(
                                          color: rowIdx % 2 == 0
                                              ? Colors.white
                                              : Colors.grey.shade50,
                                        ),
                                        children: List.generate(_headers.length,
                                            (colIdx) {
                                          final isEditable =
                                              colIdx < _headers.length - 1;
                                          // Si es SECCION, recalcula JEFATURA al editar
                                          final seccionIdx =
                                              _headers.indexOf('SECCION');
                                          final jefaturaIdx =
                                              _headers.indexOf('JEFATURA');
                                          // Pintar ESTATUS ACTUAL en verde si es ENTREGADO (celda completa)
                                          bool isEstatusEntregado =
                                              _headers[colIdx] ==
                                                      'ESTATUS ACTUAL' &&
                                                  rowCtrls[colIdx]
                                                          .text
                                                          .trim()
                                                          .toUpperCase() ==
                                                      'ENTREGADO';
                                          // Mostrar DIAS calculado y colorear celda
                                          if (_headers[colIdx] == 'DIAS') {
                                            Color? colorDias;
                                            if (dias == 0) {
                                              colorDias = Colors.green.shade700;
                                            } else if (dias == 1 || dias == 2) {
                                              colorDias = Colors.amber.shade700;
                                            } else if (dias == 3 || dias == 4) {
                                              colorDias =
                                                  Colors.orange.shade700;
                                            } else if (dias > 4) {
                                              colorDias = Colors.red.shade700;
                                            }
                                            return Container(
                                              color:
                                                  colorDias?.withOpacity(0.18),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                      horizontal: 2),
                                              child: Text(
                                                dias > 0 || dias == 0
                                                    ? dias.toString()
                                                    : '',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: colorDias,
                                                ),
                                              ),
                                            );
                                          }
                                          // Celda ESTATUS ACTUAL coloreada si es ENTREGADO
                                          if (_headers[colIdx] ==
                                              'ESTATUS ACTUAL') {
                                            return Container(
                                              color: isEstatusEntregado
                                                  ? Colors.green.shade100
                                                  : null,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                      horizontal: 2),
                                              child: isEditable
                                                  ? TextField(
                                                      controller:
                                                          rowCtrls[colIdx],
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        4),
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            isEstatusEntregado
                                                                ? Colors.green
                                                                    .shade800
                                                                : null,
                                                        fontWeight:
                                                            isEstatusEntregado
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .normal,
                                                      ),
                                                    )
                                                  : Text(
                                                      rowCtrls[colIdx].text,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color:
                                                            isEstatusEntregado
                                                                ? Colors.green
                                                                    .shade800
                                                                : null,
                                                      ),
                                                    ),
                                            );
                                          }
                                          // Otras celdas
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2, horizontal: 2),
                                            child: isEditable
                                                ? TextField(
                                                    controller:
                                                        rowCtrls[colIdx],
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
                                                      fontSize: 13,
                                                    ),
                                                    onChanged: (colIdx ==
                                                                seccionIdx &&
                                                            jefaturaIdx != -1)
                                                        ? (val) {
                                                            final clave =
                                                                _normalizeSeccion(
                                                                    val);
                                                            final nuevaJefatura =
                                                                _seccionToJefatura[
                                                                        clave] ??
                                                                    '';
                                                            rowCtrls[jefaturaIdx]
                                                                    .text =
                                                                nuevaJefatura;
                                                            setState(() {});
                                                          }
                                                        : null,
                                                  )
                                                : Text(
                                                    rowCtrls[colIdx].text,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                          );
                                        }),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
