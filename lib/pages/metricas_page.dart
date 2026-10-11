import 'package:flutter/material.dart';

import 'metricas_page_fixed.dart';

/// Wrapper limpio que delega a la implementación fija de métricas.
class MetricasPage extends StatelessWidget {
  const MetricasPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MetricasPageFixed();
  }
}
