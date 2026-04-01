import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MkpBadgeCounter extends StatefulWidget {
  final Widget child;
  const MkpBadgeCounter({required this.child, Key? key}) : super(key: key);

  @override
  State<MkpBadgeCounter> createState() => _MkpBadgeCounterState();
}

class _MkpBadgeCounterState extends State<MkpBadgeCounter> {
  int _sinGuia = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    // Leer devoluciones de Entregas MKP y guías guardadas para contar igual que en guias_mkp_page.dart
    final entregasDoc = await FirebaseFirestore.instance
        .collection('entregas')
        .doc('mkp')
        .get();
    final guiasDoc =
        await FirebaseFirestore.instance.collection('guias').doc('mkp').get();
    List<Map<String, dynamic>> entregas = [];
    List<Map<String, dynamic>> guias = [];
    if (entregasDoc.exists && entregasDoc.data()?['items'] is List) {
      entregas = List<Map<String, dynamic>>.from(
        (entregasDoc.data()!['items'] as List)
            .whereType<Map<String, dynamic>>(),
      );
    }
    if (guiasDoc.exists && guiasDoc.data()?['items'] is List) {
      guias = List<Map<String, dynamic>>.from(
        (guiasDoc.data()!['items'] as List).whereType<Map<String, dynamic>>(),
      );
    }
    // Unir devoluciones de ambos orígenes
    final Set<String> devoluciones = {
      ...entregas
          .map((e) => e['devolucion_mkp']?.toString() ?? '')
          .where((d) => d.isNotEmpty),
      ...guias
          .map((g) => g['devolucion']?.toString() ?? '')
          .where((d) => d.isNotEmpty),
    };
    final Map<String, Map<String, dynamic>> guiasMap = {
      for (var g in guias) g['devolucion']?.toString() ?? '': g
    };
    int count = 0;
    for (final dev in devoluciones) {
      final reg = guiasMap[dev];
      if (reg == null || (reg['guia'] ?? '').toString().isEmpty) {
        count++;
      }
    }
    setState(() {
      _sinGuia = count;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        widget.child,
        if (!_loading && _sinGuia > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                _sinGuia.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
