import 'dart:convert';
import 'dart:typed_data';
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
  String? _filterJefatura;

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

  final String _boxName = 'ohpdis_cache';

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
      final List<Map<String, dynamic>> rows = [];
      for (final key in box.keys) {
        if (key == '__lastImportedAt') continue;
        final v = box.get(key);
        if (v == null) continue;
        Map<String, dynamic> m;
        if (v is String) {
          try {
            m = Map<String, dynamic>.from(jsonDecode(v));
          } catch (_) {
            continue;
          }
        } else if (v is Map) {
          m = Map<String, dynamic>.from(v);
        } else {
          continue;
        }
        rows.add(m);
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
      DateTime? max;
      for (final r in rows) {
        final id = (r['__id'] ?? '').toString();
        // ensure we store serializable values (DateTime/Timestamp -> ISO string)
        final toStore = <String, dynamic>{};
        r.forEach((k, v) {
          if (v is Timestamp)
            toStore[k] = v.toDate().toIso8601String();
          else if (v is DateTime)
            toStore[k] = v.toIso8601String();
          else
            toStore[k] = v;
        });

        // if importedAt missing, assign local now (helps incremental sync)
        DateTime now = DateTime.now().toUtc();
        if (toStore['importedAt'] == null ||
            toStore['importedAt'].toString().isEmpty) {
          toStore['importedAt'] = now.toIso8601String();
        }

        await box.put(id, jsonEncode(toStore));

        DateTime? d = _safeParseDate(toStore['importedAt']);
        if (d != null && (max == null || d.isAfter(max))) max = d;
      }
      if (max != null) await box.put('__lastImportedAt', max.toIso8601String());
    } catch (e) {
      print('Error saving hive: $e');
    }
  }

  Map<String, dynamic> _normalizeFirestoreData(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      if (v is Timestamp)
        out[k] = v.toDate().toIso8601String();
      else
        out[k] = v;
    });
    return out;
  }

  Future<void> _syncFromFirestore() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
      final box = Hive.box(_boxName);
      final rawLast = box.get('__lastImportedAt');
      DateTime? last;
      if (rawLast is String) {
        last = DateTime.tryParse(rawLast);
        if (last == null) {
          final n = int.tryParse(rawLast);
          if (n != null) {
            try {
              last = DateTime.fromMillisecondsSinceEpoch(n);
            } catch (_) {
              last = null;
            }
          }
        }
      } else if (rawLast is int) {
        try {
          last = DateTime.fromMillisecondsSinceEpoch(rawLast);
        } catch (_) {
          last = null;
        }
      } else if (rawLast is DateTime) {
        last = rawLast;
      } else {
        last = null;
      }
      Query q = FirebaseFirestore.instance.collection('ohpdis');
      if (last != null) {
        try {
          q = q.where('importedAt', isGreaterThan: Timestamp.fromDate(last));
        } catch (_) {
          // ignore invalid last
        }
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) return;
      DateTime? max;
      for (final doc in snap.docs) {
        final raw = doc.data();
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw.cast<String, dynamic>());
        data['__id'] = doc.id;
        final norm = _normalizeFirestoreData(data);
        await box.put(doc.id, jsonEncode(norm));
        final imp = data['importedAt'];
        if (imp is Timestamp) {
          final d = imp.toDate();
          if (max == null || d.isAfter(max)) max = d;
        }
      }
      if (max != null) await box.put('__lastImportedAt', max.toIso8601String());
      await _loadFromHiveToState();
    } catch (e) {
      print('Error syncing from Firestore: $e');
    }
  }

  DateTime? _safeParseDate(dynamic val) {
    if (val == null) return null;
    try {
      if (val is DateTime) return val.toUtc();
      if (val is Timestamp) return val.toDate().toUtc();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toUtc();
        // maybe it's numeric in string
        final n = int.tryParse(val);
        if (n != null) return _safeParseDate(n);
        return null;
      }
      if (val is int) {
        final int raw = val;
        final List<int> divisors = [1, 1000, 1000000, 1000000000];
        for (final div in divisors) {
          try {
            final cand = raw ~/ div;
            final dt = DateTime.fromMillisecondsSinceEpoch(cand);
            final y = dt.year;
            if (y >= 1970 && y <= 2100) return dt.toUtc();
          } catch (_) {
            // try next
          }
        }
        // try microseconds directly
        try {
          final dtm = DateTime.fromMicrosecondsSinceEpoch(raw);
          final y = dtm.year;
          if (y >= 1970 && y <= 2100) return dtm.toUtc();
        } catch (_) {}
        // excel serial days fallback (typical small numbers)
        if (raw > 0 && raw < 200000) {
          try {
            final excelEpoch = DateTime.utc(1899, 12, 30);
            return excelEpoch.add(Duration(days: raw)).toUtc();
          } catch (_) {}
        }
        return null;
      }
    } catch (_) {}
    return null;
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
      }
    } catch (_) {}
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
          final List<Map<String, dynamic>> parsed = [];

          // Use first non-empty sheet
          ex.Sheet? sheet;
          for (final name in excel.tables.keys) {
            final s = excel.tables[name];
            if (s != null && s.maxRows > 0) {
              sheet = s;
              break;
            }
          }
          if (sheet == null) {
            setState(() => _loading = false);
            return;
          }

          // Headers expected (case-insensitive): Sección, SKU, PDIS, REFERENCIA, Tex.Cab.Doc., Descripción, Total $ PDIS, Documento, Fecha Documento, Antigüedad Documento dias, Jefatura
          final headerRow = sheet.row(0);
          final Map<String, int> headerIndex = {};
          for (int i = 0; i < headerRow.length; i++) {
            final cell = headerRow[i];
            final key = cell?.value?.toString().trim() ?? '';
            if (key.isNotEmpty) headerIndex[key] = i;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            final row = sheet.row(r);
            if (row.every((c) => (c?.value?.toString() ?? '').isEmpty))
              continue;
            final Map<String, dynamic> obj = {};
            headerIndex.forEach((key, idx) {
              final cell = idx < row.length ? row[idx] : null;
              obj[key] = cell?.value ?? '';
            });

            // Normalize keys: ensure required keys exist with fallback names
            String seccion = (obj['Sección'] ??
                    obj['Seccion'] ??
                    obj['SECCIÓN'] ??
                    obj['SECTION'] ??
                    '')
                .toString();
            String referencia = (obj['REFERENCIA'] ??
                    obj['Referencia'] ??
                    obj['Descripcion'] ??
                    obj['DESCRIPCIÓN'] ??
                    obj['Descripción'] ??
                    '')
                .toString();
            String pdisStr = (obj['PDIS'] ??
                    obj['Pdis'] ??
                    obj['Total \$ PDIS'] ??
                    obj['Total PDIS'] ??
                    '')
                .toString();
            double pdisNum = 0;
            try {
              pdisNum = double.parse(pdisStr
                  .toString()
                  .replaceAll(RegExp(r'[^0-9\\.,-]'), '')
                  .replaceAll(',', '.'));
            } catch (_) {
              pdisNum = 0;
            }
            obj['__pdis_num'] = pdisNum;

            // Determine Jefatura
            String jef = (obj['Jefatura'] ?? obj['JEFTURA'] ?? '').toString();
            if (jef.isEmpty && seccion.isNotEmpty) {
              jef = _seccionToJefatura[seccion] ?? '';
            }
            obj['Jefatura'] = jef;

            // generate id to avoid duplicates
            final idKey = '$seccion|$referencia|$pdisNum';
            final id = base64Url.encode(utf8.encode(idKey));
            obj['__id'] = id;

            parsed.add(obj);
          }

          setState(() {
            _rows = parsed;
          });

          // Save to Firestore collection 'ohpdis'
          try {
            final col = FirebaseFirestore.instance.collection('ohpdis');
            final batch = FirebaseFirestore.instance.batch();
            for (final r in parsed) {
              final id = (r['__id'] ?? '').toString();
              final docRef = col.doc(id);
              final payload = Map<String, dynamic>.from(r);
              payload.remove('__id');
              payload['__pdis_num'] = (r['__pdis_num'] ?? 0);
              payload['importedAt'] = FieldValue.serverTimestamp();
              batch.set(docRef, payload, SetOptions(merge: true));
            }
            await batch.commit();
            // update local cache (Hive) with parsed rows
            await _saveRowsToHive(parsed);
            await _loadFromHiveToState();
          } catch (e) {
            // ignore write errors but print
            print('Error guardando ohpdis: $e');
          }
        } catch (e) {
          print('Error importando excel: $e');
        } finally {
          setState(() => _loading = false);
        }
      });
    });
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

  int get _countFiltered {
    return _filteredRows.length;
  }

  @override
  Widget build(BuildContext context) {
    final jefaturas = _rows
        .map((r) => (r['Jefatura'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final columns = [
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

    return Scaffold(
      appBar: AppBar(title: const Text('PDIS - Detalle')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Filtrar Jefatura: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterJefatura ?? '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todas'))
                  ]
                      .followedBy(jefaturas.map(
                          (j) => DropdownMenuItem(value: j, child: Text(j))))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _filterJefatura = (v == null || v.isEmpty) ? null : v;
                    });
                  },
                ),
                const SizedBox(width: 16),
                Text('Filtradas: ${_countFiltered.toString()}'),
                const SizedBox(width: 12),
                Text('Total PDIS: ${_totalPdisFiltered.toStringAsFixed(2)}'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading ? null : _importExcel,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar Excel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredRows.isEmpty
                  ? const Center(child: Text('No hay datos importados'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: columns
                            .map((c) => DataColumn(label: Text(c)))
                            .toList(),
                        rows: _filteredRows.map((r) {
                          String cell(String k) =>
                              (r[k] ?? r[k.trim()] ?? '').toString();
                          return DataRow(cells: [
                            DataCell(Text(cell('Sección'))),
                            DataCell(Text(cell('SKU'))),
                            DataCell(Text((r['__pdis_num'] ?? 0).toString())),
                            DataCell(Text(cell('REFERENCIA'))),
                            DataCell(Text(cell('Tex.Cab.Doc.'))),
                            DataCell(Text(cell('Descripción'))),
                            DataCell(Text(cell('Total \$ PDIS'))),
                            DataCell(Text(cell('Documento'))),
                            DataCell(Text(cell('Fecha Documento'))),
                            DataCell(Text(cell('Antigüedad Documento dias'))),
                            DataCell(Text(cell('Jefatura'))),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
