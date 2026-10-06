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
  Map<String, int> _countAByJefe = {};
  Map<String, int> _countBByJefe = {};
  int _totalMesA = 0;
  int _totalMesB = 0;
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

      var totalMes = 0;
      final byJefe = <String, int>{};

      for (final data in merged.values) {
        final fecha = _extractFecha(data);
        if (fecha == null) continue;
        if (fecha.isBefore(start) || !fecha.isBefore(end)) continue;

        totalMes++;
        final jefe = _resolverJefe(data);
        if (jefe.isNotEmpty) {
          byJefe[jefe] = (byJefe[jefe] ?? 0) + 1;
        }
      }

      return _MonthDistribution(totalMes: totalMes, byJefe: byJefe);
    } catch (e) {
      debugPrint('Error calculando métricas: $e');
      return const _MonthDistribution(totalMes: 0, byJefe: {});
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
      totalMes: _totalMesA,
      caminatasJefe: _countAByJefe[jefe] ?? 0,
    );
    _statsB = _MonthStats(
      totalMes: _totalMesB,
      caminatasJefe: _countBByJefe[jefe] ?? 0,
    );
  }

  Future<void> _loadMetrics() async {
    if (_selectedJefe == null || _monthA == null || _monthB == null) return;

    setState(() => _loading = true);
    final distA = await _fetchMonthDistribution(_monthA!);
    final distB = await _fetchMonthDistribution(_monthB!);

    if (!mounted) return;
    setState(() {
      _countAByJefe = distA.byJefe;
      _countBByJefe = distB.byJefe;
      _totalMesA = distA.totalMes;
      _totalMesB = distB.totalMes;
      _refreshSelectedStats();
      _loading = false;
    });
  }

  String _monthLabel(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    return '${dt.year}-$m';
  }

  Color _colorFor(double value) {
    if (value >= 30) return Colors.green;
    if (value >= 15) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Métricas Caminatas')),
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
                'Comparativa (porcentaje sobre total mensual)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _metricRow('Mes A', _monthA, _statsA),
              const SizedBox(height: 8),
              _metricRow('Mes B', _monthB, _statsB),
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final a = _statsA?.pct ?? 0.0;
                final b = _statsB?.pct ?? 0.0;
                final delta = a - b;
                final dColor = delta > 0
                    ? Colors.green
                    : (delta < 0 ? Colors.red : Colors.grey);
                final deltaText =
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%';

                return Row(
                  children: [
                    const Expanded(
                      child: Text('Diferencia (A − B), puntos porcentuales'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: dColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        deltaText,
                        style: TextStyle(
                          color: dColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
    final pct = stats?.pct ?? 0.0;
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
                  ? '${stats.caminatasJefe}/${stats.totalMes} (${stats.pct.toStringAsFixed(1)}%)'
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
      ..._countAByJefe.keys,
      ..._countBByJefe.keys,
    }.toList()
      ..sort((a, b) {
        final pctA =
            _totalMesA == 0 ? 0 : ((_countAByJefe[a] ?? 0) / _totalMesA);
        final pctB =
            _totalMesA == 0 ? 0 : ((_countAByJefe[b] ?? 0) / _totalMesA);
        return pctB.compareTo(pctA);
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
        final ca = _countAByJefe[jefe] ?? 0;
        final cb = _countBByJefe[jefe] ?? 0;
        final pa = _totalMesA == 0 ? 0 : (ca / _totalMesA) * 100;
        final pb = _totalMesB == 0 ? 0 : (cb / _totalMesB) * 100;
        final delta = pa - pb;
        final deltaColor =
            delta > 0 ? Colors.green : (delta < 0 ? Colors.red : Colors.grey);

        return DataRow(cells: [
          DataCell(Text(jefe)),
          DataCell(Text('$ca/$_totalMesA (${pa.toStringAsFixed(1)}%)')),
          DataCell(Text('$cb/$_totalMesB (${pb.toStringAsFixed(1)}%)')),
          DataCell(Text(
            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
            style: TextStyle(color: deltaColor, fontWeight: FontWeight.bold),
          )),
        ]);
      }).toList(),
    );
  }
}

class _MonthStats {
  final int totalMes;
  final int caminatasJefe;

  const _MonthStats({required this.totalMes, required this.caminatasJefe});

  double get pct => totalMes == 0 ? 0 : (caminatasJefe / totalMes) * 100;
}

class _MonthDistribution {
  final int totalMes;
  final Map<String, int> byJefe;

  const _MonthDistribution({required this.totalMes, required this.byJefe});
}
