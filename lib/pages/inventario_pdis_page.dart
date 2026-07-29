import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:async';

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
  // session support
  String? _currentSessionId;
  List<Map<String, dynamic>> _availableSessions = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionsListSub;
  // selected sessions for combining (store docId)
  final Set<String> _selectedSessionDocIds = {};

  // Aggregated by SKU for selected jefe
  final Map<String, double> _pdisBySku = {};
  final Map<String, int> _scannedBySku = {};
  // SKUs scanned but not present in plantilla for the selected jefe
  final Map<String, int> _sobrantesBySku = {};

  // scans from other users (sku -> usuario -> count)
  final Map<String, Map<String, int>> _scansFromOthers = {};
  // latest server totals for skus/sobrantes (from inprogress snapshot)
  final Map<String, int> _serverScannedBySku = {};
  final Map<String, int> _serverSobrantesBySku = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _historicSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _inprogressSub;

  // applied counts from inprogress doc to avoid double-applying deltas
  final Map<String, int> _appliedInprogressScanned = {};
  final Map<String, int> _appliedInprogressSobrantes = {};

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
    _subscribeHistoricScans();
    _fetchAvailableSessions();
    _subscribeInprogress();
  }

  Future<void> _fetchAvailableSessions() async {
    _sessionsListSub?.cancel();
    _availableSessions.clear();
    if (_selectedJefe == null) return;
    try {
      final qBase = FirebaseFirestore.instance
          .collection('inventarios_inprogress')
          .where('jefe', isEqualTo: _selectedJefe)
          .where('dateKey', isEqualTo: _todayKey())
          .where('status', isEqualTo: 'open')
          .orderBy('updatedAt', descending: true);

      // Try to fetch fresh results directly from server first (helps when other clients just created a session)
      try {
        final serverSnap = await qBase.get(GetOptions(source: Source.server));
        _availableSessions = serverSnap.docs.map((d) {
          final data = d.data();
          return {
            'docId': d.id,
            'sessionId': (data['sessionId'] ?? d.id).toString(),
            'contributors': data['contributors'] is Map
                ? Map<String, dynamic>.from(data['contributors'])
                : {},
            'createdBy': data['createdBy']?.toString() ?? '',
          };
        }).toList();
        print(
            'Fetched (server) ${_availableSessions.length} sessions for $_selectedJefe');
        setState(() {});
      } catch (e) {
        // server read may fail (rules, network) — ignore and rely on snapshots below
        print('Server fetch failed: $e');
      }

      final q = qBase.withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (m, _) => m);

      _sessionsListSub = q.snapshots().listen((snap) {
        _availableSessions = snap.docs.map((d) {
          final data = d.data();
          return {
            'docId': d.id,
            'sessionId': (data['sessionId'] ?? d.id).toString(),
            'contributors': data['contributors'] is Map
                ? Map<String, dynamic>.from(data['contributors'])
                : {},
            'createdBy': data['createdBy']?.toString() ?? '',
          };
        }).toList();
        // debug
        print(
            'Fetched (snapshots) ${_availableSessions.length} sessions for $_selectedJefe');
        setState(() {});
      });
    } catch (e) {
      print('Error fetching sessions: $e');
    }
  }

  Future<void> _createSession() async {
    if (_selectedJefe == null) return;
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    final id = '${_selectedJefe}_${_todayKey()}_$sessionId';
    final docRef =
        FirebaseFirestore.instance.collection('inventarios_inprogress').doc(id);
    final payload = {
      'sessionId': sessionId,
      'jefe': _selectedJefe,
      'dateKey': _todayKey(),
      'skus': {},
      'sobrantes': {},
      'contributors': {widget.usuario: FieldValue.serverTimestamp()},
      'createdBy': widget.usuario,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await docRef.set(payload);
      // confirm write on server so other devices can observe it immediately
      bool seen = false;
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          final snap = await docRef.get(GetOptions(source: Source.server));
          if (snap.exists) {
            seen = true;
            break;
          }
        } catch (_) {
          // ignore and retry
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      setState(() => _currentSessionId = sessionId);
      _fetchAvailableSessions();
      _subscribeInprogress();
      if (seen) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sesión creada y visible. ID: $id')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Sesión creada (no confirmada en servidor). ID: $id - revise consola o Firebase Console')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error creando sesión: $e')));
    }
  }

  Future<void> _closeSession(String docId) async {
    if (docId.isEmpty) return;
    final docRef = FirebaseFirestore.instance
        .collection('inventarios_inprogress')
        .doc(docId);
    try {
      await docRef.set({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': widget.usuario
      }, SetOptions(merge: true));
      // refresh list so other clients stop seeing it
      _fetchAvailableSessions();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sesión cerrada')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error cerrando sesión: $e')));
    }
  }

  void _joinSession(String sessionId) {
    setState(() {
      _currentSessionId = sessionId;
    });
    // mark user as contributor in session doc
    if (_selectedJefe != null) {
      final id = '${_selectedJefe}_${_todayKey()}_${sessionId}';
      final docRef = FirebaseFirestore.instance
          .collection('inventarios_inprogress')
          .doc(id);
      try {
        docRef.set({
          'contributors': {widget.usuario: FieldValue.serverTimestamp()},
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
        // refresh sessions list so other UI updates quickly
        _fetchAvailableSessions();
      } catch (e) {
        print('Error joining session contributors: $e');
      }
    }
    _subscribeInprogress();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sesion seleccionada')));
  }

  void _subscribeHistoricScans() {
    // cancel previous
    _historicSub?.cancel();
    _scansFromOthers.clear();
    if (_selectedJefe == null) return;
    try {
      final q = FirebaseFirestore.instance
          .collection('inventarios_historico')
          .where('jefe', isEqualTo: _selectedJefe)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .withConverter<Map<String, dynamic>>(
              fromFirestore: (snap, _) => snap.data() ?? {},
              toFirestore: (m, _) => m);

      _historicSub = q.snapshots().listen((snap) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final usuario = (data['usuario'] ?? '').toString();
          if (usuario.isEmpty || usuario == widget.usuario) continue;
          // skus map
          if (data['skus'] is Map) {
            (data['skus'] as Map).forEach((k, v) {
              final sku = k.toString();
              int cnt = 0;
              if (v is Map && v['scanned'] != null) {
                final sv = v['scanned'];
                cnt = sv is num ? sv.toInt() : int.tryParse(sv.toString()) ?? 0;
              }
              if (cnt <= 0) return;
              final mapForSku = _scansFromOthers[sku] ?? {};
              mapForSku[usuario] = (mapForSku[usuario] ?? 0) + cnt;
              _scansFromOthers[sku] = mapForSku;
            });
          }
          // sobrantes next
          if (data['sobrantes'] is Map) {
            (data['sobrantes'] as Map).forEach((k, v) {
              final sku = k.toString();
              final cnt =
                  v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
              if (cnt <= 0) return;
              final mapForSku = _scansFromOthers[sku] ?? {};
              mapForSku[usuario] = (mapForSku[usuario] ?? 0) + cnt;
              _scansFromOthers[sku] = mapForSku;
            });
          }
        }
        setState(() {});
      });
    } catch (e) {
      print('Error subscribing historic scans: $e');
    }
  }

  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      if (html.window.navigator.clipboard != null) {
        await html.window.navigator.clipboard!.writeText(text);
      } else {
        // fallback for older browsers
        final ta = html.TextAreaElement();
        ta.value = text;
        html.document.body?.append(ta);
        ta.select();
        html.document.execCommand('copy');
        ta.remove();
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ID copiado')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error copiando ID: $e')));
    }
  }

  void _subscribeInprogress() {
    _inprogressSub?.cancel();
    _appliedInprogressScanned.clear();
    _appliedInprogressSobrantes.clear();
    if (_selectedJefe == null) return;
    // support session-specific doc id when _currentSessionId is set
    final id = _currentSessionId != null
        ? '${_selectedJefe}_${_todayKey()}_${_currentSessionId}'
        : '${_selectedJefe}_${_todayKey()}';
    final docRef = FirebaseFirestore.instance
        .collection('inventarios_inprogress')
        .doc(id)
        .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? {},
            toFirestore: (m, _) => m);
    _inprogressSub = docRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      // update server totals maps (don't mix into local '_scannedBySku' which is local-only)
      if (data['skus'] is Map) {
        (data['skus'] as Map).forEach((k, v) {
          final sku = k.toString();
          int docCount = 0;
          if (v is Map && v['scanned'] != null) {
            final sv = v['scanned'];
            docCount =
                sv is num ? sv.toInt() : int.tryParse(sv.toString()) ?? 0;
          }
          _serverScannedBySku[sku] = docCount;
          // track applied value so local writes won't cause duplicate UI increments
          _appliedInprogressScanned[sku] = docCount;
        });
      }
      if (data['sobrantes'] is Map) {
        (data['sobrantes'] as Map).forEach((k, v) {
          final sku = k.toString();
          final docCount =
              v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
          _serverSobrantesBySku[sku] = docCount;
          _appliedInprogressSobrantes[sku] = docCount;
        });
      }
      // contributors info
      // contributors are optional metadata; no direct action here
      _recalcTotals();
    });
  }

  Future<void> _combineSelectedSessions() async {
    if (_selectedSessionDocIds.isEmpty || _selectedJefe == null) return;
    try {
      // read all selected sessions
      final coll =
          FirebaseFirestore.instance.collection('inventarios_inprogress');
      final mergedSkus = <String, Map<String, dynamic>>{};
      final mergedSobrantes = <String, int>{};
      final contributors = <String, dynamic>{};

      for (final docId in _selectedSessionDocIds) {
        final docRef = coll.doc(docId);
        final snap = await docRef.get();
        if (!snap.exists) continue;
        final data = snap.data() ?? {};
        if (data['skus'] is Map) {
          (data['skus'] as Map).forEach((k, v) {
            final key = k.toString();
            final pdis = v is Map && v['pdis'] is num
                ? (v['pdis'] as num).toDouble()
                : (_pdisBySku[key] ?? 0.0);
            final scanned = v is Map && v['scanned'] is num
                ? (v['scanned'] as num).toInt()
                : 0;
            final prev = mergedSkus[key];
            final prevScanned = prev != null && prev['scanned'] is int
                ? prev['scanned'] as int
                : 0;
            mergedSkus[key] = {'pdis': pdis, 'scanned': prevScanned + scanned};
          });
        }
        if (data['sobrantes'] is Map) {
          (data['sobrantes'] as Map).forEach((k, v) {
            final key = k.toString();
            final cnt = v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
            mergedSobrantes[key] = (mergedSobrantes[key] ?? 0) + cnt;
          });
        }
        if (data['contributors'] is Map) {
          contributors.addAll(Map<String, dynamic>.from(data['contributors']));
        }
      }

      // Also include local pending counts (only increments not yet applied to server)
      _scannedBySku.forEach((k, v) {
        final applied = _appliedInprogressScanned[k] ?? 0;
        final pending = v - applied;
        if (pending <= 0) return;
        final prev = mergedSkus[k];
        final prevScanned =
            prev != null && prev['scanned'] is int ? prev['scanned'] as int : 0;
        mergedSkus[k] = {
          'pdis': (_pdisBySku[k] ?? 0.0),
          'scanned': prevScanned + pending
        };
      });
      _sobrantesBySku.forEach((k, v) {
        final applied = _appliedInprogressSobrantes[k] ?? 0;
        final pending = v - applied;
        if (pending <= 0) return;
        mergedSobrantes[k] = (mergedSobrantes[k] ?? 0) + pending;
      });

      contributors[widget.usuario] = FieldValue.serverTimestamp();

      // compute totals
      final totalPdis = _pdisBySku.values.fold(0.0, (s, v) => s + v).round();
      final totalScanned = mergedSkus.values.fold<int>(0, (s, e) {
        final scanned = e['scanned'] is int
            ? e['scanned'] as int
            : (e['scanned'] is num ? (e['scanned'] as num).toInt() : 0);
        return s + scanned;
      });

      final histRef =
          FirebaseFirestore.instance.collection('inventarios_historico').doc();

      // ensure historico `skus` contains all plantilla SKUs (scanned 0 if missing)
      final fullSkus = <String, Map<String, Object>>{};
      for (final sku in _pdisBySku.keys) {
        final pdis = _pdisBySku[sku] ?? 0.0;
        final scannedVal =
            mergedSkus.containsKey(sku) && mergedSkus[sku]?['scanned'] != null
                ? (mergedSkus[sku]!['scanned'] is int
                    ? mergedSkus[sku]!['scanned'] as int
                    : (mergedSkus[sku]!['scanned'] is num
                        ? (mergedSkus[sku]!['scanned'] as num).toInt()
                        : 0))
                : 0;
        fullSkus[sku] = {'pdis': pdis, 'scanned': scannedVal};
      }
      // also include any mergedSkus not in plantilla
      mergedSkus.forEach((k, v) {
        if (!fullSkus.containsKey(k)) {
          final scannedVal = v['scanned'] is int
              ? v['scanned'] as int
              : (v['scanned'] is num ? (v['scanned'] as num).toInt() : 0);
          final pdis = v['pdis'] is num ? (v['pdis'] as num).toDouble() : 0.0;
          fullSkus[k] = {'pdis': pdis, 'scanned': scannedVal};
        }
      });

      final histPayload = {
        'usuario': widget.usuario,
        'jefe': _selectedJefe,
        'createdAt': FieldValue.serverTimestamp(),
        'totalPdis': totalPdis,
        'totalScanned': totalScanned,
        'percentScanned': totalPdis > 0 ? (totalScanned / totalPdis) : 0.0,
        'qualityScore': _computeQualityScore(),
        'q1': q1,
        'q2': q2,
        'q3': q3,
        'q4': q4,
        'skus': fullSkus,
        'sobrantes': mergedSobrantes,
        'contributors': contributors,
      };

      // batch write: set historico and delete selected sessions
      final batch = FirebaseFirestore.instance.batch();
      batch.set(histRef, histPayload);
      for (final docId in _selectedSessionDocIds) {
        final docRef = FirebaseFirestore.instance
            .collection('inventarios_inprogress')
            .doc(docId);
        batch.delete(docRef);
      }
      await batch.commit();

      setState(() {
        _selectedSessionDocIds.clear();
        _currentSessionId = null;
        _scannedBySku.clear();
        _sobrantesBySku.clear();
      });
      _fetchAvailableSessions();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sesiones combinadas y guardadas en histórico')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error combinando sesiones: $e')));
    }
  }

  Future<void> _confirmAndCombineSelectedSessions() async {
    if (_selectedSessionDocIds.isEmpty) return;
    final ids = _selectedSessionDocIds.toList();
    final count = ids.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirmar combinación'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  '¿Seguro quieres combinar $count sesión(es)?\nEsto cerrará los inventarios en los usuarios y consolidará en histórico.'),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ids
                        .map((id) =>
                            Text('- $id', style: const TextStyle(fontSize: 12)))
                        .toList(),
                  ),
                ),
              )
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Combinar'))
          ],
        );
      },
    );
    if (ok == true) await _combineSelectedSessions();
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
      _persistScanToInprogress(sku, isSobrante: false, delta: 1);
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
      _persistScanToInprogress(found, isSobrante: false, delta: 1);
      _recalcTotals();
      _scanController.clear();
      _scanFocus.requestFocus();
      return;
    }
    // No está en la plantilla del jefe: registrar como sobrante (solo en este reporte)
    _sobrantesBySku[sku] = (_sobrantesBySku[sku] ?? 0) + 1;
    _persistScanToInprogress(sku, isSobrante: true, delta: 1);
    _recalcTotals();
    _scanController.clear();
    _scanFocus.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'SKU "$sku" registrado como SOBRANTE (no se modifica OHPDIS)')));
  }

  Future<void> _persistScanToInprogress(String sku,
      {required bool isSobrante, int delta = 1}) async {
    if (_selectedJefe == null) return;
    final id = _currentSessionId != null
        ? '${_selectedJefe}_${_todayKey()}_${_currentSessionId}'
        : '${_selectedJefe}_${_todayKey()}';
    final docRef =
        FirebaseFirestore.instance.collection('inventarios_inprogress').doc(id);
    try {
      if (isSobrante) {
        await docRef.set({
          'sobrantes': {sku: FieldValue.increment(delta)},
          'contributors': {widget.usuario: FieldValue.serverTimestamp()},
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
        // reflect that we've applied this increment so snapshot doesn't add it again
        setState(() {
          _appliedInprogressSobrantes[sku] =
              (_appliedInprogressSobrantes[sku] ?? 0) + delta;
        });
      } else {
        final pdis = _pdisBySku[sku] ?? 0.0;
        await docRef.set({
          'skus': {
            sku: {'pdis': pdis, 'scanned': FieldValue.increment(delta)}
          },
          'contributors': {widget.usuario: FieldValue.serverTimestamp()},
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
        setState(() {
          _appliedInprogressScanned[sku] =
              (_appliedInprogressScanned[sku] ?? 0) + delta;
        });
      }
    } catch (e) {
      // ignore failures for now; UI keeps local state
      print('Error persisting scan to inprogress: $e');
    }
  }

  void _recalcTotals() {
    // Total scanned uses server totals when available, plus any local-only scans not yet persisted
    final serverScannedSum =
        _serverScannedBySku.values.fold(0, (s, v) => s + v);
    final localOnlyScanned = _scannedBySku.keys
        .where((k) => !_serverScannedBySku.containsKey(k))
        .map((k) => _scannedBySku[k] ?? 0)
        .fold(0, (s, v) => s + v);
    _totalScanned = serverScannedSum + localOnlyScanned;

    final serverSobrantesSum =
        _serverSobrantesBySku.values.fold(0, (s, v) => s + v);
    final localOnlySobrantes = _sobrantesBySku.keys
        .where((k) => !_serverSobrantesBySku.containsKey(k))
        .map((k) => _sobrantesBySku[k] ?? 0)
        .fold(0, (s, v) => s + v);
    _totalSobrantes = serverSobrantesSum + localOnlySobrantes;

    _totalPdis = _pdisBySku.values.fold(0.0, (s, v) => s + v).round();
    setState(() {});
  }

  double _percentScanned() {
    if (_totalPdis <= 0) return 0.0;
    return (_totalScanned / _totalPdis).clamp(0.0, 1.0);
  }

  double _computeQualityScore() {
    // Revised scoring:
    // - `percentScanned` contributes 50% of the final score.
    // - The four form questions together contribute the other 50%,
    //   each with configurable weight so each one affects the result
    //   and cannot be fully overridden by capping.
    final scannedScore = (_percentScanned() * 100).clamp(0.0, 100.0);

    // Question contributions as 0..100
    final q1Score = q1 ? 100.0 : 0.0; // Mercancía identificada (important)
    final q2Score = q2 ? 0.0 : 100.0; // Faltante primer escaneo (NO is good)
    final q3Score = q3 ? 0.0 : 100.0; // Mercancía dañada (NO is good)
    final q4Score = q4 ? 0.0 : 100.0; // En bodega (NO is good)

    // Weights for questions (sum to 1.0)
    const w1 = 0.20; // q1 weight
    const w2 = 0.40; // q2 weight (bigger impact)
    const w3 = 0.25; // q3 weight
    const w4 = 0.15; // q4 weight

    final questionsScore =
        (q1Score * w1) + (q2Score * w2) + (q3Score * w3) + (q4Score * w4);

    // Final: 50% scanned, 50% questions
    final finalScore =
        ((scannedScore * 0.5) + (questionsScore * 0.5)).clamp(0.0, 100.0);
    return finalScore;
  }

  Future<void> _finishInventory() async {
    final pct = _percentScanned();
    final quality = _computeQualityScore();

    final choice = await showDialog<String?>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Resultado Inventario'),
            content: SizedBox(
              width: 420,
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
                  const SizedBox(height: 12),
                  const Text('¿Eres el último revisor para esta jefatura hoy?'),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'pasar'),
                  child: const Text('No, pasar al siguiente')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'cerrar'),
                  child: const Text('Sí, guardar en histórico')),
            ],
          );
        });

    if (choice == null) return;

    // build payload pieces: only include pending local increments that haven't been applied to server
    final skusPayload = <String, Map<String, Object>>{};
    for (final k in _pdisBySku.keys) {
      final pdis = _pdisBySku[k] ?? 0.0;
      final local = _scannedBySku[k] ?? 0;
      final applied = _appliedInprogressScanned[k] ?? 0;
      final pending = (local - applied) > 0 ? (local - applied) : 0;
      skusPayload[k] = {'pdis': pdis, 'scanned': pending};
    }
    // also include any local-only SKUs not present in plantilla
    for (final k in _scannedBySku.keys) {
      if (!skusPayload.containsKey(k)) {
        final local = _scannedBySku[k] ?? 0;
        final applied = _appliedInprogressScanned[k] ?? 0;
        final pending = (local - applied) > 0 ? (local - applied) : 0;
        skusPayload[k] = {'pdis': (_pdisBySku[k] ?? 0.0), 'scanned': pending};
      }
    }

    if (choice == 'pasar') {
      // save/update inprogress doc so next user picks it up
      final id = _currentSessionId != null
          ? '${_selectedJefe}_${_todayKey()}_${_currentSessionId}'
          : '${_selectedJefe}_${_todayKey()}';
      final docRef = FirebaseFirestore.instance
          .collection('inventarios_inprogress')
          .doc(id);
      try {
        // Since scans are persisted in real-time, avoid re-adding counts here.
        // Just mark the current user as contributor and update timestamp so next user can pick up.
        await docRef.set({
          'contributors': {widget.usuario: FieldValue.serverTimestamp()},
          'status': 'open',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Inventario guardado como borrador para siguiente revisor')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error guardando borrador: $e')));
      }
      return;
    }

    // choice == 'cerrar' -> final user: save to historico and remove inprogress
    try {
      // When closing, prefer to consolidate the session document (all contributors)
      final id = _currentSessionId != null
          ? '${_selectedJefe}_${_todayKey()}_${_currentSessionId}'
          : '${_selectedJefe}_${_todayKey()}';
      final inDocRef = FirebaseFirestore.instance
          .collection('inventarios_inprogress')
          .doc(id);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final inSnap = await tx.get(inDocRef);

        // start from in-doc data if present
        final Map<String, dynamic> mergedSkus = {};
        final Map<String, int> mergedSobrantes = {};
        final Map<String, dynamic> contributors = {};

        if (inSnap.exists && inSnap.data() != null) {
          final data = inSnap.data()!;
          if (data['skus'] is Map) {
            (data['skus'] as Map).forEach((k, v) {
              final key = k.toString();
              if (v is Map) {
                final pdis =
                    v['pdis'] is num ? (v['pdis'] as num).toDouble() : 0.0;
                final scanned =
                    v['scanned'] is num ? (v['scanned'] as num).toInt() : 0;
                mergedSkus[key] = {'pdis': pdis, 'scanned': scanned};
              }
            });
          }
          if (data['sobrantes'] is Map) {
            (data['sobrantes'] as Map).forEach((k, v) {
              final key = k.toString();
              final cnt =
                  v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
              mergedSobrantes[key] = (mergedSobrantes[key] ?? 0) + cnt;
            });
          }
          if (data['contributors'] is Map) {
            contributors
                .addAll(Map<String, dynamic>.from(data['contributors']));
          }
        }

        // merge any local skus that may not be pushed yet
        skusPayload.forEach((k, v) {
          final prev = mergedSkus[k];
          final prevScanned = (prev is Map && prev['scanned'] != null)
              ? (prev['scanned'] as int)
              : 0;
          final prevPdis = (prev is Map && prev['pdis'] != null)
              ? (prev['pdis'] as num).toDouble()
              : (_pdisBySku[k] ?? 0.0);
          final newScanned = prevScanned + (v['scanned'] as int);
          mergedSkus[k] = {'pdis': prevPdis, 'scanned': newScanned};
        });

        _sobrantesBySku.forEach((k, v) {
          final applied = _appliedInprogressSobrantes[k] ?? 0;
          final pending = v - applied;
          if (pending <= 0) return;
          mergedSobrantes[k] = (mergedSobrantes[k] ?? 0) + pending;
        });

        contributors[widget.usuario] = FieldValue.serverTimestamp();

        // compute totals from merged data
        final totalPdis = _pdisBySku.values.fold(0.0, (s, v) => s + v).round();
        final totalScanned = mergedSkus.values.fold<int>(0, (s, e) {
          final scanned = e['scanned'] is int
              ? e['scanned'] as int
              : (e['scanned'] is num ? (e['scanned'] as num).toInt() : 0);
          return s + scanned;
        });

        final histRef = FirebaseFirestore.instance
            .collection('inventarios_historico')
            .doc();
        // ensure historico `skus` contains all plantilla SKUs (scanned 0 if missing)
        final fullSkus = <String, Map<String, Object>>{};
        for (final sku in _pdisBySku.keys) {
          final pdis = _pdisBySku[sku] ?? 0.0;
          final scannedVal =
              mergedSkus.containsKey(sku) && mergedSkus[sku]?['scanned'] != null
                  ? (mergedSkus[sku]!['scanned'] is int
                      ? mergedSkus[sku]!['scanned'] as int
                      : (mergedSkus[sku]!['scanned'] is num
                          ? (mergedSkus[sku]!['scanned'] as num).toInt()
                          : 0))
                  : 0;
          fullSkus[sku] = {'pdis': pdis, 'scanned': scannedVal};
        }
        // also include any mergedSkus not in plantilla
        mergedSkus.forEach((k, v) {
          if (!fullSkus.containsKey(k)) {
            final scannedVal = v['scanned'] is int
                ? v['scanned'] as int
                : (v['scanned'] is num ? (v['scanned'] as num).toInt() : 0);
            final pdis = v['pdis'] is num ? (v['pdis'] as num).toDouble() : 0.0;
            fullSkus[k] = {'pdis': pdis, 'scanned': scannedVal};
          }
        });

        final histPayload = {
          'usuario': widget.usuario,
          'jefe': _selectedJefe,
          'createdAt': FieldValue.serverTimestamp(),
          'totalPdis': totalPdis,
          'totalScanned': totalScanned,
          'percentScanned': totalPdis > 0 ? (totalScanned / totalPdis) : 0.0,
          'qualityScore': _computeQualityScore(),
          'q1': q1,
          'q2': q2,
          'q3': q3,
          'q4': q4,
          'skus': fullSkus,
          'sobrantes': mergedSobrantes,
          'contributors': contributors,
        };

        tx.set(histRef, histPayload);

        // delete session doc (cleanup)
        if (inSnap.exists) tx.delete(inDocRef);
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventario guardado en histórico')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando histórico: $e')));
    }
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
    sheet.appendRow(['SKU', 'PDIS', 'Escaneado', 'Faltante', 'Tipo']);

    // primero los SKUs de la plantilla
    for (final sku in _pdisBySku.keys) {
      final pdis = _pdisBySku[sku] ?? 0.0;
      final local = _scannedBySku[sku] ?? 0;
      final server = _serverScannedBySku[sku] ?? 0;
      final scanned = server > 0 ? server : local;
      final faltante =
          (pdis.round() - scanned) > 0 ? (pdis.round() - scanned) : 0;
      sheet.appendRow([sku, pdis.toStringAsFixed(0), scanned, faltante, '']);
    }
    // luego los sobrantes detectados al escanear (incluye server/local)
    final sobranteKeys = <String>{}
      ..addAll(_sobrantesBySku.keys)
      ..addAll(_serverSobrantesBySku.keys);
    for (final sku in sobranteKeys) {
      if (_pdisBySku.containsKey(sku)) continue;
      final local = _sobrantesBySku[sku] ?? 0;
      final server = _serverSobrantesBySku[sku] ?? 0;
      final scanned = server > 0 ? server : local;
      sheet.appendRow([sku, '0', scanned, 0, 'SOBRANTE']);
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
      final local = _scannedBySku[sku] ?? 0;
      final server = _serverScannedBySku[sku] ?? 0;
      final scanned = server > 0 ? server : local;
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
    _historicSub?.cancel();
    _inprogressSub?.cancel();
    _sessionsListSub?.cancel();
    super.dispose();
  }

  DataCell _buildOtherScansCell(String sku, {required bool isSobrante}) {
    final others = _scansFromOthers[sku];
    if (others == null || others.isEmpty) {
      return DataCell(Text(isSobrante ? 'SOBRANTE' : ''));
    }
    final entries =
        others.entries.map((e) => '${e.key}(${e.value})').join(', ');
    return DataCell(Row(children: [
      Expanded(
          child: Text('Escaneada por: $entries',
              style: const TextStyle(fontSize: 12))),
      TextButton(
          onPressed: () => _onAddOneFromOthers(sku, isSobrante: isSobrante),
          child: const Text('Agregar'))
    ]));
  }

  Future<void> _onAddOneFromOthers(String sku,
      {required bool isSobrante}) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Confirmar'),
              content: Text('Deseas agregar una más para SKU "$sku"?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sí'))
              ],
            ));
    if (ok != true) return;
    setState(() {
      if (isSobrante) {
        _sobrantesBySku[sku] = (_sobrantesBySku[sku] ?? 0) + 1;
      } else {
        _scannedBySku[sku] = (_scannedBySku[sku] ?? 0) + 1;
      }
      _recalcTotals();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Se agregó una unidad a $sku')));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
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
                          child: const Text('Reiniciar')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _exportToExcel,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white),
                          child: const Text('Exportar Excel'))
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedJefe != null && !isMobile)
                    Card(
                        color: Colors.white,
                        elevation: 1,
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Text('Sesión:'),
                                    const SizedBox(width: 8),
                                    Text(_currentSessionId ?? 'ninguna',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      tooltip: 'Copiar sessionId',
                                      onPressed: _currentSessionId == null
                                          ? null
                                          : () {
                                              final docId =
                                                  '${_selectedJefe}_${_todayKey()}_${_currentSessionId}';
                                              _copyToClipboard(docId);
                                            },
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                        onPressed: _createSession,
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white),
                                        child: const Text('Crear sesión')),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                        onPressed: _fetchAvailableSessions,
                                        child:
                                            const Text('Refrescar sesiones')),
                                  ]),
                                  const SizedBox(height: 8),
                                  if (_availableSessions.isNotEmpty)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ..._availableSessions.map((s) {
                                          final docId =
                                              s['docId']?.toString() ?? '';
                                          final sessId =
                                              s['sessionId']?.toString() ??
                                                  docId;
                                          final contributors =
                                              s['contributors'] is Map
                                                  ? Map<String, dynamic>.from(
                                                      s['contributors'])
                                                  : <String, dynamic>{};
                                          return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              child: Row(
                                                children: [
                                                  Checkbox(
                                                      value:
                                                          _selectedSessionDocIds
                                                              .contains(docId),
                                                      onChanged: (v) {
                                                        setState(() {
                                                          if (v == true)
                                                            _selectedSessionDocIds
                                                                .add(docId);
                                                          else
                                                            _selectedSessionDocIds
                                                                .remove(docId);
                                                        });
                                                      }),
                                                  Expanded(
                                                      child: Text(
                                                          'Sesion: $sessId')),
                                                  Text(
                                                      'contrib: ${contributors.length}'),
                                                  const SizedBox(width: 8),
                                                  OutlinedButton(
                                                      onPressed: () =>
                                                          _joinSession(sessId),
                                                      child:
                                                          const Text('Unirse')),
                                                  const SizedBox(width: 6),
                                                  IconButton(
                                                    icon: const Icon(Icons.copy,
                                                        size: 18),
                                                    tooltip: 'Copiar sessionId',
                                                    onPressed: () {
                                                      _copyToClipboard(docId);
                                                    },
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // show close button if user is creator or contributor
                                                  if (contributors.containsKey(
                                                          widget.usuario) ||
                                                      (s['createdBy']
                                                                  ?.toString() ??
                                                              '') ==
                                                          widget.usuario)
                                                    OutlinedButton(
                                                      onPressed: () =>
                                                          _closeSession(docId),
                                                      child:
                                                          const Text('Cerrar'),
                                                    )
                                                ],
                                              ));
                                        }).toList(),
                                        const SizedBox(height: 8),
                                        if (_selectedSessionDocIds.isNotEmpty)
                                          ElevatedButton(
                                              onPressed:
                                                  _confirmAndCombineSelectedSessions,
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.black,
                                                  foregroundColor:
                                                      Colors.white),
                                              child: const Text(
                                                  'Combinar sesiones seleccionadas'))
                                      ],
                                    )
                                  else
                                    const Text('No hay sesiones abiertas')
                                ]))),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    if (_selectedJefe == null) {
                      return const Center(
                          child: Text(
                              'Seleccione una jefatura para cargar inventario',
                              style: TextStyle(color: Colors.black)));
                    }
                    // Desktop / Tablet: keep existing spacious layout
                    if (!isMobile) {
                      return Expanded(
                          child: SingleChildScrollView(
                              child: Column(children: [
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
                                    // Build combined rows: plantilla SKUs first (sorted by falta), then sobrantes
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

                                    final rows = <DataRow>[];
                                    for (final sku in pdisKeys) {
                                      final pdis = _pdisBySku[sku] ?? 0.0;
                                      final local = _scannedBySku[sku] ?? 0;
                                      final server =
                                          _serverScannedBySku[sku] ?? 0;
                                      final total = server > 0 ? server : local;
                                      final display = server > 0 && local > 0
                                          ? '$total (tú:$local)'
                                          : '$total';
                                      rows.add(DataRow(cells: [
                                        DataCell(Text(sku)),
                                        DataCell(Text(pdis.toStringAsFixed(0))),
                                        DataCell(Text(display,
                                            style: TextStyle(
                                                color: total == 0
                                                    ? Colors.red
                                                    : Colors.black))),
                                        _buildOtherScansCell(sku,
                                            isSobrante: false),
                                      ]));
                                    }
                                    for (final sku in sobranteKeys) {
                                      final local = _sobrantesBySku[sku] ?? 0;
                                      final server =
                                          _serverSobrantesBySku[sku] ?? 0;
                                      final total = server > 0 ? server : local;
                                      final display = server > 0 && local > 0
                                          ? '$total (tú:$local)'
                                          : '$total';
                                      rows.add(DataRow(cells: [
                                        DataCell(Text('$sku')),
                                        const DataCell(Text('0')),
                                        DataCell(Text(display,
                                            style: TextStyle(
                                                color: total == 0
                                                    ? Colors.red
                                                    : Colors.black))),
                                        _buildOtherScansCell(sku,
                                            isSobrante: true),
                                      ]));
                                    }

                                    return SingleChildScrollView(
                                        // vertical scroll
                                        child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    minWidth:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width),
                                                child:
                                                    DataTable(columns: const [
                                                  DataColumn(
                                                      label: Text('SKU')),
                                                  DataColumn(
                                                      label: Text('PDIS'),
                                                      numeric: true),
                                                  DataColumn(
                                                      label: Text('Escaneado'),
                                                      numeric: true),
                                                  DataColumn(
                                                      label: Text('Tipo')),
                                                ], rows: rows))));
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
                      ])));
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
                                  // Mobile: session controls
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(
                                                'Sesión: ${_currentSessionId ?? 'ninguna'}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black))),
                                        IconButton(
                                            icon: const Icon(Icons.copy,
                                                size: 18),
                                            tooltip: 'Copiar sessionId',
                                            onPressed: _currentSessionId == null
                                                ? null
                                                : () {
                                                    final docId =
                                                        '${_selectedJefe}_${_todayKey()}_${_currentSessionId}';
                                                    _copyToClipboard(docId);
                                                  }),
                                        ElevatedButton(
                                            onPressed: _createSession,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.black,
                                                foregroundColor: Colors.white),
                                            child: const Text('Crear')),
                                        const SizedBox(width: 6),
                                        OutlinedButton(
                                            onPressed: _fetchAvailableSessions,
                                            child: const Text('Refrescar'))
                                      ]),
                                      const SizedBox(height: 8),
                                      if (_availableSessions.isNotEmpty)
                                        Column(
                                          children: _availableSessions.map((s) {
                                            final docId =
                                                s['docId']?.toString() ?? '';
                                            final sessId =
                                                s['sessionId']?.toString() ??
                                                    docId;
                                            final contributors =
                                                s['contributors'] is Map
                                                    ? Map<String, dynamic>.from(
                                                        s['contributors'])
                                                    : <String, dynamic>{};
                                            final createdBy =
                                                s['createdBy']?.toString() ??
                                                    '';
                                            return Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 6),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: Row(
                                                  children: [
                                                    Checkbox(
                                                      value:
                                                          _selectedSessionDocIds
                                                              .contains(docId),
                                                      onChanged: (v) {
                                                        setState(() {
                                                          if (v == true)
                                                            _selectedSessionDocIds
                                                                .add(docId);
                                                          else
                                                            _selectedSessionDocIds
                                                                .remove(docId);
                                                        });
                                                      },
                                                    ),
                                                    Expanded(
                                                        child: Text(
                                                            'ID: $sessId',
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        13))),
                                                    Text(
                                                        'c: ${contributors.length}',
                                                        style: const TextStyle(
                                                            fontSize: 12)),
                                                    const SizedBox(width: 6),
                                                    OutlinedButton(
                                                        onPressed: () =>
                                                            _joinSession(
                                                                sessId),
                                                        child: const Text(
                                                            'Unirse')),
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                        icon: const Icon(
                                                            Icons.copy,
                                                            size: 18),
                                                        onPressed: () =>
                                                            _copyToClipboard(
                                                                docId)),
                                                    if (contributors
                                                            .containsKey(widget
                                                                .usuario) ||
                                                        createdBy ==
                                                            widget.usuario)
                                                      const SizedBox(width: 4),
                                                    if (contributors
                                                            .containsKey(widget
                                                                .usuario) ||
                                                        createdBy ==
                                                            widget.usuario)
                                                      OutlinedButton(
                                                          onPressed: () =>
                                                              _closeSession(
                                                                  docId),
                                                          child: const Text(
                                                              'Cerrar'))
                                                  ],
                                                ));
                                          }).toList(),
                                        )
                                      else
                                        const Text('No hay sesiones abiertas',
                                            style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 8),
                                      if (_selectedSessionDocIds.isNotEmpty)
                                        ElevatedButton(
                                            onPressed:
                                                _confirmAndCombineSelectedSessions,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.black,
                                                foregroundColor: Colors.white),
                                            child: const Text(
                                                'Combinar sesiones seleccionadas')),
                                    ],
                                  ),
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

                                      final rows = <DataRow>[];
                                      for (final sku in pdisKeys) {
                                        final pdis = _pdisBySku[sku] ?? 0.0;
                                        final scanned = _scannedBySku[sku] ?? 0;
                                        rows.add(DataRow(cells: [
                                          DataCell(Text(sku)),
                                          DataCell(
                                              Text(pdis.toStringAsFixed(0))),
                                          DataCell(Text(scanned.toString(),
                                              style: TextStyle(
                                                  color: scanned == 0
                                                      ? Colors.red
                                                      : Colors.black))),
                                          _buildOtherScansCell(sku,
                                              isSobrante: false),
                                        ]));
                                      }
                                      for (final sku in sobranteKeys) {
                                        final scanned =
                                            _sobrantesBySku[sku] ?? 0;
                                        rows.add(DataRow(cells: [
                                          DataCell(Text('$sku')),
                                          const DataCell(Text('0')),
                                          DataCell(Text(scanned.toString(),
                                              style: TextStyle(
                                                  color: scanned == 0
                                                      ? Colors.red
                                                      : Colors.black))),
                                          _buildOtherScansCell(sku,
                                              isSobrante: true),
                                        ]));
                                      }

                                      return SingleChildScrollView(
                                          // vertical scroll wrapper
                                          child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                      minWidth:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width -
                                                              48),
                                                  child:
                                                      DataTable(columns: const [
                                                    DataColumn(
                                                        label: Text('SKU')),
                                                    DataColumn(
                                                        label: Text('PDIS'),
                                                        numeric: true),
                                                    DataColumn(
                                                        label:
                                                            Text('Escaneado'),
                                                        numeric: true),
                                                    DataColumn(
                                                        label: Text('Tipo')),
                                                  ], rows: rows))));
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
