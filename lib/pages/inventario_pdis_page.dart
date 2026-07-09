import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';

class InventarioPdisPage extends StatefulWidget {
  final String usuario;
  const InventarioPdisPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<InventarioPdisPage> createState() => _InventarioPdisPageState();
}

class _InventarioPdisPageState extends State<InventarioPdisPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _plantilla = {};

  List<String> _jefes = [];
  String? _selectedJefe;

  // Aggregated by SKU for selected jefe
  final Map<String, double> _pdisBySku = {};
  final Map<String, int> _scannedBySku = {};

  int _totalPdis = 0;
  int _totalScanned = 0;

  // scanner controller
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocus = FocusNode();

  // form answers
  bool q1 = true; // Mercancia identificada con sku y PDIS? (YES good)
  bool q2 = false; // Se tuvo faltante en el primer escaneo? (NO good)
  bool q3 = false; // Hay mercancia dañada? (NO good)
  bool q4 = false; // Hay mercancia en bodega? (NO good)

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ohpdis')
          .doc('datos')
          .get();
      final plantillaDoc = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();
      final List<dynamic> items = (doc.data()?['datos']) ?? [];
      _rows = items
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (plantillaDoc.exists &&
          plantillaDoc.data() != null &&
          plantillaDoc.data()!['datos'] is List) {
        for (final e in List<dynamic>.from(plantillaDoc.data()!['datos'])) {
          if (e is Map && e['SECCION'] != null && e['NOMBRE'] != null) {
            _plantilla[e['SECCION'].toString()] = e['NOMBRE'].toString();
          }
        }
      }

      // build jefes list
      final counts = <String, int>{};
      for (final r in _rows) {
        final jefe = _getJefeFromRow(r);
        if (jefe.isEmpty) continue;
        counts[jefe] = (counts[jefe] ?? 0) + 1;
      }
      _jefes = counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    } catch (e) {
      print('Error cargando datos inventario: $e');
    }
    setState(() {
      _loading = false;
    });
  }

  String _getJefeFromRow(Map<String, dynamic> r) {
    for (final k in [
      'Jefatura',
      'jefatura',
      'JEFA',
      'Jefe',
      'SECCION',
      'seccion',
      'Seccion'
    ]) {
      if (r.containsKey(k) && r[k] != null && r[k].toString().trim().isNotEmpty)
        return r[k].toString().trim();
    }
    final sec = r['SECCION'] ?? r['seccion'];
    if (sec != null) return _plantilla[sec.toString()] ?? '';
    return '';
  }

  void _onSelectJefe(String? jefe) {
    setState(() {
      _selectedJefe = jefe;
      _buildSkuAggregates();
      Future.delayed(const Duration(milliseconds: 100), () {
        _scanFocus.requestFocus();
      });
    });
  }

  void _buildSkuAggregates() {
    _pdisBySku.clear();
    _scannedBySku.clear();
    _totalPdis = 0;
    _totalScanned = 0;
    if (_selectedJefe == null) return;
    for (final r in _rows) {
      final jefe = _getJefeFromRow(r);
      if (jefe != _selectedJefe) continue;
      final sku = (r['SKU'] ?? r['Sku'] ?? r['sku'] ?? '').toString().trim();
      if (sku.isEmpty) continue;
      final pdisVal = _parsePdisValue(r).round();
      _pdisBySku[sku] = (_pdisBySku[sku] ?? 0) + pdisVal;
    }
    _pdisBySku.forEach((k, v) {
      _scannedBySku[k] = 0;
      _totalPdis += v.round();
    });
    setState(() {});
  }

  double _parsePdisValue(Map<String, dynamic> r) {
    try {
      final candidates = [
        r['__pdis_num'],
        r['PDIS'],
        r['Total \$ PDIS'],
        r['Total PDIS']
      ];
      for (final c in candidates) {
        if (c == null) continue;
        if (c is num) return c.toDouble();
        final s = c.toString().trim();
        if (s.isEmpty) continue;
        final cleaned =
            s.replaceAll(RegExp(r"[^0-9\-\.,]"), '').replaceAll(',', '.');
        final v = double.tryParse(cleaned);
        if (v != null) return v;
      }
    } catch (_) {}
    return 0.0;
  }

  void _onScanSubmitted(String value) {
    final sku = value.trim();
    if (sku.isEmpty || _selectedJefe == null) return;
    if (_pdisBySku.containsKey(sku)) {
      _scannedBySku[sku] = (_scannedBySku[sku] ?? 0) + 1;
      _recalcTotals();
      _scanController.clear();
      _scanFocus.requestFocus();
      return;
    }
    final found = _pdisBySku.keys.firstWhere(
        (k) => k.toLowerCase() == sku.toLowerCase(),
        orElse: () => '');
    if (found.isNotEmpty) {
      _scannedBySku[found] = (_scannedBySku[found] ?? 0) + 1;
      _recalcTotals();
      _scanController.clear();
      _scanFocus.requestFocus();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('SKU "$sku" no encontrado en inventario del jefe')));
    _scanController.clear();
    _scanFocus.requestFocus();
  }

  void _recalcTotals() {
    _totalScanned = _scannedBySku.values.fold(0, (s, v) => s + v);
    _totalPdis = _pdisBySku.values.fold(0.0, (s, v) => s + v).round();
    setState(() {});
  }

  double _percentScanned() {
    if (_totalPdis <= 0) return 0.0;
    return (_totalScanned / _totalPdis).clamp(0.0, 1.0);
  }

  double _computeQualityScore() {
    final base = (_percentScanned() * 100);
    double score = base;
    score += q1 ? 20 : -20;
    score += q2 ? -50 : 50;
    score += q3 ? -20 : 20;
    score += q4 ? -10 : 10;
    if (score > 100) score = 100;
    if (score < 0) score = 0;
    return score;
  }

  Future<void> _finishInventory() async {
    final pct = _percentScanned();
    final quality = _computeQualityScore();
    final result = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Resultado Inventario'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            'Scanned: ${(_totalScanned)} / ${_totalPdis}')),
                    Text('${(pct * 100).toStringAsFixed(1)}%')
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: Text('Calidad: ${quality.toStringAsFixed(1)}%')),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'))
            ],
          );
        });
    if (result != true) return;
    final doc =
        FirebaseFirestore.instance.collection('inventarios_historico').doc();
    final payload = {
      'usuario': widget.usuario,
      'jefe': _selectedJefe,
      'createdAt': FieldValue.serverTimestamp(),
      'totalPdis': _totalPdis,
      'totalScanned': _totalScanned,
      'percentScanned': pct,
      'qualityScore': _computeQualityScore(),
      'q1': q1,
      'q2': q2,
      'q3': q3,
      'q4': q4,
      'skus': _pdisBySku.map(
          (k, v) => MapEntry(k, {'pdis': v, 'scanned': _scannedBySku[k] ?? 0})),
    };
    await doc.set(payload);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventario guardado en histórico')));
  }

  Future<void> _exportToExcel() async {
    if (_selectedJefe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione una jefatura primero')));
      return;
    }
    final workbook = ex.Excel.createExcel();
    final sheet = workbook['Inventario'];

    // metadata header
    sheet.appendRow(['Jefatura', _selectedJefe]);
    sheet.appendRow(['Total PDIS', _totalPdis]);
    sheet.appendRow(['Total Escaneado', _totalScanned]);
    sheet.appendRow([]);
    sheet.appendRow(['SKU', 'PDIS', 'Escaneado']);

    for (final sku in _pdisBySku.keys) {
      final pdis = _pdisBySku[sku] ?? 0.0;
      final scanned = _scannedBySku[sku] ?? 0;
      sheet.appendRow([sku, pdis.toStringAsFixed(0), scanned]);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error generando Excel')));
      return;
    }
    final data = Uint8List.fromList(bytes);
    final blob = html.Blob([data],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download =
          'inventario_${_selectedJefe ?? 'jefe'}_${DateTime.now().toIso8601String()}.xlsx';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  void _showFaltantesDialog() {
    final faltantes = <Map<String, dynamic>>[];
    _pdisBySku.forEach((sku, pdis) {
      final scanned = _scannedBySku[sku] ?? 0;
      final falta = pdis.round() - scanned;
      if (falta > 0) {
        faltantes.add({
          'sku': sku,
          'pdis': pdis.round(),
          'scanned': scanned,
          'falta': falta
        });
      }
    });
    faltantes.sort((a, b) => (b['falta'] as int).compareTo(a['falta'] as int));

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Faltantes',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black)),
            content: SizedBox(
              width: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (faltantes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No hay SKUs con faltante',
                          style: TextStyle(color: Colors.black)),
                    )
                  else
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: faltantes.length,
                        itemBuilder: (context, i) {
                          final row = faltantes[i];
                          return ListTile(
                            dense: true,
                            title: Text(row['sku'] ?? '',
                                style: const TextStyle(color: Colors.black)),
                            trailing: SizedBox(
                                width: 180,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${row['pdis']}',
                                        style: const TextStyle(
                                            color: Colors.black)),
                                    const SizedBox(width: 12),
                                    Text('${row['scanned']}',
                                        style: const TextStyle(
                                            color: Colors.black)),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('${row['falta']}',
                                          style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                )),
                          );
                        },
                      ),
                    )
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'))
            ],
          );
        });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Inventario PDIS',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedJefe,
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Seleccione Jefe',
                                    style: TextStyle(color: Colors.black))),
                            ..._jefes.map((j) => DropdownMenuItem<String?>(
                                value: j,
                                child: Text(j,
                                    style:
                                        const TextStyle(color: Colors.black))))
                          ],
                          onChanged: _onSelectJefe,
                          decoration: const InputDecoration(
                              labelText: 'Jefatura para auditoría'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                          onPressed: _buildSkuAggregates,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white),
                          child: const Text('Cargar'))
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedJefe != null) ...[
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                          controller: _scanController,
                          focusNode: _scanFocus,
                          decoration: const InputDecoration(
                              labelText: 'Escanear SKU',
                              border: OutlineInputBorder()),
                          onSubmitted: _onScanSubmitted,
                        )),
                        const SizedBox(width: 12),
                        Column(children: [
                          Text('Total PDIS: $_totalPdis',
                              style: const TextStyle(color: Colors.black)),
                          Text('Escaneado: $_totalScanned',
                              style: const TextStyle(color: Colors.black)),
                          Text('Faltante: ${_totalPdis - _totalScanned}',
                              style: const TextStyle(color: Colors.black)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _showFaltantesDialog,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8)),
                            child: const Text('Faltantes'),
                          )
                        ])
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                        flex: 3,
                        child: Card(
                          color: Colors.white,
                          elevation: 2,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text('SKU',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    SizedBox(
                                        width: 120,
                                        child: Text('PDIS',
                                            textAlign: TextAlign.right)),
                                    SizedBox(
                                        width: 120,
                                        child: Text('Escaneado',
                                            textAlign: TextAlign.right))
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(child: Builder(builder: (context) {
                                final sortedKeys = _pdisBySku.keys.toList()
                                  ..sort((a, b) {
                                    final remA = (_pdisBySku[a]?.round() ?? 0) -
                                        (_scannedBySku[a] ?? 0);
                                    final remB = (_pdisBySku[b]?.round() ?? 0) -
                                        (_scannedBySku[b] ?? 0);
                                    if (remA != remB)
                                      return remB.compareTo(remA);
                                    return a.compareTo(b);
                                  });

                                return ListView.builder(
                                  itemCount: sortedKeys.length,
                                  itemBuilder: (context, index) {
                                    final sku = sortedKeys[index];
                                    final pdis = _pdisBySku[sku] ?? 0.0;
                                    final scanned = _scannedBySku[sku] ?? 0;
                                    return ListTile(
                                      title: Text(sku,
                                          style: const TextStyle(
                                              color: Colors.black)),
                                      trailing: SizedBox(
                                          width: 240,
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                SizedBox(
                                                    width: 110,
                                                    child: Text(
                                                        pdis.toStringAsFixed(0),
                                                        textAlign:
                                                            TextAlign.right,
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.black))),
                                                const SizedBox(width: 12),
                                                SizedBox(
                                                    width: 110,
                                                    child: Text(
                                                        scanned.toString(),
                                                        textAlign:
                                                            TextAlign.right,
                                                        style: TextStyle(
                                                            color: scanned == 0
                                                                ? Colors.red
                                                                : Colors
                                                                    .black)))
                                              ])),
                                    );
                                  },
                                );
                              }))
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                    Card(
                        color: Colors.white,
                        elevation: 2,
                        child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(children: [
                              const Text('Formulario de resultado',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              SwitchListTile(
                                  activeColor: Colors.black,
                                  title: const Text(
                                      'Mercancía identificada con SKU y PDIS?'),
                                  value: q1,
                                  onChanged: (v) {
                                    setState(() => q1 = v);
                                  }),
                              SwitchListTile(
                                  activeColor: Colors.black,
                                  title: const Text(
                                      'Se tuvo faltante en el primer escaneo?'),
                                  value: q2,
                                  onChanged: (v) {
                                    setState(() => q2 = v);
                                  }),
                              SwitchListTile(
                                  activeColor: Colors.black,
                                  title: const Text('Hay mercancía dañada?'),
                                  value: q3,
                                  onChanged: (v) {
                                    setState(() => q3 = v);
                                  }),
                              SwitchListTile(
                                  activeColor: Colors.black,
                                  title: const Text('Hay mercancía en bodega?'),
                                  value: q4,
                                  onChanged: (v) {
                                    setState(() => q4 = v);
                                  }),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          'Porcentaje escaneado: ${(_percentScanned() * 100).toStringAsFixed(1)}%'),
                                      SizedBox(height: 6),
                                      LinearProgressIndicator(
                                          value: _percentScanned()),
                                    ])),
                                const SizedBox(width: 12),
                                Column(children: [
                                  Text(
                                      'Calidad: ${_computeQualityScore().toStringAsFixed(1)}%'),
                                  SizedBox(height: 8),
                                  SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                                value: _computeQualityScore() /
                                                    100),
                                            Text(
                                                '${_computeQualityScore().toStringAsFixed(0)}%')
                                          ]))
                                ])
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                    child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white),
                                        onPressed: _finishInventory,
                                        child:
                                            const Text('Terminar inventario'))),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _pdisBySku.clear();
                                        _scannedBySku.clear();
                                        _selectedJefe = null;
                                        _totalPdis = 0;
                                        _totalScanned = 0;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.black)),
                                    child: const Text('Cancelar'))
                              ])
                            ]))),
                  ] else
                    const Center(
                        child: Text(
                            'Seleccione una jefatura para cargar inventario',
                            style: TextStyle(color: Colors.black)))
                ],
              ),
      ),
    );
  }
}
