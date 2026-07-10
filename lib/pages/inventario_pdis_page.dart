import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';

class InventarioPdisPage extends StatefulWidget {
  final String usuario;
  final Map<String, dynamic>? initialPayload;
  const InventarioPdisPage(
      {Key? key, required this.usuario, this.initialPayload})
      : super(key: key);

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
  // SKUs scanned but not present in plantilla for the selected jefe
  final Map<String, int> _sobrantesBySku = {};

  int _totalPdis = 0;
  int _totalScanned = 0;
  int _totalSobrantes = 0;

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
    // If page was opened to edit a historic inventory, apply payload
    if (widget.initialPayload != null) {
      Future.microtask(() => _applyInitialPayload(widget.initialPayload!));
    }
  }

  void _applyInitialPayload(Map<String, dynamic> payload) {
    final jefe = payload['jefe']?.toString();
    if (jefe == null) return;
    setState(() {
      _selectedJefe = jefe;
    });
    _buildSkuAggregates();

    // apply scanned counts from payload skus
    if (payload['skus'] is Map) {
      (payload['skus'] as Map).forEach((k, v) {
        final key = k.toString();
        if (v is Map && v['scanned'] != null) {
          final sv = v['scanned'];
          final scanned =
              sv is num ? sv.toInt() : int.tryParse(sv.toString()) ?? 0;
          if (_scannedBySku.containsKey(key)) _scannedBySku[key] = scanned;
        }
      });
    }

    // apply sobrantes
    if (payload['sobrantes'] is Map) {
      (payload['sobrantes'] as Map).forEach((k, v) {
        final key = k.toString();
        final val = v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
        _sobrantesBySku[key] = val;
      });
    }

    setState(() {
      q1 = payload['q1'] == true;
      q2 = payload['q2'] == true;
      q3 = payload['q3'] == true;
      q4 = payload['q4'] == true;
    });

    _recalcTotals();
    // focus scan field after applying
    Future.delayed(
        const Duration(milliseconds: 100), () => _scanFocus.requestFocus());
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
    _sobrantesBySku.clear();
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
    // No está en la plantilla del jefe: registrar como sobrante (solo en este reporte)
    _sobrantesBySku[sku] = (_sobrantesBySku[sku] ?? 0) + 1;
    _recalcTotals();
    _scanController.clear();
    _scanFocus.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'SKU "$sku" registrado como SOBRANTE (no se modifica OHPDIS)')));
  }

  void _recalcTotals() {
    final scannedFromPdis = _scannedBySku.values.fold(0, (s, v) => s + v);
    final scannedSobrantes = _sobrantesBySku.values.fold(0, (s, v) => s + v);
    _totalScanned = scannedFromPdis; // Escaneado = dentro de plantilla
    _totalSobrantes = scannedSobrantes; // sobrantes detectados al escanear
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
      'sobrantes': _sobrantesBySku,
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
    sheet.appendRow(['SKU', 'PDIS', 'Escaneado', 'Tipo']);

    // primero los SKUs de la plantilla
    for (final sku in _pdisBySku.keys) {
      final pdis = _pdisBySku[sku] ?? 0.0;
      final scanned = _scannedBySku[sku] ?? 0;
      sheet.appendRow([sku, pdis.toStringAsFixed(0), scanned, '']);
    }
    // luego los sobrantes detectados al escanear
    for (final sku in _sobrantesBySku.keys) {
      if (_pdisBySku.containsKey(sku)) continue;
      final scanned = _sobrantesBySku[sku] ?? 0;
      sheet.appendRow([sku, '0', scanned, 'SOBRANTE']);
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
          final isMobile = MediaQuery.of(ctx).size.width < 600;
          return AlertDialog(
            title: Row(children: const [
              Icon(Icons.info_outline, color: Colors.black),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Faltantes',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black)))
            ]),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 800,
                  maxHeight: isMobile ? 520 : 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Definiciones:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                      'PDIS: cantidad registrada en la plantilla para ese SKU.\nFaltante: PDIS menos la cantidad escaneada. Aquí se muestran los SKUs que requieren atención.'),
                  const SizedBox(height: 12),
                  if (faltantes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No hay SKUs con faltante',
                          style: TextStyle(color: Colors.black)),
                    )
                  else
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            color: Colors.grey.shade100,
                            child: Row(
                              children: const [
                                Expanded(
                                    child: Text('SKU',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(
                                    width: 80,
                                    child: Text('PDIS',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(
                                    width: 80,
                                    child: Text('Escaneado',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(
                                    width: 80,
                                    child: Text('Faltante',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red))),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemCount: faltantes.length,
                              itemBuilder: (context, i) {
                                final row = faltantes[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Text(row['sku'] ?? '',
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                      SizedBox(
                                          width: 80,
                                          child: Text('${row['pdis']}',
                                              textAlign: TextAlign.right)),
                                      SizedBox(
                                          width: 80,
                                          child: Text('${row['scanned']}',
                                              textAlign: TextAlign.right)),
                                      SizedBox(
                                          width: 80,
                                          child: Text('${row['falta']}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold)))
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        ],
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
                          child: const Text('Cargar')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _exportToExcel,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white),
                          child: const Text('Exportar Excel'))
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    if (_selectedJefe == null) {
                      return const Center(
                          child: Text(
                              'Seleccione una jefatura para cargar inventario',
                              style: TextStyle(color: Colors.black)));
                    }
                    final isMobile = MediaQuery.of(context).size.width < 600;

                    // Desktop / Tablet: keep existing spacious layout
                    if (!isMobile) {
                      return Column(children: [
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
                              Text(
                                  'Escaneado: $_totalScanned (Sobrantes: $_totalSobrantes)',
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
                                                    fontWeight:
                                                        FontWeight.w700))),
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
                                    final pdisKeys = _pdisBySku.keys.toList()
                                      ..sort((a, b) {
                                        final remA =
                                            (_pdisBySku[a]?.round() ?? 0) -
                                                (_scannedBySku[a] ?? 0);
                                        final remB =
                                            (_pdisBySku[b]?.round() ?? 0) -
                                                (_scannedBySku[b] ?? 0);
                                        if (remA != remB)
                                          return remB.compareTo(remA);
                                        return a.compareTo(b);
                                      });
                                    final sobranteKeys = _sobrantesBySku.keys
                                        .where(
                                            (k) => !_pdisBySku.containsKey(k))
                                        .toList();
                                    final totalCount =
                                        pdisKeys.length + sobranteKeys.length;

                                    return ListView.builder(
                                      itemCount: totalCount,
                                      itemBuilder: (context, index) {
                                        final isPdis = index < pdisKeys.length;
                                        final sku = isPdis
                                            ? pdisKeys[index]
                                            : sobranteKeys[
                                                index - pdisKeys.length];
                                        final pdis = _pdisBySku[sku] ?? 0.0;
                                        final scanned = isPdis
                                            ? (_scannedBySku[sku] ?? 0)
                                            : (_sobrantesBySku[sku] ?? 0);
                                        return ListTile(
                                          title: Text(
                                              isPdis ? sku : '$sku (SOBRANTE)',
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
                                                            pdis.toStringAsFixed(
                                                                0),
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .black))),
                                                    const SizedBox(width: 12),
                                                    SizedBox(
                                                        width: 110,
                                                        child: Text(
                                                            scanned.toString(),
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: TextStyle(
                                                                color: scanned ==
                                                                        0
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
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
                                      title:
                                          const Text('Hay mercancía dañada?'),
                                      value: q3,
                                      onChanged: (v) {
                                        setState(() => q3 = v);
                                      }),
                                  SwitchListTile(
                                      activeColor: Colors.black,
                                      title: const Text(
                                          'Hay mercancía en bodega?'),
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
                                                    value:
                                                        _computeQualityScore() /
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
                                            child: const Text(
                                                'Terminar inventario'))),
                                    const SizedBox(width: 12),
                                    OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            _pdisBySku.clear();
                                            _scannedBySku.clear();
                                            _sobrantesBySku.clear();
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
                                ])))
                      ]);
                    }

                    // Mobile layout: totals above scan field, scan area includes Faltantes button,
                    // constrained list height and single scrollable column so form/buttons can be reached.
                    final listHeight =
                        MediaQuery.of(context).size.height * 0.36;
                    return Expanded(
                        child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: Colors.white,
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                          child: Text('Total PDIS: $_totalPdis',
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                      Flexible(
                                          child: Text(
                                              'Escaneado: $_totalScanned (Sobrantes: $_totalSobrantes)',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                      Flexible(
                                          child: Text(
                                              'Faltante: ${_totalPdis - _totalScanned}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(
                                        child: TextField(
                                      controller: _scanController,
                                      focusNode: _scanFocus,
                                      decoration: const InputDecoration(
                                          labelText: 'Escanear SKU',
                                          border: OutlineInputBorder()),
                                      onSubmitted: _onScanSubmitted,
                                    )),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _showFaltantesDialog,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white),
                                      child: const Text('Faltantes'),
                                    )
                                  ])
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                              height: listHeight.clamp(220.0, 420.0),
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
                                                      fontWeight:
                                                          FontWeight.w700))),
                                          SizedBox(
                                              width: 100,
                                              child: Text('PDIS',
                                                  textAlign: TextAlign.right)),
                                          SizedBox(
                                              width: 100,
                                              child: Text('Escaneado',
                                                  textAlign: TextAlign.right)),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(child: Builder(builder: (context) {
                                      final pdisKeys = _pdisBySku.keys.toList()
                                        ..sort((a, b) {
                                          final remA =
                                              (_pdisBySku[a]?.round() ?? 0) -
                                                  (_scannedBySku[a] ?? 0);
                                          final remB =
                                              (_pdisBySku[b]?.round() ?? 0) -
                                                  (_scannedBySku[b] ?? 0);
                                          if (remA != remB)
                                            return remB.compareTo(remA);
                                          return a.compareTo(b);
                                        });
                                      final sobranteKeys = _sobrantesBySku.keys
                                          .where(
                                              (k) => !_pdisBySku.containsKey(k))
                                          .toList();
                                      final totalCount =
                                          pdisKeys.length + sobranteKeys.length;

                                      return ListView.builder(
                                        itemCount: totalCount,
                                        itemBuilder: (context, index) {
                                          final isPdis =
                                              index < pdisKeys.length;
                                          final sku = isPdis
                                              ? pdisKeys[index]
                                              : sobranteKeys[
                                                  index - pdisKeys.length];
                                          final pdis = _pdisBySku[sku] ?? 0.0;
                                          final scanned = isPdis
                                              ? (_scannedBySku[sku] ?? 0)
                                              : (_sobrantesBySku[sku] ?? 0);
                                          return ListTile(
                                            title: Text(
                                                isPdis
                                                    ? sku
                                                    : '$sku (SOBRANTE)',
                                                style: const TextStyle(
                                                    color: Colors.black)),
                                            trailing: SizedBox(
                                                width: 200,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    SizedBox(
                                                        width: 80,
                                                        child: Text(
                                                            pdis.toStringAsFixed(
                                                                0),
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .black))),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                        width: 80,
                                                        child: Text(
                                                            scanned.toString(),
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: TextStyle(
                                                                color: scanned ==
                                                                        0
                                                                    ? Colors.red
                                                                    : Colors
                                                                        .black))),
                                                  ],
                                                )),
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
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    SwitchListTile(
                                        activeColor: Colors.black,
                                        title: const Text(
                                            'Mercancía identificada con SKU y PDIS?'),
                                        value: q1,
                                        onChanged: (v) =>
                                            setState(() => q1 = v)),
                                    SwitchListTile(
                                        activeColor: Colors.black,
                                        title: const Text(
                                            'Se tuvo faltante en el primer escaneo?'),
                                        value: q2,
                                        onChanged: (v) =>
                                            setState(() => q2 = v)),
                                    SwitchListTile(
                                        activeColor: Colors.black,
                                        title:
                                            const Text('Hay mercancía dañada?'),
                                        value: q3,
                                        onChanged: (v) =>
                                            setState(() => q3 = v)),
                                    SwitchListTile(
                                        activeColor: Colors.black,
                                        title: const Text(
                                            'Hay mercancía en bodega?'),
                                        value: q4,
                                        onChanged: (v) =>
                                            setState(() => q4 = v)),
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
                                                value: _percentScanned())
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
                                                      value:
                                                          _computeQualityScore() /
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
                                                  foregroundColor:
                                                      Colors.white),
                                              onPressed: _finishInventory,
                                              child: const Text(
                                                  'Terminar inventario'))),
                                      const SizedBox(width: 12),
                                      OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _pdisBySku.clear();
                                              _scannedBySku.clear();
                                              _sobrantesBySku.clear();
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
                                  ])))
                        ],
                      ),
                    ));
                  })
                ],
              ),
      ),
    );
  }
}
