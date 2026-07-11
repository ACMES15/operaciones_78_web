import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MetricasCaminatasPage extends StatefulWidget {
  @override
  State<MetricasCaminatasPage> createState() => _MetricasCaminatasPageState();
}

class _MetricasCaminatasPageState extends State<MetricasCaminatasPage> {
  List<String> _jefes = [];
  String? _selectedJefe;
  List<DateTime> _months = [];
  DateTime? _monthA;
  DateTime? _monthB;
  double? _avgA;
  double? _avgB;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prepareMonths();
    _loadJefes();
  }

  void _prepareMonths() {
    final now = DateTime.now();
    for (var i = 0; i < 12; i++) {
      final dt = DateTime(now.year, now.month - i, 1);
      _months.add(dt);
    }
    _monthA = _months.isNotEmpty ? _months[0] : null;
    _monthB = _months.length > 1 ? _months[1] : _monthA;
  }

  Future<void> _loadJefes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('caminatas')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();
      final set = <String>{};
      for (final d in snap.docs) {
        final jefe = (d.data()['jefe'] ?? '').toString();
        if (jefe.isNotEmpty) set.add(jefe);
      }
      setState(() {
        _jefes = set.toList()..sort();
        if (_jefes.isNotEmpty && _selectedJefe == null) {
          _selectedJefe = _jefes.first;
          _loadMetrics();
        }
      });
    } catch (e) {
      debugPrint('Error cargando jefes: $e');
    }
  }

  Future<double?> _fetchAvg(String jefe, DateTime start) async {
    final end = DateTime(start.year, start.month + 1, 1);
    try {
      // Some documents use `date`, others `createdAt`. Fetch by jefe
      // and filter in memory by either timestamp field so recent saves
      // are included regardless of which field was set.
      final snap = await FirebaseFirestore.instance
          .collection('caminatas')
          .where('jefe', isEqualTo: jefe)
          .orderBy('createdAt', descending: true)
          .limit(1000)
          .get();
      if (snap.docs.isEmpty) return null;
      double sum = 0;
      int cnt = 0;
      for (final d in snap.docs) {
        final data = d.data();
        Timestamp? ts;
        try {
          if (data['date'] is Timestamp) {
            ts = data['date'] as Timestamp;
          } else if (data['createdAt'] is Timestamp) {
            ts = data['createdAt'] as Timestamp;
          }
        } catch (_) {}

        if (ts == null) continue;
        final dt = ts.toDate();
        if (dt.isBefore(start) || !dt.isBefore(end)) continue;

        final sc = data['score'];
        if (sc is num) {
          sum += sc.toDouble();
          cnt++;
        }
      }
      if (cnt == 0) return null;
      return sum / cnt;
    } catch (e) {
      debugPrint('Error fetching avg: $e');
      return null;
    }
  }

  Future<void> _loadMetrics() async {
    if (_selectedJefe == null || _monthA == null || _monthB == null) return;
    setState(() => _loading = true);
    final a = await _fetchAvg(_selectedJefe!, _monthA!);
    final b = await _fetchAvg(_selectedJefe!, _monthB!);
    setState(() {
      _avgA = a;
      _avgB = b;
      _loading = false;
    });
  }

  String _monthLabel(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    return '${dt.year}-$m';
  }

  Color _colorFor(double? val) {
    if (val == null) return Colors.grey;
    if (val >= 80) return Colors.green;
    if (val >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Métricas Caminatas')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Jefatura', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedJefe,
            hint: const Text('Selecciona jefatura'),
            items: _jefes
                .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedJefe = v);
              _loadMetrics();
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mes A',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<DateTime>(
                        value: _monthA,
                        items: _months
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(_monthLabel(m))))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _monthA = v);
                          _loadMetrics();
                        })
                  ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mes B',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<DateTime>(
                        value: _monthB,
                        items: _months
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(_monthLabel(m))))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _monthB = v);
                          _loadMetrics();
                        })
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading) ...[
            const Text('Comparativa',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _metricRow('Mes A', _monthA, _avgA),
            const SizedBox(height: 8),
            _metricRow('Mes B', _monthB, _avgB),
            const SizedBox(height: 12),
            // Diferencia A - B
            Builder(builder: (ctx) {
              final a = _avgA ?? 0.0;
              final b = _avgB ?? 0.0;
              final delta = a - b;
              Color dColor;
              if (delta > 0)
                dColor = Colors.green;
              else if (delta < 0)
                dColor = Colors.red;
              else
                dColor = Colors.grey;
              final deltaText =
                  (delta >= 0 ? '+' : '') + '${delta.toStringAsFixed(0)}%';
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Diferencia (A − B)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Text('Cambio en puntos (A menos B)')),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: dColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(deltaText,
                              style: TextStyle(
                                  color: dColor, fontWeight: FontWeight.bold))),
                    ])
                  ]);
            }),
            const SizedBox(height: 8),
            // Cambio relativo (porcentaje)
            Builder(builder: (ctx) {
              final a = _avgA ?? 0.0;
              final b = _avgB ?? 0.0;
              String relText;
              Color relColor = Colors.grey;
              if (b == 0) {
                if (a == 0) {
                  relText = '0%';
                } else {
                  relText = '—';
                }
              } else {
                final rel = ((a - b) / b) * 100;
                relText = (rel >= 0 ? '+' : '') + '${rel.toStringAsFixed(0)}%';
                if (rel > 0)
                  relColor = Colors.green;
                else if (rel < 0) relColor = Colors.red;
              }
              return Row(children: [
                Expanded(child: Text('Cambio relativo (%)')),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: relColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(relText,
                        style: TextStyle(
                            color: relColor, fontWeight: FontWeight.bold)))
              ]);
            }),
          ]
        ]),
      ),
    );
  }

  Widget _metricRow(String label, DateTime? month, double? value) {
    final pct = value ?? 0.0;
    final color = _colorFor(value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${label} ${month != null ? _monthLabel(month) : ''}'),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
            child: Container(
          height: 18,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey.shade200),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (pct / 100).clamp(0.0, 1.0),
            child: Container(
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(6))),
          ),
        )),
        const SizedBox(width: 8),
        Text(value != null ? '${value.toStringAsFixed(0)}%' : '—',
            style: TextStyle(
                color: _colorFor(value), fontWeight: FontWeight.bold)),
      ])
    ]);
  }
}
