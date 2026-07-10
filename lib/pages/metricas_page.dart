import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MetricasPage extends StatefulWidget {
  const MetricasPage({Key? key}) : super(key: key);

  @override
  State<MetricasPage> createState() => _MetricasPageState();
}

class _MetricasPageState extends State<MetricasPage> {
  String? _selectedMonth; // format YYYY-MM

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
          final month = _selectedMonth ??
              (sortedMonths.isNotEmpty ? sortedMonths.first : null);

          // aggregate by jefe for selected month
          final Map<String, List<double>> byJefe = {};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['createdAt'] is Timestamp
                ? data['createdAt'] as Timestamp
                : null;
            final key = _monthKeyFromTimestamp(ts);
            if (month == null || key != month) continue;
            final jefe = (data['jefe']?.toString() ?? 'Sin Jefe');
            final pct = _normalizePercent(data['percentScanned']);
            byJefe.putIfAbsent(jefe, () => []).add(pct);
          }

          final List<MapEntry<String, double>> entries =
              byJefe.entries.map((e) {
            final avg = e.value.isEmpty
                ? 0.0
                : (e.value.reduce((a, b) => a + b) / e.value.length);
            return MapEntry(e.key, avg);
          }).toList()
                ..sort((a, b) => b.value.compareTo(a.value));

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
                    child: Row(
                      children: [
                        const Expanded(
                            child: Text('Mes',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: month,
                          hint: const Text('Selecciona mes'),
                          items: sortedMonths
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedMonth = v;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(month == null
                              ? 'No hay datos'
                              : 'No hay métricas para $month'))
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = entries[i];
                            final label = e.key;
                            final pct = e.value.clamp(0.0, 100.0);
                            return Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                            child: Text(label,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        Text('${pct.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: (pct / 100.0).clamp(0.0, 1.0),
                                        minHeight: 14,
                                        backgroundColor: Colors.grey.shade200,
                                        color: Colors.black,
                                      ),
                                    ),
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
