import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MetricasCaminatasPage extends StatefulWidget {
  @override
  State<MetricasCaminatasPage> createState() => _MetricasCaminatasPageState();
}

class _MetricasCaminatasPageState extends State<MetricasCaminatasPage> {
  final List<String> _jefes = [];
  final Map<String, String> _seccionToJefe = {};

  String? _selectedJefe;
  final List<DateTime> _months = [];
  DateTime? _monthA;
  DateTime? _monthB;
  _MonthStats? _statsA;
  _MonthStats? _statsB;
  Map<String, double> _avgAByJefe = {};
  Map<String, double> _avgBByJefe = {};
  Map<String, int> _evalAByJefe = {};
  Map<String, int> _evalBByJefe = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prepareMonths();
    _loadPlantillaJefes();
  }

  void _prepareMonths() {
    final now = DateTime.now();
    for (var i = 0; i < 12; i++) {
      _months.add(DateTime(now.year, now.month - i, 1));
    }
    _monthA = _months.isNotEmpty ? _months.first : null;
    _monthB = _months.length > 1 ? _months[1] : _monthA;
  }

  String _norm(String value) => value.trim().toUpperCase();

  DateTime? _extractFecha(Map<String, dynamic> data) {
    final dateVal = data['date'];
    if (dateVal is Timestamp) return dateVal.toDate();

    final createdAtVal = data['createdAt'];
    if (createdAtVal is Timestamp) return createdAtVal.toDate();

    if (dateVal is String) {
      try {
        return DateTime.parse(dateVal);
      } catch (_) {}
    }
    return null;
  }

  String _resolverJefe(Map<String, dynamic> data) {
    final seccion = (data['seccion'] ?? data['SECCION'] ?? '').toString();
    final jefePorSeccion = _seccionToJefe[_norm(seccion)] ?? '';
    if (jefePorSeccion.isNotEmpty) return jefePorSeccion;
    return (data['jefe'] ?? '').toString().trim();
  }

  double? _extractScore(Map<String, dynamic> data) {
    final raw = data['score'];
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      var s = raw.trim();
      if (s.isEmpty) return null;
      if (s.endsWith('%')) s = s.substring(0, s.length - 1);
      return double.tryParse(s);
    }
    return null;
  }

  Future<void> _loadPlantillaJefes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();

      final raw = snap.data()?['datos'];
      if (raw is! List) return;

      final jefesSet = <String>{};
      for (final row in raw) {
        if (row is! Map) continue;
        final seccion = (row['SECCION'] ?? '').toString().trim();
        final jefe = (row['NOMBRE'] ?? '').toString().trim();
        if (seccion.isEmpty || jefe.isEmpty) continue;

        _seccionToJefe[_norm(seccion)] = jefe;
        jefesSet.add(jefe);
      }

      setState(() {
        _jefes
          ..clear()
          ..addAll(jefesSet.toList()..sort());
        if (_jefes.isNotEmpty && _selectedJefe == null) {
          _selectedJefe = _jefes.first;
        }
      });

      if (_selectedJefe != null) {
        await _loadMetrics();
      }
    } catch (e) {
      debugPrint('Error cargando jefes desde plantilla ejecutiva: $e');
    }
  }

  Future<_MonthDistribution> _fetchMonthDistribution(DateTime start) async {
    final end = DateTime(start.year, start.month + 1, 1);

    try {
      final byDate = await FirebaseFirestore.instance
          .collection('caminatas')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      final byCreatedAt = await FirebaseFirestore.instance
          .collection('caminatas')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .get();

      final merged = <String, Map<String, dynamic>>{};
      for (final d in byDate.docs) {
        merged[d.id] = d.data();
      }
      for (final d in byCreatedAt.docs) {
        merged[d.id] = d.data();
      }

      final aggByJefe = <String, _Agg>{};

      for (final data in merged.values) {
        final fecha = _extractFecha(data);
        if (fecha == null) continue;
        if (fecha.isBefore(start) || !fecha.isBefore(end)) continue;

        final jefe = _resolverJefe(data);
        if (jefe.isEmpty) continue;
        final score = _extractScore(data);
        if (score == null) continue;

        final agg = aggByJefe.putIfAbsent(jefe, () => _Agg());
        agg.sum += score;
        agg.count += 1;
      }

      final avgByJefe = <String, double>{};
      final evalByJefe = <String, int>{};
      aggByJefe.forEach((jefe, agg) {
        if (agg.count > 0) {
          avgByJefe[jefe] = agg.sum / agg.count;
          evalByJefe[jefe] = agg.count;
        }
      });

      return _MonthDistribution(avgByJefe: avgByJefe, evalByJefe: evalByJefe);
    } catch (e) {
      debugPrint('Error calculando métricas: $e');
      return const _MonthDistribution(avgByJefe: {}, evalByJefe: {});
    }
  }

  void _refreshSelectedStats() {
    final jefe = _selectedJefe;
    if (jefe == null) {
      _statsA = null;
      _statsB = null;
      return;
    }

    _statsA = _MonthStats(
      promedio: _avgAByJefe[jefe],
      evaluaciones: _evalAByJefe[jefe] ?? 0,
    );
    _statsB = _MonthStats(
      promedio: _avgBByJefe[jefe],
      evaluaciones: _evalBByJefe[jefe] ?? 0,
    );
  }

  Future<void> _loadMetrics() async {
    if (_selectedJefe == null || _monthA == null || _monthB == null) return;

    setState(() => _loading = true);
    final distA = await _fetchMonthDistribution(_monthA!);
    final distB = await _fetchMonthDistribution(_monthB!);

    if (!mounted) return;
    setState(() {
      _avgAByJefe = distA.avgByJefe;
      _avgBByJefe = distB.avgByJefe;
      _evalAByJefe = distA.evalByJefe;
      _evalBByJefe = distB.evalByJefe;
      _refreshSelectedStats();
      _loading = false;
    });
  }

  String _monthLabel(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    return '${dt.year}-$m';
  }

  Color _colorFor(double value) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  String _trendLabel(double delta) {
    if (delta > 0.05) return 'Subió';
    if (delta < -0.05) return 'Bajó';
    return 'Igual';
  }

  IconData _trendIcon(double delta) {
    if (delta > 0.05) return Icons.arrow_upward;
    if (delta < -0.05) return Icons.arrow_downward;
    return Icons.remove;
  }

  Color _trendColor(double delta) {
    if (delta > 0.05) return Colors.green;
    if (delta < -0.05) return Colors.red;
    return Colors.grey;
  }

  Widget _trendBadge(double delta, {bool compact = false}) {
    final color = _trendColor(delta);
    final icon = _trendIcon(delta);
    final label = _trendLabel(delta);
    final deltaText = '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 14 : 16),
          const SizedBox(width: 4),
          Text(
            '$label $deltaText',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Métricas Caminatas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Jefatura',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedJefe,
              hint: const Text('Selecciona jefatura'),
              items: _jefes
                  .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedJefe = v;
                  _refreshSelectedStats();
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
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
                                  value: m,
                                  child: Text(_monthLabel(m)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _monthA = v);
                          _loadMetrics();
                        },
                      ),
                    ],
                  ),
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
                                  value: m,
                                  child: Text(_monthLabel(m)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _monthB = v);
                          _loadMetrics();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading) ...[
              const Text(
                'Comparativa (promedio de evaluación)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _metricRow('Mes A', _monthA, _statsA),
              const SizedBox(height: 8),
              _metricRow('Mes B', _monthB, _statsB),
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final a = _statsA?.promedio ?? 0.0;
                final b = _statsB?.promedio ?? 0.0;
                final delta = a - b;

                return Row(
                  children: [
                    const Expanded(
                      child: Text('Variación (A − B), puntos porcentuales'),
                    ),
                    _trendBadge(delta),
                  ],
                );
              }),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              const Text(
                'Ranking de jefes por mes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildRankingTable(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, DateTime? month, _MonthStats? stats) {
    final pct = stats?.promedio ?? 0.0;
    final color = _colorFor(pct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${label} ${month != null ? _monthLabel(month) : ''}'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade200,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stats != null
                  ? '${stats.promedio?.toStringAsFixed(1) ?? '—'}% (${stats.evaluaciones} eval.)'
                  : '—',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRankingTable() {
    final allJefes = <String>{
      ..._jefes,
      ..._avgAByJefe.keys,
      ..._avgBByJefe.keys,
    }.toList()
      ..sort((a, b) {
        final avgA = _avgAByJefe[a] ?? 0;
        final avgB = _avgAByJefe[b] ?? 0;
        return avgB.compareTo(avgA);
      });

    if (allJefes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No hay datos para mostrar ranking.'),
      );
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('Jefe')),
        DataColumn(label: Text('Mes A')),
        DataColumn(label: Text('Mes B')),
        DataColumn(label: Text('Δ')),
      ],
      rows: allJefes.map((jefe) {
        final avgA = _avgAByJefe[jefe];
        final avgB = _avgBByJefe[jefe];
        final evaA = _evalAByJefe[jefe] ?? 0;
        final evaB = _evalBByJefe[jefe] ?? 0;
        final delta = (avgA ?? 0) - (avgB ?? 0);

        return DataRow(cells: [
          DataCell(Text(jefe)),
          DataCell(Text(
              '${avgA?.toStringAsFixed(1) ?? '—'}% (${evaA.toString()} eval.)')),
          DataCell(Text(
              '${avgB?.toStringAsFixed(1) ?? '—'}% (${evaB.toString()} eval.)')),
          DataCell(_trendBadge(delta, compact: true)),
        ]);
      }).toList(),
    );
  }
}

class _MonthStats {
  final double? promedio;
  final int evaluaciones;

  const _MonthStats({required this.promedio, required this.evaluaciones});
}

class _MonthDistribution {
  final Map<String, double> avgByJefe;
  final Map<String, int> evalByJefe;

  const _MonthDistribution({required this.avgByJefe, required this.evalByJefe});
}

class _Agg {
  double sum = 0;
  int count = 0;
}
