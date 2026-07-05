import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PdisDetailPage extends StatefulWidget {
  final String usuario;
  const PdisDetailPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<PdisDetailPage> createState() => _PdisDetailPageState();
}

class _PdisDetailPageState extends State<PdisDetailPage> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _seccionToJefatura = {};
  String? _filterJefatura;
  bool _hiveAvailable = false;
  Box? _hiveBox;

  @override
  void initState() {
    super.initState();
    _loadPlantillaCache();
    _loadCacheThenMaybeCloud();
  }

  Future<void> _loadPlantillaCache() async {
    try {
      final cache = html.window.localStorage['plantilla_ejecutiva_cache'];
      if (cache != null) {
        final List<dynamic> datos = jsonDecode(cache);
        for (final d in datos) {
          if (d is Map && d['SECCION'] != null && d['NOMBRE'] != null) {
            _seccionToJefatura[d['SECCION'].toString()] =
                d['NOMBRE'].toString();
          }
        }
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _importExcel() async {
    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) async {
        final result = reader.result;
        final Uint8List bytes =
            result is ByteBuffer ? result.asUint8List() : (result as Uint8List);
        final excel = ex.Excel.decodeBytes(bytes);
        final List<Map<String, dynamic>> parsed = [];
        for (final sheetName in excel.tables.keys) {
          final sheet = excel.tables[sheetName];
          if (sheet == null) continue;
          if (sheet.maxRows < 1) continue;
          // Map headers -> colIndex
          final headerRow = sheet.row(0);
          final Map<String, int> headerIndex = {};
          for (int i = 0; i < headerRow.length; i++) {
            final cell = headerRow[i];
            final key = cell?.value?.toString().trim() ?? '';
            if (key.isNotEmpty) headerIndex[key] = i;
          }
          for (int r = 1; r < sheet.maxRows; r++) {
            final row = sheet.row(r);
            final Map<String, dynamic> obj = {};
            String seccion = '';
            headerIndex.forEach((key, idx) {
              final cell = idx < row.length ? row[idx] : null;
              final val = cell?.value?.toString() ?? '';
              obj[key] = val;
              if (key.toLowerCase().contains('sección') ||
                  key.toLowerCase().contains('seccion')) {
                seccion = val;
              }
            });
            // Normalize expected fields
            // Buscar la columna que contenga 'pdis' en su nombre (ignorando mayúsculas y caracteres especiales)
            String pdisValue = '';
            for (final k in obj.keys) {
              final kn = k
                  .toString()
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9]'), '');
              if (kn.contains('pdis')) {
                pdisValue = (obj[k] ?? '').toString();
                break;
              }
            }
            // Fallback a claves comunes
            if (pdisValue.isEmpty)
              pdisValue = (obj['PDIS'] ?? obj['Total PDIS'] ?? '').toString();
            double pdisNum = 0;
            try {
              pdisNum = double.parse(pdisValue
                  .replaceAll(RegExp(r'[^0-9\.,-]'), '')
                  .replaceAll(',', '.'));
            } catch (_) {
              pdisNum = 0;
            }
            obj['__pdis_num'] = pdisNum;
            // Jefatura auto
            String jef = (obj['Jefatura'] ?? '').toString();
            if (jef.isEmpty && seccion.isNotEmpty) {
              jef = _seccionToJefatura[seccion] ?? '';
              if (jef.isEmpty) {
                // buscar en Firestore plantilla_ejecutiva/datos
                try {
                  final doc = await FirebaseFirestore.instance
                      .collection('plantilla_ejecutiva')
                      .doc('datos')
                      .get();
                  if (doc.exists &&
                      doc.data() != null &&
                      doc.data()!['datos'] is List) {
                    final lista = List<dynamic>.from(doc.data()!['datos']);
                    final match = lista.firstWhere(
                        (e) => e is Map && e['SECCION'] == seccion,
                        orElse: () => null);
                    if (match != null && match['NOMBRE'] != null) {
                      jef = match['NOMBRE'].toString();
                      _seccionToJefatura[seccion] = jef;
                      // update cache
                      try {
                        final cache = html
                            .window.localStorage['plantilla_ejecutiva_cache'];
                        List<dynamic> cacheList = [];
                        if (cache != null)
                          cacheList = List<dynamic>.from(jsonDecode(cache));
                        bool updated = false;
                        for (final item in cacheList) {
                          if (item is Map && item['SECCION'] == seccion) {
                            item['NOMBRE'] = jef;
                            updated = true;
                            break;
                          }
                        }
                        if (!updated)
                          cacheList.add({'SECCION': seccion, 'NOMBRE': jef});
                        html.window.localStorage['plantilla_ejecutiva_cache'] =
                            jsonEncode(cacheList);
                      } catch (_) {}
                    }
                  }
                } catch (_) {}
              }
            }
            obj['Jefatura'] = jef;
            parsed.add(obj);
          }
        }
        setState(() {
          _rows = parsed;
        });
        // Save locally and to Firestore
        try {
          await _saveLocalCache(parsed);
        } catch (_) {}
        try {
          await _saveToFirestore(parsed);
        } catch (_) {}
      });
    });
  }

  // Load local cache (Hive preferred) and check cloud updatedAt to avoid unnecessary reads
  Future<void> _loadCacheThenMaybeCloud() async {
    try {
      if (!Hive.isBoxOpen('pdis_cache')) {
        await Hive.initFlutter();
        _hiveBox = await Hive.openBox('pdis_cache');
      } else {
        _hiveBox = Hive.box('pdis_cache');
      }
      _hiveAvailable = true;
    } catch (_) {
      _hiveAvailable = false;
      _hiveBox = null;
    }

    // Load local
    try {
      if (_hiveAvailable && _hiveBox != null && _hiveBox!.containsKey('data')) {
        final data = _hiveBox!.get('data');
        if (data is Map) {
          final rows =
              List<Map<String, dynamic>>.from((data['rows'] ?? []) as List);
          setState(() => _rows = rows);
        }
      } else {
        final cache = html.window.localStorage['pdis_cache'];
        if (cache != null) {
          final parsed = jsonDecode(cache) as Map<String, dynamic>;
          final rows = List<Map<String, dynamic>>.from(parsed['rows'] ?? []);
          setState(() => _rows = rows);
        }
      }
    } catch (_) {}

    // Check cloud updatedAt
    try {
      final docRef =
          FirebaseFirestore.instance.collection('pdis').doc('latest');
      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final docData = Map<String, dynamic>.from(doc.data()!);
        final cloudUpdated = docData['updatedAt'];
        DateTime? cloudDt;
        if (cloudUpdated is Timestamp)
          cloudDt = cloudUpdated.toDate();
        else if (cloudUpdated is String)
          cloudDt = DateTime.tryParse(cloudUpdated);

        DateTime? localDt;
        if (_hiveAvailable &&
            _hiveBox != null &&
            _hiveBox!.containsKey('data')) {
          try {
            final data = Map<String, dynamic>.from(_hiveBox!.get('data'));
            localDt = data['syncedAt'] != null
                ? DateTime.tryParse(data['syncedAt'])
                : null;
          } catch (_) {}
        } else {
          try {
            final cache = html.window.localStorage['pdis_cache'];
            if (cache != null) {
              final parsed = jsonDecode(cache) as Map<String, dynamic>;
              localDt = parsed['syncedAt'] != null
                  ? DateTime.tryParse(parsed['syncedAt'])
                  : null;
            }
          } catch (_) {}
        }

        if (cloudDt != null && (localDt == null || cloudDt.isAfter(localDt))) {
          final cloudRows =
              List<Map<String, dynamic>>.from(docData['rows'] ?? []);
          setState(() => _rows = cloudRows);
          await _saveLocalCache(cloudRows, syncedAt: cloudDt.toIso8601String());
        }
      }
    } catch (_) {}
  }

  Future<void> _saveLocalCache(List<Map<String, dynamic>> rows,
      {String? syncedAt}) async {
    final data = {
      'rows': rows,
      'syncedAt': syncedAt ?? DateTime.now().toIso8601String()
    };
    try {
      if (_hiveAvailable && _hiveBox != null) {
        await _hiveBox!.put('data', data);
      } else {
        html.window.localStorage['pdis_cache'] = jsonEncode(data);
      }
    } catch (_) {}
  }

  Future<void> _saveToFirestore(List<Map<String, dynamic>> rows) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('pdis').doc('latest');
      await docRef
          .set({'rows': rows, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredRows {
    if (_filterJefatura == null || _filterJefatura!.isEmpty) return _rows;
    return _rows
        .where((r) => (r['Jefatura'] ?? '').toString() == _filterJefatura)
        .toList();
  }

  double get _totalPdisFiltered {
    return _filteredRows.fold(
        0.0, (s, r) => s + ((r['__pdis_num'] ?? 0) as double));
  }

  @override
  Widget build(BuildContext context) {
    final jefaturas = _rows
        .map((r) => (r['Jefatura'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        title: const Text('OH PDIS - Detalle ejecutivo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Detalle PDIS',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total PDIS',
                        style: TextStyle(color: Colors.black54)),
                    Text('\$${_totalPdisFiltered.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<String>(
                  hint: const Text('Filtrar por Jefatura'),
                  value: _filterJefatura,
                  items: [
                        const DropdownMenuItem(value: '', child: Text('Todas'))
                      ] +
                      jefaturas
                          .map(
                              (j) => DropdownMenuItem(value: j, child: Text(j)))
                          .toList(),
                  onChanged: (v) {
                    setState(() {
                      _filterJefatura = (v == null || v.isEmpty) ? null : v;
                    });
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Importar desde Excel'),
                  onPressed: _importExcel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('No hay datos importados'))
                  : ListView.builder(
                      itemCount: _filteredRows.length,
                      itemBuilder: (context, idx) {
                        final row = _filteredRows[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          row['Sección'] ??
                                              row['Seccion'] ??
                                              '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text((row['Descripción'] ??
                                              row['Descripcion'] ??
                                              row['REFERENCIA'] ??
                                              '')
                                          .toString()),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        'PDIS: \$${(row['__pdis_num'] ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text('Jefatura: ${row['Jefatura'] ?? ''}',
                                        style: const TextStyle(
                                            color: Colors.black54)),
                                  ],
                                )
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
    );
  }
}
