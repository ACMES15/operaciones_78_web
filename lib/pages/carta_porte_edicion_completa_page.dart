import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  int? _choferSeleccionado;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _choferesStream;
  List<Map<String, String>> _choferes = [];

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
    _choferSeleccionado = null;
    _choferesStream = FirebaseFirestore.instance
        .collection('choferes')
        .doc('main')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: (widget.carta['NUMERO_CONTROL'] != null &&
              widget.carta['NUMERO_CONTROL'].toString().isNotEmpty)
          ? FirebaseFirestore.instance
              .collection('cartas_porte')
              .doc(widget.carta['NUMERO_CONTROL'].toString())
              .snapshots()
          : null,
      builder: (context, cartaSnapshot) {
        if (cartaSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (cartaSnapshot.hasError) {
          return Center(child: Text('Error cargando carta porte'));
        }
        Map<String, dynamic> cartaData = widget.carta;
        if (cartaSnapshot.hasData && cartaSnapshot.data?.data() != null) {
          cartaData = cartaSnapshot.data!.data()!;
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _choferesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error cargando choferes'));
            }
            final data = snapshot.data?.data();
            List<Map<String, String>> choferes = [];
            if (data != null && data['items'] != null) {
              choferes = (data['items'] as List)
                  .map<Map<String, String>>((e) => Map<String, String>.from(e))
                  .toList();
              _choferes = choferes;
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString(
                    'choferes_db_main', jsonEncode({'items': data['items']}));
              });
            }
            if (_choferSeleccionado == null && choferes.isNotEmpty) {
              final nombreChofer = cartaData['CHOFER'] ?? '';
              if (nombreChofer.isNotEmpty) {
                final idx =
                    choferes.indexWhere((c) => c['nombre'] == nombreChofer);
                if (idx != -1) {
                  _choferSeleccionado = idx;
                  _rfcController.text = choferes[idx]['rfc'] ?? '';
                }
              }
            }
            _unidadController.text = cartaData['UNIDAD'] ?? '';
            _destinoController.text = cartaData['DESTINO'] ?? '';
            _rfcController.text = cartaData['RFC'] ?? '';
            _fechaActual = cartaData['FECHA'] ?? '';
            _columns = List<String>.from(cartaData['COLUMNS'] ?? []);
            final tableData = (cartaData['TABLE'] as List?) ?? [];
            if (tableData.length == _controllers.length) {
              for (int i = 0; i < tableData.length; i++) {
                final row = tableData[i] as List;
                for (int j = 0;
                    j < row.length && j < _controllers[i].length;
                    j++) {
                  _controllers[i][j].text = row[j]?.toString() ?? '';
                }
              }
            }
            return Padding(
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
                                for (int i = 0; i < choferes.length; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(choferes[i]['nombre'] ?? ''),
                                  ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _choferSeleccionado = val;
                                  if (val != null) {
                                    _rfcController.text =
                                        choferes[val]['rfc'] ?? '';
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
                            left: BorderSide(
                                color: Colors.grey.shade300, width: 1),
                            right: BorderSide(
                                color: Colors.grey.shade300, width: 1),
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
                                              color: Colors.grey.shade300,
                                              width: 1))
                                      : null,
                                ),
                                child: Text(
                                  col,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
                                final hasData = rowControllers
                                    .asMap()
                                    .entries
                                    .any((e) =>
                                        e.key != 0 &&
                                        (e.value.text.trim().isNotEmpty));
                                if (!hasData) return null;
                                return DataRow(
                                  cells: List<DataCell>.generate(
                                      _columns.length, (colIdx) {
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
                                        controller: _controllers[rowIdx]
                                            [colIdx],
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
                                        controller: _controllers[rowIdx]
                                            [colIdx],
                                        onChanged: (val) {
                                          final concIdx = _columns.indexWhere(
                                              (c) =>
                                                  c.toUpperCase() ==
                                                  'CONCENTRADO');
                                          if (concIdx != -1) {
                                            setState(() {
                                              _controllers[rowIdx][concIdx]
                                                  .text = val;
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
                                        controller: _controllers[rowIdx]
                                            [colIdx],
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
                                                      color:
                                                          Colors.grey.shade300,
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
            );
          },
        );
      },
    );
  }
}
