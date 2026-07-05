import 'package:flutter/material.dart';

class PdisDetailPage extends StatelessWidget {
  final String usuario;
  const PdisDetailPage({Key? key, required this.usuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDIS - Detalle (deshabilitado)'),
      ),
      body: const Center(
        child: Text('Funcionalidad deshabilitada temporalmente.'),
      ),
    );
  }
}
