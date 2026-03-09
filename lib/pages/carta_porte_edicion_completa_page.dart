import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'carta_porte_printer.dart';
import 'carta_porte_pdf_printer.dart';
import 'carta_porte_edicion_completa_dialog.dart';
import '../utils/exportar_excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartaPorteEdicionCompletaPage extends StatefulWidget {
  final Map<String, dynamic> carta;
  final void Function(Map<String, dynamic>)? onGuardar;
  final VoidCallback? onImprimir;

  const CartaPorteEdicionCompletaPage({
    super.key,
    required this.carta,
    this.onGuardar,
    this.onImprimir,
  });

  @override
  State<CartaPorteEdicionCompletaPage> createState() =>
      _CartaPorteEdicionCompletaPageState();
}

class _CartaPorteEdicionCompletaPageState
    extends State<CartaPorteEdicionCompletaPage> {
  late List<List<TextEditingController>> _controllers;
  late List<String> _columns;
  late TextEditingController _unidadController;
  late TextEditingController _destinoController;
  late TextEditingController _rfcController;
  late String _fechaActual;
  List<Map<String, String>> _choferes = [];
  int? _choferSeleccionado;

  @override
  void initState() {
    super.initState();
    _columns = List<String>.from(widget.carta['COLUMNS'] ?? []);
    _controllers = (widget.carta['TABLE'] as List?)
            ?.map<List<TextEditingController>>((row) {
          return (row as List)
              .map<TextEditingController>(
                  (cell) => TextEditingController(text: cell?.toString() ?? ''))
              .toList();
        }).toList() ??
        [];
    _unidadController =
        TextEditingController(text: widget.carta['UNIDAD'] ?? '');
    _destinoController =
        TextEditingController(text: widget.carta['DESTINO'] ?? '');
    _rfcController = TextEditingController(text: widget.carta['RFC'] ?? '');
    _fechaActual = widget.carta['FECHA'] ?? '';
    _cargarChoferes().then((_) {
      final nombreChofer = widget.carta['CHOFER'] ?? '';
      if (nombreChofer.isNotEmpty) {
        final idx = _choferes.indexWhere((c) => c['nombre'] == nombreChofer);
        if (idx != -1) {
          setState(() {
            _choferSeleccionado = idx;
            _rfcController.text = _choferes[idx]['rfc'] ?? '';
          });
        }
      }
    });
  }

  Future<void> _cargarChoferes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('choferes_db');
    if (jsonStr != null) {
      final List<dynamic> decoded = json.decode(jsonStr);
      setState(() {
        _choferes = decoded
            .map<Map<String, String>>((e) => Map<String, String>.from(e))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    for (var row in _controllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    _unidadController.dispose();
    _destinoController.dispose();
    _rfcController.dispose();
    super.dispose();
  }

  void _guardar() {
    // Obtener el valor de CONCENTRADO si existe columna
    String concentrado = '';
    final concIdx =
        _columns.indexWhere((c) => c.toUpperCase() == 'CONCENTRADO');
    if (concIdx != -1 &&
        _controllers.isNotEmpty &&
        _controllers[0].length > concIdx) {
      // Buscar el primer valor no vacío de concentrado
      for (final row in _controllers) {
        if (row[concIdx].text.trim().isNotEmpty) {
          concentrado = row[concIdx].text.trim();
          break;
        }
      }
    }
    final nuevaCarta = {
      ...widget.carta,
      'CHOFER': _choferSeleccionado != null && _choferes.isNotEmpty
          ? _choferes[_choferSeleccionado!]['nombre'] ?? ''
          : '',
      'UNIDAD': _unidadController.text.trim(),
      'DESTINO': _destinoController.text.trim(),
      'RFC': _rfcController.text.trim(),
      'FECHA': _fechaActual,
      'COLUMNS': _columns,
      'TABLE':
          _controllers.map((row) => row.map((c) => c.text).toList()).toList(),
      'CONCENTRADO': concentrado,
    };
    // Actualizar en historial si existe NUMERO_CONTROL
    if (nuevaCarta['NUMERO_CONTROL'] != null &&
        nuevaCarta['NUMERO_CONTROL'].toString().isNotEmpty) {
      final idx = CartaPorteHistorialManager.historial.indexWhere(
          (c) => c['NUMERO_CONTROL'] == nuevaCarta['NUMERO_CONTROL']);
      if (idx != -1) {
        CartaPorteHistorialManager.updateCarta(idx, nuevaCarta);
      }
    }
    if (widget.onGuardar != null) widget.onGuardar!(nuevaCarta);
  }

  @override
  Widget build(BuildContext context) {
    final numeroControl = widget.carta['NUMERO_CONTROL']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Editar Carta Porte Completa'),
            if (numeroControl.isNotEmpty) ...[
              const SizedBox(width: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFB7E4C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF2D6A4F)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number,
                        size: 16, color: Color(0xFF2D6A4F)),
                    const SizedBox(width: 6),
                    Text(
                      numeroControl,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D6A4F)),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _guardar,
            tooltip: 'Guardar',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              final chofer = _choferSeleccionado != null && _choferes.isNotEmpty
                  ? _choferes[_choferSeleccionado!]['nombre'] ?? ''
                  : '';
              final unidad = _unidadController.text.trim();
              final destino = _destinoController.text.trim();
              final rfc = _rfcController.text.trim();
              final fecha = _fechaActual;
              final columns = _columns;
              final table = _controllers
                  .map((row) => row.map((c) => c.text).toList())
                  .toList();
              // Obtener el valor de CONCENTRADO si existe columna
              String concentrado = '';
              final concIdx =
                  columns.indexWhere((c) => c.toUpperCase() == 'CONCENTRADO');
              if (concIdx != -1 &&
                  _controllers.isNotEmpty &&
                  _controllers[0].length > concIdx) {
                for (final row in _controllers) {
                  if (row[concIdx].text.trim().isNotEmpty) {
                    concentrado = row[concIdx].text.trim();
                    break;
                  }
                }
              }
              final nuevaCarta = {
                ...widget.carta,
                'CHOFER': chofer,
                'UNIDAD': unidad,
                'DESTINO': destino,
                'RFC': rfc,
                'FECHA': fecha,
                'COLUMNS': columns,
                'TABLE': table,
                'CONCENTRADO': concentrado,
              };
              if (nuevaCarta['NUMERO_CONTROL'] != null &&
                  nuevaCarta['NUMERO_CONTROL'].toString().isNotEmpty) {
                final idx = CartaPorteHistorialManager.historial.indexWhere(
                    (c) => c['NUMERO_CONTROL'] == nuevaCarta['NUMERO_CONTROL']);
                if (idx != -1) {
                  await CartaPorteHistorialManager.updateCarta(idx, nuevaCarta);
                }
              }
              await CartaPortePdfPrinter.printCartaPortePdf(
                chofer: chofer,
                unidad: unidad,
                destino: destino,
                rfc: rfc,
                fecha: fecha,
                columns: columns,
                table: table,
                numeroControl: widget.carta['NUMERO_CONTROL']?.toString() ?? '',
              );
            },
            tooltip: 'Imprimir',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar a Excel',
            onPressed: () async {
              final columns = _columns;
              final table = _controllers
                  .map((row) => row.map((c) => c.text).toList())
                  .toList();
              final carta = {
                ...widget.carta,
                'CHOFER': _choferSeleccionado != null && _choferes.isNotEmpty
                    ? _choferes[_choferSeleccionado!]['nombre'] ?? ''
                    : '',
                'UNIDAD': _unidadController.text.trim(),
                'DESTINO': _destinoController.text.trim(),
                'RFC': _rfcController.text.trim(),
                'FECHA': _fechaActual,
                'COLUMNS': columns,
                'TABLE': table,
                'NUMERO_CONTROL': numeroControl,
              };
              await exportarExcel(
                  cartas: [carta], fileName: 'carta_porte.xlsx');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
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
                              _rfcController.text = _choferes[val]['rfc'] ?? '';
                            } else {
                              _rfcController.text = '';
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Chofer',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _unidadController,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _destinoController,
                        decoration: const InputDecoration(
                          labelText: 'Destino',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _rfcController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'RFC',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300, width: 1),
                      right: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: DataTable(
                    columns: _columns.asMap().entries.map((entry) {
                      final col = entry.value;
                      final idx = entry.key;
                      return DataColumn(
                        label: Container(
                          decoration: BoxDecoration(
                            border: idx < _columns.length - 1
                                ? Border(
                                    right: BorderSide(
                                        color: Colors.grey.shade300, width: 1))
                                : null,
                          ),
                          child: Text(
                            col,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        numeric: idx == 1, // N0. columna
                      );
                    }).toList(),
                    rows: _controllers
                        .asMap()
                        .entries
                        .map((entry) {
                          final rowIdx = entry.key;
                          final rowControllers = entry.value;
                          // Mostrar solo filas con al menos un dato no vacío (excepto la columna NO.)
                          final hasData = rowControllers.asMap().entries.any(
                              (e) =>
                                  e.key != 0 &&
                                  (e.value.text.trim().isNotEmpty));
                          if (!hasData) return null;
                          return DataRow(
                            cells: List<DataCell>.generate(_columns.length,
                                (colIdx) {
                              Widget cellWidget;
                              if (_columns[colIdx] == 'NO.' ||
                                  _columns[colIdx] == 'N0.' ||
                                  _columns[colIdx] == 'NO') {
                                cellWidget = Text(
                                  (rowIdx + 1).toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                );
                              } else if (_columns[colIdx].toUpperCase() ==
                                  'CONCENTRADO') {
                                cellWidget = TextField(
                                  controller: _controllers[rowIdx][colIdx],
                                  onChanged: (val) {},
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 4),
                                  ),
                                );
                              } else if (_columns[colIdx].toUpperCase() ==
                                      'EMBARQUE' &&
                                  colIdx == 9) {
                                cellWidget = TextField(
                                  controller: _controllers[rowIdx][colIdx],
                                  onChanged: (val) {
                                    final concIdx = _columns.indexWhere((c) =>
                                        c.toUpperCase() == 'CONCENTRADO');
                                    if (concIdx != -1) {
                                      setState(() {
                                        _controllers[rowIdx][concIdx].text =
                                            val;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 4),
                                  ),
                                );
                              } else {
                                cellWidget = TextField(
                                  controller: _controllers[rowIdx][colIdx],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 4),
                                  ),
                                );
                              }
                              return DataCell(
                                Container(
                                  decoration: BoxDecoration(
                                    border: colIdx < _columns.length - 1
                                        ? Border(
                                            right: BorderSide(
                                                color: Colors.grey.shade300,
                                                width: 1))
                                        : null,
                                  ),
                                  child: cellWidget,
                                ),
                              );
                            }),
                          );
                        })
                        .whereType<DataRow>()
                        .toList(),
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
