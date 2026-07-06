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
          final headerRow = sheet.row(0);
          final headerIndex = <String, int>{};
          for (int i = 0; i < headerRow.length; i++) {
            final cell = headerRow[i];
            final key = cell?.value?.toString().trim() ?? '';
            if (key.isNotEmpty) headerIndex[norm(key)] = i;
          }

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
                content: Text('Faltan encabezados: ${missing.join(', ')}')));
            setState(() => _loading = false);
            return;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            try {
              final row = sheet.row(r);
              if (row.every((c) => (c?.value?.toString() ?? '').isEmpty))
                continue;
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
              continue;
            }
          }

          setState(() => _rows = parsed);
          await _saveRowsToHive(parsed);
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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _importExcel,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar .xlsx'),
                ),
                const SizedBox(width: 12),
                if (_loading) const CircularProgressIndicator(),
                const Spacer(),
                Text('Filas: ${_rows.length}'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                if (wide) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return ListTile(
                            title: Text(
                                row['Descripción'] ?? row['REFERENCIA'] ?? ''),
                            subtitle: Text(
                                'Jefatura: ${row['Jefatura'] ?? ''} — PDIS: ${_getPdisValue(row)}'),
                          );
                        },
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    return Card(
                      child: ListTile(
                        title:
                            Text(row['Descripción'] ?? row['REFERENCIA'] ?? ''),
                        subtitle: Text(
                            'Jefatura: ${row['Jefatura'] ?? ''} — PDIS: ${_getPdisValue(row)}'),
                      ),
                    );
                  },
                );
              }),
            )
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
