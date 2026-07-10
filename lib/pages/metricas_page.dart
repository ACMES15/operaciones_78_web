import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MetricasPage extends StatefulWidget {
  const MetricasPage({Key? key}) : super(key: key);

  @override
  State<MetricasPage> createState() => _MetricasPageState();
}

class _MetricasPageState extends State<MetricasPage> {
  final Set<String> _selectedMonths = {}; // selected months in format YYYY-MM

  String _monthKeyFromTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  }

  double _normalizePercent(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) {
      final d = v.toDouble();
      if (d > 1.5) return d.clamp(0.0, 100.0); // already 0..100
      return (d <= 1.0) ? (d * 100.0) : d;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Métricas Mensuales',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventarios_historico')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];

          // collect available months
          final months = <String>{};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['createdAt'] is Timestamp
                ? data['createdAt'] as Timestamp
                : null;
            final key = _monthKeyFromTimestamp(ts);
            if (key.isNotEmpty) months.add(key);
          }
          final sortedMonths = months.toList()..sort((a, b) => b.compareTo(a));

          // default to latest month if nothing selected
          if (_selectedMonths.isEmpty && sortedMonths.isNotEmpty) {
            _selectedMonths.add(sortedMonths.first);
          }

          // palette for month colors
          final palette = [
            Colors.black,
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.purple,
            Colors.teal,
            Colors.red
          ];
          final selectedList = _selectedMonths.toList();
          final monthColors = <String, Color>{};
          for (var i = 0; i < selectedList.length; i++) {
            monthColors[selectedList[i]] = palette[i % palette.length];
          }

          // aggregate percent by month and jefe
          final Map<String, Map<String, List<double>>> dataByMonth = {};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['createdAt'] is Timestamp
                ? data['createdAt'] as Timestamp
                : null;
            final key = _monthKeyFromTimestamp(ts);
            if (!_selectedMonths.contains(key)) continue;
            final jefe = (data['jefe']?.toString() ?? 'Sin Jefe');
            final pct = _normalizePercent(data['percentScanned']);
            dataByMonth
                .putIfAbsent(key, () => {})
                .putIfAbsent(jefe, () => [])
                .add(pct);
          }

          // union of jefes across selected months
          final Set<String> allJefes = {};
          for (final m in dataByMonth.keys) {
            allJefes.addAll(dataByMonth[m]!.keys);
          }
          final jefes = allJefes.toList()..sort((a, b) => a.compareTo(b));

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Meses',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: sortedMonths.map((m) {
                            final selected = _selectedMonths.contains(m);
                            return ChoiceChip(
                              label: Text(m),
                              selected: selected,
                              onSelected: (v) {
                                setState(() {
                                  if (v)
                                    _selectedMonths.add(m);
                                  else
                                    _selectedMonths.remove(m);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        if (selectedList.isNotEmpty)
                          Wrap(
                            spacing: 12,
                            children: selectedList.map((m) {
                              final c = monthColors[m] ?? Colors.black;
                              return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 14, height: 14, color: c),
                                    const SizedBox(width: 6),
                                    Text(m)
                                  ]);
                            }).toList(),
                          )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: jefes.isEmpty
                      ? Center(
                          child: Text(_selectedMonths.isEmpty
                              ? 'No hay meses seleccionados'
                              : 'No hay datos para los meses seleccionados'))
                      : ListView.separated(
                          itemCount: jefes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final jefe = jefes[i];
                            return Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(jefe,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Column(
                                      children: selectedList.map((m) {
                                        final vals =
                                            dataByMonth[m]?[jefe] ?? [];
                                        final avg = vals.isEmpty
                                            ? 0.0
                                            : (vals.reduce((a, b) => a + b) /
                                                vals.length);
                                        final color =
                                            monthColors[m] ?? Colors.black;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                  width: 10,
                                                  height: 10,
                                                  color: color),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                  width: 80,
                                                  child: Text(m,
                                                      style: const TextStyle(
                                                          fontSize: 12))),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child:
                                                      LinearProgressIndicator(
                                                    value: (avg / 100.0)
                                                        .clamp(0.0, 1.0),
                                                    minHeight: 12,
                                                    backgroundColor:
                                                        Colors.grey.shade200,
                                                    color: color,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('${avg.toStringAsFixed(1)}%',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
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
          );
        },
      ),
    );
  }
}
