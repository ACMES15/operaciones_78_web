import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'pdis_detail_page.dart';
import 'inventario_pdis_page.dart';
import 'inventario_historico_page.dart';

class PdisPage extends StatefulWidget {
  final String usuario;
  const PdisPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<PdisPage> createState() => _PdisPageState();
}

class _PdisPageState extends State<PdisPage> {
  String? _selectedJefe; // key: jefe name
  Map<String, int> _countsByJefe = {};
  int _totalPdis = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribeData();
  }

  void _subscribeData() async {
    setState(() {
      _loading = true;
    });

    // Listen once and compute aggregates. Using a one-time fetch keeps UI snappy.
    final doc = await FirebaseFirestore.instance.doc('ohpdis/datos').get();
    final plantillaDoc =
        await FirebaseFirestore.instance.doc('plantilla_ejecutiva/datos').get();

    final List<dynamic> rows = (doc.data()?['datos']) ?? [];

    // Build map for SECCION -> NOMBRE from plantilla (if present)
    final Map<String, dynamic> plantillaMap =
        (plantillaDoc.data() ?? {})['map'] ?? {};

    final counts = <String, int>{};
    int total = 0;

    for (final r in rows) {
      if (r is Map<String, dynamic>) {
        final String jefe = _extractJefaturaFromRow(r, plantillaMap);
        if (jefe.isEmpty) continue;
        counts[jefe] = (counts[jefe] ?? 0) + 1;
        total++;
      }
    }

    setState(() {
      _countsByJefe = counts;
      _totalPdis = total;
      _loading = false;
      // keep selected if still present
      if (_selectedJefe != null && !_countsByJefe.containsKey(_selectedJefe)) {
        _selectedJefe = null;
      }
    });
  }

  String _extractJefaturaFromRow(Map<String, dynamic> r, Map plantillaMap) {
    // Try common fields, case-insensitive
    String? value;
    for (final k in [
      'Jefatura',
      'jefatura',
      'JEFA',
      'SECCION',
      'seccion',
      'Seccion'
    ]) {
      if (r.containsKey(k) && r[k] != null) {
        value = r[k].toString().trim();
        break;
      }
    }
    if (value == null || value.isEmpty) {
      // Try map via 'SECCION' code
      final sec = r['SECCION'] ?? r['seccion'];
      if (sec != null) {
        value = plantillaMap[sec.toString()]?.toString() ?? '';
      }
    }
    return value ?? '';
  }

  void _onSelectJefe(String jefe) {
    setState(() {
      _selectedJefe = jefe;
    });
  }

  Widget _buildChartCard(BuildContext context) {
    final int count = _selectedJefe == null
        ? _totalPdis
        : (_countsByJefe[_selectedJefe!] ?? 0);
    final double pct = _totalPdis > 0 ? (count / _totalPdis) : 0.0;
    // stylized white/black contrast card with animated chart
    return Card(
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _selectedJefe == null
                  ? 'Cobertura PDIS (Total)'
                  : 'Cobertura de $_selectedJefe',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 200,
              width: 200,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: pct),
                duration: const Duration(milliseconds: 700),
                builder: (context, animatedPct, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 200,
                        width: 200,
                        child: CircularProgressIndicator(
                          value: animatedPct,
                          strokeWidth: 18,
                          color: Colors.black,
                          backgroundColor: Colors.grey.shade300,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              '${(animatedPct * 100).toStringAsFixed(animatedPct >= 0.01 ? 1 : 0)}%',
                              key: ValueKey<double>(animatedPct),
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('$count PDIS',
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (_selectedJefe != null)
              TextButton.icon(
                onPressed: () {
                  // Reset selection
                  setState(() {
                    _selectedJefe = null;
                  });
                },
                icon: const Icon(Icons.refresh, color: Colors.black),
                label: const Text('Ver todos',
                    style: TextStyle(color: Colors.black)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJefesList(BuildContext context) {
    final entries = _countsByJefe.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                    child: Text('Jefaturas',
                        style: Theme.of(context).textTheme.titleMedium)),
                Chip(label: Text('Total: $_totalPdis')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No se encontraron PDIS'))
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      final isSelected = e.key == _selectedJefe;
                      return ListTile(
                        onTap: () => _onSelectJefe(e.key),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        tileColor: isSelected ? Colors.black12 : Colors.white,
                        title: Text(e.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            const SizedBox(height: 4),
                            Text(
                                '${(_totalPdis > 0 ? (e.value * 100 / _totalPdis).toStringAsFixed(1) : "0")}%',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsPanel(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Acciones', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_selectedJefe != null)
              Text('Jefe: $_selectedJefe',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        InventarioPdisPage(usuario: widget.usuario)));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 6,
              ),
              child: const Text('Auditoría PDIS',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const InventarioHistoricoPage()));
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black87, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Histórico',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _subscribeData,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('PDIS - Auditoría',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PdisDetailPage(usuario: widget.usuario))),
            tooltip: 'OH PDIS',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 900) {
                    // Desktop / wide: 3 columns (left chart, center list ~50%, right actions)
                    return Row(
                      children: [
                        Flexible(flex: 3, child: _buildChartCard(context)),
                        const SizedBox(width: 16),
                        Flexible(flex: 6, child: _buildJefesList(context)),
                        const SizedBox(width: 16),
                        Flexible(flex: 3, child: _buildActionsPanel(context)),
                      ],
                    );
                  } else {
                    // Mobile / narrow: stacked with a scrollable actions panel
                    return Column(
                      children: [
                        _buildChartCard(context),
                        const SizedBox(height: 12),
                        Expanded(flex: 2, child: _buildJefesList(context)),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 140,
                            maxHeight: 380,
                          ),
                          child: SingleChildScrollView(
                            child: _buildActionsPanel(context),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
      ),
    );
  }
}
