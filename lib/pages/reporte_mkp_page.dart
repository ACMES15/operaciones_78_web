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

  // Importar desde Excel
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
            for (int i = 1; i < rows.length; i++) {
              final row = rows[i];
              final ctrls = List.generate(_headers.length, (colIdx) {
                // Para la columna DIAS, inicializar vacío, se calculará en el build
                if (_headers[colIdx] == 'DIAS')
                  return TextEditingController(text: '');
                String val = colIdx < row.length && row[colIdx] != null
                    ? row[colIdx]!.value.toString()
                    : '';
                return TextEditingController(text: val);
              });
              _controllers.add(ctrls);
            }
            // Forzar actualización de JEFATURA y ESTATUS ACTUAL después de importar
            for (final ctrls in _controllers) {
              final seccionIdx = _headers.indexOf('SECCION');
              final jefaturaIdx = _headers.indexOf('JEFATURA');
              final remisionIdx = _headers.indexOf('REmision');
              final articuloIdx = _headers.indexOf('ARTICULO');
              final estatusIdx = _headers.indexOf('ESTATUS ACTUAL');
              // JEFATURA
              if (seccionIdx != -1 && jefaturaIdx != -1) {
                final seccion = ctrls[seccionIdx].text;
                final clave = _normalizeSeccion(seccion);
                final nuevaJefatura = _seccionToJefatura[clave] ?? '';
                print(
                    'DEBUG IMPORT: Buscando SECCION "$clave" => "$nuevaJefatura"');
                ctrls[jefaturaIdx].text = nuevaJefatura;
              }
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
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 1400),
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
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 4),
                                          child: Text(col,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15)),
                                        ))
                                    .toList(),
                              ),
                              ...List.generate(
                                _controllers.isEmpty ? 1 : _controllers.length,
                                (rowIdx) {
                                  final rowCtrls = _controllers.isEmpty
                                      ? List.generate(_headers.length,
                                          (i) => TextEditingController())
                                      : _controllers[rowIdx];
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
                                      // Si es SECCION, actualizar JEFATURA al editar (siempre)
                                      if (_headers[colIdx] == 'SECCION') {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2, horizontal: 2),
                                          child: TextField(
                                            controller: rowCtrls[colIdx],
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 4),
                                            ),
                                            style:
                                                const TextStyle(fontSize: 13),
                                            onChanged: (value) {
                                              final jefaturaIdx =
                                                  _headers.indexOf('JEFATURA');
                                              final clave =
                                                  _normalizeSeccion(value);
                                              final nuevaJefatura =
                                                  _seccionToJefatura[clave] ??
                                                      '';
                                              print(
                                                  'DEBUG EDIT: Buscando SECCION "$clave" => "$nuevaJefatura"');
                                              rowCtrls[jefaturaIdx].text =
                                                  nuevaJefatura;
                                              setState(() {});
                                            },
                                          ),
                                        );
                                      }
                                      // Si es JEFATURA, mostrar siempre el valor actualizado y no editable
                                      if (_headers[colIdx] == 'JEFATURA') {
                                        final seccionIdx =
                                            _headers.indexOf('SECCION');
                                        final seccion =
                                            rowCtrls[seccionIdx].text;
                                        final clave =
                                            _normalizeSeccion(seccion);
                                        final jefatura =
                                            _seccionToJefatura[clave] ?? '';
                                        print(
                                            'DEBUG RENDER: Buscando SECCION "$clave" => "$jefatura"');
                                        if (rowCtrls[colIdx].text != jefatura) {
                                          rowCtrls[colIdx].text = jefatura;
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2, horizontal: 2),
                                          child: Text(
                                            jefatura,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.black,
                                            ),
                                          ),
                                        );
                                      }
                                      // Si es DIAS, calcular días transcurridos desde FECHA y colorear
                                      if (_headers[colIdx] == 'DIAS') {
                                        final fechaIdx =
                                            _headers.indexOf('FECHA');
                                        String fechaStr =
                                            rowCtrls[fechaIdx].text;
                                        int dias = 0;
                                        Color color = Colors.grey.shade200;
                                        if (fechaStr.isNotEmpty) {
                                          try {
                                            // Intentar parsear dd/MM/yyyy HH:mm:ss
                                            final partes = fechaStr.split(' ');
                                            final fechaSolo = partes[0];
                                            final formato = RegExp(
                                                r'^(\d{2})/(\d{2})/(\d{4})$');
                                            if (formato.hasMatch(fechaSolo)) {
                                              final f = fechaSolo.split('/');
                                              final dia = int.parse(f[0]);
                                              final mes = int.parse(f[1]);
                                              final anio = int.parse(f[2]);
                                              final fecha =
                                                  DateTime(anio, mes, dia);
                                              final ahora = DateTime.now();
                                              dias = ahora
                                                  .difference(fecha)
                                                  .inDays;
                                              if (dias < 0) dias = 0;
                                              if (dias == 1) {
                                                color = Colors.green.shade200;
                                              } else if (dias >= 2 &&
                                                  dias <= 3) {
                                                color = Colors.orange.shade200;
                                              } else if (dias >= 4) {
                                                color = Colors.red.shade200;
                                              } else {
                                                color = Colors.grey.shade200;
                                              }
                                            }
                                          } catch (e) {
                                            // Si hay error, dejar en gris
                                          }
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2, horizontal: 2),
                                          child: Container(
                                            color: color,
                                            alignment: Alignment.center,
                                            child: Text(
                                              dias > 0 ? dias.toString() : '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      // Si es REmision o ARTICULO, actualizar ESTATUS ACTUAL al editar (normalizando)
                                      if (_headers[colIdx] == 'REmision' ||
                                          _headers[colIdx] == 'ARTICULO') {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2, horizontal: 2),
                                          child: TextField(
                                            controller: rowCtrls[colIdx],
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 4),
                                            ),
                                            style:
                                                const TextStyle(fontSize: 13),
                                            onChanged: (_) {
                                              final remisionIdx =
                                                  _headers.indexOf('REmision');
                                              final articuloIdx =
                                                  _headers.indexOf('ARTICULO');
                                              final estatusIdx = _headers
                                                  .indexOf('ESTATUS ACTUAL');
                                              final remision =
                                                  rowCtrls[remisionIdx].text;
                                              final articulo =
                                                  rowCtrls[articuloIdx].text;
                                              final key =
                                                  '${_normalizeKey(remision)}|${_normalizeKey(articulo)}';
                                              setState(() {
                                                if (_entregados.contains(key)) {
                                                  rowCtrls[estatusIdx].text =
                                                      'ENTREGADO';
                                                } else if (rowCtrls[estatusIdx]
                                                        .text ==
                                                    'ENTREGADO') {
                                                  rowCtrls[estatusIdx].text =
                                                      '';
                                                }
                                              });
                                            },
                                          ),
                                        );
                                      }
                                      // Si es ESTATUS ACTUAL y es ENTREGADO, pintar verde
                                      if (_headers[colIdx] ==
                                              'ESTATUS ACTUAL' &&
                                          rowCtrls[colIdx].text ==
                                              'ENTREGADO') {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2, horizontal: 2),
                                          child: Container(
                                            color: Colors.green.shade200,
                                            alignment: Alignment.center,
                                            child: Text(
                                              rowCtrls[colIdx].text,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 2),
                                        child: isEditable
                                            ? TextField(
                                                controller: rowCtrls[colIdx],
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
                                                    fontSize: 13),
                                              )
                                            : Text(rowCtrls[colIdx].text,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13)),
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
                ],
              ),
            ),
    );
  }
}
