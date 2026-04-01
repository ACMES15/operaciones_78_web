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
    final doc = await FirebaseFirestore.instance
        .collection('entregas')
        .doc('mkp')
        .get();
    int count = 0;
    if (doc.exists) {
      final data = doc.data() ?? {};
      if (data['items'] is List) {
        for (final reg in data['items']) {
          if (reg is Map &&
              (reg['devolucion_mkp'] ?? '').toString().isNotEmpty &&
              (reg['guia'] ?? '').toString().isEmpty) {
            count++;
          }
        }
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
