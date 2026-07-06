import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:html' as html;
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
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
  bool _loading = false;
  String? _selectedJefatura;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _ensureFirebase();
    await _ensureHive();
    await _loadFromHiveToState();
    await _fetchPlantillaIfNeeded();
    await _syncFromFirestore();
  }

  String get _boxName => 'ohpdis_cache_${widget.usuario}';

  Future<void> _ensureHive() async {
    try {
      await Hive.initFlutter();
      if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
    } catch (e) {
      print('Hive init error: $e');
    }
  }

  Future<void> _loadFromHiveToState() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final box = Hive.box(_boxName);
      final rows = <Map<String, dynamic>>[];
      for (final key in box.keys) {
        if (key == '__lastImportedAt') continue;
        final v = box.get(key);
        if (v == null) continue;
        if (v is String) {
          try {
            rows.add(Map<String, dynamic>.from(jsonDecode(v)));
          } catch (_) {}
        } else if (v is Map) {
          rows.add(Map<String, dynamic>.from(v));
        }
      }
      setState(() => _rows = rows);
    } catch (e) {
      print('Error loading hive: $e');
    }
  }

  Future<void> _saveRowsToHive(List<Map<String, dynamic>> rows) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
      final box = Hive.box(_boxName);
      for (final r in rows) {
        final id = (r['__id'] ?? '').toString();
        if (id.isEmpty) continue;
        await box.put(id, jsonEncode(r));
      }
    } catch (e) {
      print('Error saving hive: $e');
    }
  }

  Future<void> _ensureFirebase() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (_) {}
  }

  Future<void> _fetchPlantillaIfNeeded() async {
    if (_seccionToJefatura.isNotEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();
      if (doc.exists && doc.data() != null && doc.data()!['datos'] is List) {
        final lista = List<dynamic>.from(doc.data()!['datos']);
        for (final e in lista) {
          if (e is Map && e['SECCION'] != null && e['NOMBRE'] != null) {
            _seccionToJefatura[e['SECCION'].toString()] =
                e['NOMBRE'].toString();
          }
        }
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _syncFromFirestore() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
      final box = Hive.box(_boxName);
      final doc = await FirebaseFirestore.instance
          .collection('ohpdis')
          .doc('datos')
          .get();
      if (!doc.exists || doc.data() == null) return;
      final raw = doc.data()!;
      if (raw['datos'] is! List) return;
      final List items = raw['datos'];
      for (final it in items) {
        if (it is! Map) continue;
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(it.cast<String, dynamic>());
        String id = data['__id']?.toString() ?? '';
        if (id.isEmpty) {
          final seccion = (data['Sección'] ?? '').toString();
          final referencia =
              (data['REFERENCIA'] ?? data['Referencia'] ?? '').toString();
          final pdisNum = (data['__pdis_num'] ?? 0).toString();
          id = base64Url.encode(utf8.encode('$seccion|$referencia|$pdisNum'));
          data['__id'] = id;
        }
        await box.put(
            id,
            jsonEncode(data.map((k, v) => MapEntry(
                k, v is Timestamp ? v.toDate().toIso8601String() : v))));
      }
      await _loadFromHiveToState();
    } catch (e) {
      print('Error syncing from Firestore: $e');
    }
  }

  List<Map<String, dynamic>> get _visibleRows {
    var rows = _rows;
    if (_selectedJefatura != null &&
        _selectedJefatura!.isNotEmpty &&
        _selectedJefatura != 'Todas') {
      rows = rows
          .where((r) => (r['Jefatura'] ?? '').toString() == _selectedJefatura)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      rows = rows.where((r) {
        final desc = (r['Descripción'] ?? '').toString().toLowerCase();
        final ref =
            (r['REFERENCIA'] ?? r['Referencia'] ?? '').toString().toLowerCase();
        return desc.contains(q) || ref.contains(q);
      }).toList();
    }
    return rows;
  }

  Map<String, double> get _totalesPorJefatura {
    final map = <String, double>{};
    for (final r in _rows) {
      final j = (r['Jefatura'] ?? 'Sin Jefatura').toString();
      final val = _getPdisValue(r);
      map[j] = (map[j] ?? 0) + val;
    }
    return map;
  }

  double get _totalVisible =>
      _visibleRows.fold(0.0, (s, r) => s + _getPdisValue(r));

  double get _selectedTotal {
    final sel = _selectedJefatura ?? 'Todas';
    if (sel == 'Todas') return _totalVisible;
    return _totalesPorJefatura[sel] ?? 0.0;
  }

  double _getPdisValue(Map<String, dynamic> r) {
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

  Future<void> _saveToFirestore() async {
    setState(() => _loading = true);
    try {
      await _ensureFirebase();
      final docRef =
          FirebaseFirestore.instance.collection('ohpdis').doc('datos');
      final payload = {
        'datos': _rows.map((r) {
          final m = <String, dynamic>{};
          r.forEach((k, v) {
            if (v is DateTime)
              m[k] = v.toIso8601String();
            else if (v is Timestamp)
              m[k] = v.toDate().toIso8601String();
            else if (v is num || v is bool)
              m[k] = v;
            else
              m[k] = v?.toString();
          });
          return m;
        }).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(payload);
      // After saving, sync back from Firestore into Hive cache
      await _syncFromFirestore();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Guardado en Firestore y cacheado localmente')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _importExcel() async {
    setState(() => _loading = true);
    await _fetchPlantillaIfNeeded();

    final uploadInput = html.FileUploadInputElement()..accept = '.xlsx';
    uploadInput.click();
    uploadInput.onChange.listen((_) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);
      reader.onLoadEnd.listen((event) async {
        try {
          final result = reader.result;
          final Uint8List bytes = result is ByteBuffer
              ? result.asUint8List()
              : (result as Uint8List);
          final excel = ex.Excel.decodeBytes(bytes);
          final parsed = <Map<String, dynamic>>[];

          ex.Sheet? sheet;
          String? sheetNameChosen;
          // Pick the sheet with the largest reported row count (better chance
          // to pick the data sheet when the workbook has multiple small tables)
          for (final entry in excel.tables.entries) {
            final s = entry.value;
            final currentMax = sheet?.maxRows ?? -1;
            if (s.maxRows > currentMax) {
              sheet = s;
              sheetNameChosen = entry.key;
            }
          }
          if (sheet == null) {
            setState(() => _loading = false);
            return;
          }

          // Debug info: report which sheet we chose and its size
          print(
              'Import: chosen sheet=${sheetNameChosen ?? "?"} maxRows=${sheet.maxRows} maxCols=${sheet.maxCols}');

          final expectedHeaders = [
            'Sección',
            'SKU',
            'PDIS',
            'REFERENCIA',
            'Tex.Cab.Doc.',
            'Descripción',
            'Total \$ PDIS',
            'Documento',
            'Fecha Documento',
            'Antigüedad Documento dias',
            'Jefatura'
          ];
          String norm(String s) => s
              .toString()
              .trim()
              .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
              .toLowerCase();

          // Try to detect the header row within the first N rows (some files
          // have top metadata rows before the actual header).
          final headerCandidates = <int, Map<String, int>>{};
          final maxHeaderScan = math.min(10, math.max(1, sheet.maxRows));
          for (int hr = 0; hr < maxHeaderScan; hr++) {
            final row = sheet.row(hr);
            final headerIndex = <String, int>{};
            for (int i = 0; i < row.length; i++) {
              final cell = row[i];
              final key = cell?.value?.toString().trim() ?? '';
              if (key.isNotEmpty) headerIndex[norm(key)] = i;
            }
            headerCandidates[hr] = headerIndex;
          }

          int headerRowIndex = -1;
          Map<String, int> chosenHeaderIndex = {};
          for (final entry in headerCandidates.entries) {
            final matches = expectedHeaders
                .where((h) => entry.value.containsKey(norm(h)))
                .length;
            // choose the row that matches the most expected headers
            if (matches >= (expectedHeaders.length / 2).floor()) {
              headerRowIndex = entry.key;
              chosenHeaderIndex = entry.value;
              break;
            }
          }
          // fallback: pick first candidate if none matched sufficiently
          if (headerRowIndex < 0 && headerCandidates.isNotEmpty) {
            headerRowIndex = headerCandidates.keys.first;
            chosenHeaderIndex = headerCandidates[headerRowIndex]!;
          }

          final headerIndex = chosenHeaderIndex;
          final expectedIndex = <String, int>{};
          final missing = <String>[];
          for (final h in expectedHeaders) {
            final nh = norm(h);
            if (headerIndex.containsKey(nh))
              expectedIndex[h] = headerIndex[nh]!;
            else
              missing.add(h);
          }
          if (missing.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Faltan encabezados: ${missing.join(', ')} (buscado en fila $headerRowIndex)')));
            setState(() => _loading = false);
            return;
          }

          // Some Excel files report a small maxRows; scan forward robustly and
          // stop after N consecutive empty rows. This captures large sheets.
          final int maxScan = math.max(sheet.maxRows, 2000);
          int emptyStreak = 0;
          const int stopAfterEmpty = 200;
          for (int r = headerRowIndex + 1; r < maxScan; r++) {
            try {
              final row = sheet.row(r);
              final isEmpty =
                  row.every((c) => (c?.value?.toString() ?? '').isEmpty);
              if (isEmpty) {
                emptyStreak++;
                if (emptyStreak >= stopAfterEmpty) break;
                continue;
              }
              emptyStreak = 0;
              final obj = <String, dynamic>{};
              for (final h in expectedHeaders) {
                final idx = expectedIndex[h] ?? -1;
                final cell = (idx >= 0 && idx < row.length) ? row[idx] : null;
                obj[h] = (cell?.value ?? '').toString();
              }
              final seccion = (obj['Sección'] ?? '').toString();
              final referencia =
                  (obj['REFERENCIA'] ?? obj['Referencia'] ?? '').toString();
              final pdisStr =
                  (obj['PDIS'] ?? obj['Total \$ PDIS'] ?? '').toString();
              double pdisNum = 0;
              try {
                pdisNum = double.parse(pdisStr
                    .replaceAll(RegExp(r'[^0-9\\\.,-]'), '')
                    .replaceAll(',', '.'));
              } catch (_) {
                pdisNum = 0;
              }
              obj['__pdis_num'] = pdisNum;
              String jef = (obj['Jefatura'] ?? '').toString();
              if (jef.isEmpty && seccion.isNotEmpty)
                jef = _seccionToJefatura[seccion] ?? '';
              obj['Jefatura'] = jef;
              final id = base64Url
                  .encode(utf8.encode('$seccion|$referencia|$pdisNum'));
              obj['__id'] = id;
              parsed.add(obj);
            } catch (e) {
              // ignore row parse errors and continue scanning
              continue;
            }
          }

          setState(() => _rows = parsed);
          await _saveRowsToHive(parsed);
          // show debug summary so user can tell if parsing scanned full sheet
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Importadas ${parsed.length} filas (sheet=${sheetNameChosen ?? "?"} rows:${sheet.maxRows} cols:${sheet.maxCols})')));
        } catch (e) {
          print('Error importando excel: $e');
        } finally {
          setState(() => _loading = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDIS - Importar y Previsualizar'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _importExcel,
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar .xlsx',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Container(
                      width: 44,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _loading
                            ? Colors.grey[300]
                            : Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        tooltip: 'Importar .xlsx',
                        icon: const Icon(Icons.upload_file),
                        color: Colors.white,
                        onPressed: _loading ? null : _importExcel,
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Buscar descripción o referencia',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey[50],
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Filtrar por Jefatura', isDense: true),
                        value: _selectedJefatura ?? 'Todas',
                        items: <String>[
                          'Todas',
                          ..._seccionToJefatura.values.toSet().toList()
                        ].map((s) {
                          final total =
                              (_totalesPorJefatura[s] ?? 0).toStringAsFixed(2);
                          return DropdownMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Expanded(child: Text(s)),
                                Text(total,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedJefatura = v),
                      ),
                    ),
                    Chip(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.12),
                      avatar: Icon(Icons.summarize,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18),
                      label: Text('Total: ${_selectedTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _saveToFirestore,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    if (_loading)
                      const SizedBox(
                          width: 8,
                          height: 24,
                          child: CircularProgressIndicator()),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text('Filas: ${_visibleRows.length}'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                if (wide) {
                  final visible = _visibleRows;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 48),
                        child: SizedBox(
                          width: math.min(constraints.maxWidth, 1200),
                          child: DefaultTextStyle.merge(
                            style: const TextStyle(color: Colors.black),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // header
                                Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.06),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                          width: 220,
                                          child: Text('Sección',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      SizedBox(
                                          width: 120,
                                          child: Center(
                                              child: Text('SKU',
                                                  style: TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w700)))),
                                      SizedBox(
                                          width: 160,
                                          child: Text('Referencia',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      SizedBox(
                                          width: 360,
                                          child: Text('Descripción',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      SizedBox(
                                          width: 200,
                                          child: Text('Jefatura',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      SizedBox(
                                          width: 120,
                                          child: Text('PDIS',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                    ],
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: 200, maxHeight: 9999),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final row = visible[index];
                                      final bg = index.isEven
                                          ? Colors.white
                                          : Colors.grey[50];
                                      return Container(
                                        color: bg,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                                width: 220,
                                                child: Text(
                                                    row['Sección'] ?? '',
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                            SizedBox(
                                                width: 120,
                                                child: Center(
                                                    child: Text(
                                                        row['SKU'] ?? '',
                                                        style: const TextStyle(
                                                            color: Colors
                                                                .black)))),
                                            SizedBox(
                                                width: 160,
                                                child: Text(
                                                    row['REFERENCIA'] ?? '',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.black))),
                                            SizedBox(
                                                width: 360,
                                                child: Text(
                                                    row['Descripción'] ?? '',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.black))),
                                            SizedBox(
                                                width: 200,
                                                child: Text(
                                                    row['Jefatura'] ?? '',
                                                    style: const TextStyle(
                                                        color: Colors.black))),
                                            SizedBox(
                                                width: 120,
                                                child: Text(
                                                    _getPdisValue(row)
                                                        .toStringAsFixed(2),
                                                    textAlign: TextAlign.right,
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w700))),
                                          ],
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
                  );
                }
                final visible = _visibleRows;
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final row = visible[index];
                    final initials = (row['Sección'] ?? '')
                        .toString()
                        .split(' ')
                        .where((s) => s.isNotEmpty)
                        .map((s) => s[0])
                        .take(2)
                        .join();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                          child: Text(initials,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        title: Text(
                          row['Descripción'] ?? row['REFERENCIA'] ?? '',
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      'Jefatura: ${row['Jefatura'] ?? ''}',
                                      style: const TextStyle(
                                          color: Colors.black))),
                              Chip(
                                backgroundColor: Colors.green.shade50,
                                label: Text(
                                    _getPdisValue(row).toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      if (Hive.isBoxOpen(_boxName)) Hive.box(_boxName).close();
    } catch (_) {}
    super.dispose();
  }
}
