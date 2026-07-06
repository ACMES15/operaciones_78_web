import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/firebase_cache_utils.dart';

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

  DateTime? _safeParseDate(dynamic val) {
    if (val == null) return null;
    try {
      if (val is DateTime) return val.toUtc();
      if (val is Timestamp) return val.toDate().toUtc();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toUtc();
        final n = int.tryParse(val);
        if (n != null) return _safeParseDate(n);
        return null;
      }
      if (val is int) {
        final int raw = val;
        const int maxAllow = 8640000000000000;
        final List<int> divisors = [1000000000, 1000000, 1000, 1];
        for (final div in divisors) {
          final cand = raw ~/ div;
          if (cand.abs() > maxAllow) continue;
          try {
            final dt = DateTime.fromMillisecondsSinceEpoch(cand);
            final y = dt.year;
            if (y >= 1970 && y <= 2100) return dt.toUtc();
          } catch (_) {}
        }
        if (raw.abs() <= maxAllow) {
          try {
            final dtm = DateTime.fromMicrosecondsSinceEpoch(raw);
            final y = dtm.year;
            if (y >= 1970 && y <= 2100) return dtm.toUtc();
          } catch (_) {}
        }
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
      DateTime? max;
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
        final norm = _normalizeFirestoreData(data);
        await box.put(id, jsonEncode(norm));
        final parsed = _safeParseDate(data['importedAt']);
        if (parsed != null && (max == null || parsed.isAfter(max)))
          max = parsed;
      }
      if (max != null) await box.put('__lastImportedAt', max.toIso8601String());
      await _loadFromHiveToState();
    } catch (e) {
      print('Error syncing from Firestore: $e');
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

          // Expected headers (in this exact semantic set)
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
          final Map<String, int> headerIndex = {};
          for (int i = 0; i < headerRow.length; i++) {
            final cell = headerRow[i];
            final key = cell?.value?.toString().trim() ?? '';
            if (key.isNotEmpty) headerIndex[norm(key)] = i;
          }

          // build expectedIndex mapping from expectedHeaders -> column index (normalized)
          final Map<String, int> expectedIndex = {};
          final missing = <String>[];
          for (final h in expectedHeaders) {
            final nh = norm(h);
            if (headerIndex.containsKey(nh)) {
              expectedIndex[h] = headerIndex[nh]!;
            } else {
              missing.add(h);
            }
          }
          if (missing.isNotEmpty) {
            final msg = 'Faltan encabezados: ${missing.join(', ')}';
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
            setState(() => _loading = false);
            return;
          }
          for (int r = 1; r < sheet.maxRows; r++) {
            try {
              final row = sheet.row(r);
              if (row.every((c) => (c?.value?.toString() ?? '').isEmpty))
                continue;
              final Map<String, dynamic> obj = {};
              for (final h in expectedHeaders) {
                final idx = expectedIndex[h] ?? -1;
                final cell = (idx >= 0 && idx < row.length) ? row[idx] : null;
                // read everything as text to avoid numeric/date auto-parsing issues
                obj[h] = (cell?.value ?? '').toString();
              }

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
            } catch (e) {
              print('Fila $r omitida por error al parsear: $e');
              continue;
            }
          }

          setState(() {
            _rows =
                parsed; // preview only; user must press 'Guardar' to persist
          });
        } catch (e) {
          print('Error importando excel: $e');
        } finally {
          setState(() => _loading = false);
        }
      });
    });
  }

  Future<void> _saveToFirestoreFromState() async {
    if (_rows.isEmpty) return;
    setState(() => _loading = true);
    try {
      // Option B: save all rows into single document ohpdis/datos
      final List<Map<String, dynamic>> datosMapeados = _rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        // keep fields but remove any non-serializable
        m.remove('__id');
        return m;
      }).toList();
      final payload = {
        'datos': datosMapeados,
        'owner': widget.usuario,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await guardarDatosFirestoreYCache('ohpdis', 'datos', payload);
      await _saveRowsToHive(_rows);
      await _loadFromHiveToState();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos guardados en Firestore')));
    } catch (e) {
      print('Error guardando desde estado: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRows {
    if (_filterJefatura == null || _filterJefatura!.isEmpty) return _rows;
    return _rows
        .where((r) => (r['Jefatura'] ?? '').toString() == _filterJefatura)
        .toList();
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
        // remove currency and thousands separators, allow negative and decimals
        final cleaned =
            s.replaceAll(RegExp(r"[^0-9\-\.,]"), '').replaceAll(',', '.');
        if (cleaned.isEmpty) continue;
        final v = double.tryParse(cleaned);
        if (v != null) return v;
      }
    } catch (_) {}
    return 0.0;
  }

  double get _totalPdisFiltered {
    return _filteredRows.fold(0.0, (double s, r) => s + _getPdisValue(r));
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

    return Scaffold(
      appBar: AppBar(title: const Text('PDIS - Detalle')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          // Controls area with Wrap to avoid overflow
          final controls = Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Text('Filtrar Jefatura: '),
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
                  Text('Filtradas: ${_countFiltered.toString()}'),
                  Text('Total PDIS: ${_totalPdisFiltered.toStringAsFixed(2)}'),
                  TextButton.icon(
                    onPressed: _loading ? null : _importExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar Excel'),
                  ),
                  TextButton.icon(
                    onPressed: (_loading || _rows.isEmpty)
                        ? null
                        : _saveToFirestoreFromState,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          );

          // Executive card view for narrow screens
          if (isNarrow) {
            return Column(
              children: [
                controls,
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredRows.isEmpty
                      ? Center(
                          child: Text(
                              'Sin datos. Usa "Importar Excel" para cargar una vista previa.',
                              style: TextStyle(color: Colors.grey[700])),
                        )
                      : ListView.builder(
                          itemCount: _filteredRows.length,
                          itemBuilder: (context, idx) {
                            final r = _filteredRows[idx];
                            final title =
                                '${(r['Sección'] ?? '-')} - ${(r['REFERENCIA'] ?? r['Referencia'] ?? '-')}';
                            final pdis = (r['__pdis_num'] ?? 0) as double;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                            child: SelectableText(title,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14))),
                                        SelectableText(
                                            '\$${pdis.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 6,
                                      children: [
                                        _smallField('SKU', r['SKU']),
                                        _smallField(
                                            'Documento', r['Documento']),
                                        _smallField(
                                            'Fecha', r['Fecha Documento']),
                                        _smallField('Antigüedad',
                                            r['Antigüedad Documento dias']),
                                        _smallField('Jefatura', r['Jefatura']),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }

          // Wide screen: keep table but allow scrolling both axes, scale columns to fit
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
          final columnWidths = [
            140.0,
            100.0,
            100.0,
            220.0,
            140.0,
            300.0,
            120.0,
            160.0,
            140.0,
            120.0,
            160.0
          ];
          final totalPreferred = columnWidths.fold(0.0, (a, b) => a + b);
          final available = constraints.maxWidth - 40.0; // padding allowance
          final scale = (totalPreferred > 0 && totalPreferred > available)
              ? (available / totalPreferred)
              : 1.0;
          final finalWidths = columnWidths.map((w) => w * scale).toList();

          return Column(
            children: [
              controls,
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          for (var i = 0; i < columns.length; i++)
                            DataColumn(
                                label: Container(
                                    width: finalWidths[i],
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: i == columns.length - 1
                                            ? BorderSide.none
                                            : BorderSide(
                                                color: Colors.grey.shade300),
                                      ),
                                    ),
                                    child: Text(columns[i],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))))
                        ],
                        rows: () {
                          if (_filteredRows.isEmpty) {
                            return [
                              DataRow(
                                cells: columns
                                    .map((c) => DataCell(Text(c,
                                        style: const TextStyle(
                                            color: Colors.grey))))
                                    .toList(),
                              )
                            ];
                          }
                          return _filteredRows.map((r) {
                            String cell(String k) =>
                                (r[k] ?? r[k.trim()] ?? '').toString();
                            final pdis = (r['__pdis_num'] ?? 0) as double;
                            return DataRow(cells: [
                              DataCell(_cellSelectable(cell('Sección'),
                                  width: finalWidths[0],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('SKU'),
                                  width: finalWidths[1],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(pdis.toStringAsFixed(2),
                                  width: finalWidths[2],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('REFERENCIA'),
                                  width: finalWidths[3],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('Tex.Cab.Doc.'),
                                  width: finalWidths[4],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('Descripción'),
                                  width: finalWidths[5],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('Total \$ PDIS'),
                                  width: finalWidths[6],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('Documento'),
                                  width: finalWidths[7],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('Fecha Documento'),
                                  width: finalWidths[8],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(
                                  cell('Antigüedad Documento dias'),
                                  width: finalWidths[9],
                                  showRightBorder: true)),
                              DataCell(_cellSelectable(cell('Jefatura'),
                                  width: finalWidths[10],
                                  showRightBorder: false)),
                            ]);
                          }).toList();
                        }(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _smallField(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SizedBox(
              width: 140,
              child: SelectableText((value ?? '-').toString(),
                  maxLines: 2,
                  showCursor: true,
                  toolbarOptions:
                      const ToolbarOptions(copy: true, selectAll: true),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  onTap: null)),
        ],
      ),
    );
  }

  Widget _cellSelectable(String text,
      {double width = 160, bool showRightBorder = true}) {
    final s = text.toString();
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 60, maxWidth: width),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          border: Border(
            right: showRightBorder
                ? BorderSide(color: Colors.grey.shade300)
                : BorderSide.none,
          ),
        ),
        child: SelectableText(
          s,
          maxLines: 2,
          showCursor: true,
          toolbarOptions: const ToolbarOptions(copy: true, selectAll: true),
          scrollPhysics: const NeverScrollableScrollPhysics(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
