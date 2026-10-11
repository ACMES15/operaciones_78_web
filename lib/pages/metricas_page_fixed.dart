import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MetricasPageFixed extends StatefulWidget {
  const MetricasPageFixed({Key? key}) : super(key: key);

  @override
  State<MetricasPageFixed> createState() => _MetricasPageFixedState();
}

class _MetricasPageFixedState extends State<MetricasPageFixed> {
  String? _selectedMonth;
  String? _compareMonthA;
  String? _compareMonthB;
  String _monthKeyFromTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  }

  double _normalizePercent(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) {
      final d = v.toDouble();
      if (d > 1.5) return d.clamp(0.0, 100.0);
      return (d <= 1.0) ? (d * 100.0) : d;
    }
    return 0.0;
  }

  Widget _buildMonthMetric(
      String jefe, List<Map<String, dynamic>> records, Color accent) {
    final recs = List<Map<String, dynamic>>.from(records);
    recs.sort((a, b) {
      final ta = a['ts'] as Timestamp?;
      final tb = b['ts'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return -1;
      if (tb == null) return 1;
      return ta.compareTo(tb);
    });

    final lastPct = recs.isEmpty ? 0.0 : (recs.last['pct'] as double);

    String historyLine = '';
    String variationLine = '';
    if (recs.length > 1) {
      final values =
          recs.map((r) => (r['pct'] as double).toStringAsFixed(1)).toList();
      final penult = recs[recs.length - 2]['pct'] as double;
      final last = recs.last['pct'] as double;
      final absDiff = last - penult;
      final relPct = penult == 0.0 ? 0.0 : (absDiff / penult) * 100.0;
      final entries =
          List.generate(recs.length, (idx) => '${idx + 1}ª: ${values[idx]}%');
      historyLine = '${recs.length} E — ${entries.join('  ')}';
      variationLine =
          'Variación (penúlt→últ): ${absDiff >= 0 ? '+' : ''}${absDiff.toStringAsFixed(1)}pp (${relPct >= 0 ? '+' : ''}${relPct.toStringAsFixed(1)}%)';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(jefe,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${lastPct.toStringAsFixed(1)}%',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: accent)),
              ],
            ),
            if (historyLine.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(historyLine,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(variationLine,
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Use historico inventory docs as source of metric evaluations
        stream: FirebaseFirestore.instance
            .collection('inventarios_historico')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError)
            return const Center(child: Text('Error al cargar métricas'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final Map<String, Map<String, List<Map<String, dynamic>>>>
              aggregation = {};
          for (final doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final jefe = (data['jefe'] ?? '—').toString();
            // source stores percentScanned as 0..1 (fraction) or as 0..100
            final rawPct = data['percentScanned'];
            double pct;
            if (rawPct is num) {
              pct = rawPct.toDouble();
              if (pct <= 1.0) pct = pct * 100.0;
            } else {
              pct = 0.0;
            }
            final ts = data['createdAt'] as Timestamp?;
            final month = _monthKeyFromTimestamp(ts);
            if (month.isEmpty) continue;
            aggregation.putIfAbsent(month, () => {});
            aggregation[month]!.putIfAbsent(jefe, () => []);
            aggregation[month]![jefe]!.add({'pct': pct, 'ts': ts});
          }

          final months = aggregation.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          if (months.isEmpty)
            return const Center(child: Text('No hay métricas disponibles'));

          // Ensure selection defaults
          _selectedMonth ??= months.first;

          Widget buildExecutiveHeader() {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Métricas Ejecutivas',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: Colors.pink.shade700,
                              borderRadius: BorderRadius.circular(3)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      DropdownButton<String>(
                        value: _selectedMonth,
                        items: months
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedMonth = v),
                        hint: const Text('Seleccionar mes'),
                      ),
                      const Text('Comparar:'),
                      DropdownButton<String?>(
                        value: _compareMonthA,
                        items: [null, ...months]
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(m ?? '—')))
                            .toList(),
                        onChanged: (v) => setState(() => _compareMonthA = v),
                        hint: const Text('Mes A'),
                      ),
                      DropdownButton<String?>(
                        value: _compareMonthB,
                        items: [null, ...months]
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(m ?? '—')))
                            .toList(),
                        onChanged: (v) => setState(() => _compareMonthB = v),
                        hint: const Text('Mes B'),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          _compareMonthA = null;
                          _compareMonthB = null;
                          _selectedMonth = months.first;
                        }),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink.shade700),
                        child: const Text('Reset'),
                      ),
                    ])
                  ],
                ),
              ),
            );
          }

          Widget buildComparisonView(String a, String b) {
            final mapA = aggregation[a]!;
            final mapB = aggregation[b]!;
            final allJefes = <String>{};
            allJefes.addAll(mapA.keys);
            allJefes.addAll(mapB.keys);
            final rows = allJefes.toList()..sort();
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comparación: $a vs $b',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...rows.map((j) {
                      final pctA = (mapA[j]?.last['pct'] as double?) ?? 0.0;
                      final pctB = (mapB[j]?.last['pct'] as double?) ?? 0.0;
                      final diff = (pctB - pctA);
                      final diffLabel =
                          '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}pp';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(j,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            'A: ${pctA.toStringAsFixed(1)}%  •  B: ${pctB.toStringAsFixed(1)}%'),
                        trailing: Text(diffLabel,
                            style: TextStyle(
                                color: diff >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              buildExecutiveHeader(),
              const SizedBox(height: 12),
              if (_compareMonthA != null &&
                  _compareMonthB != null &&
                  aggregation.containsKey(_compareMonthA) &&
                  aggregation.containsKey(_compareMonthB))
                buildComparisonView(_compareMonthA!, _compareMonthB!)
              else ...[
                // Show selected month executive breakdown
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(_selectedMonth ?? months.first,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18))),
                            Container(
                                width: 8,
                                height: 32,
                                color: Colors.pink.shade200),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 8),
                        ...((aggregation[_selectedMonth ?? months.first] ?? {})
                            .entries
                            .map((e) => _buildMonthMetric(
                                e.key, e.value, Colors.pink.shade700)))
                      ],
                    ),
                  ),
                ),
              ]
            ],
          );
        },
      ),
    );
  }
}
