import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EntregasCycPage extends StatefulWidget {
  final String usuario;
  const EntregasCycPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EntregasCycPage> createState() => _EntregasCycPageState();
}

class _EntregasCycPageState extends State<EntregasCycPage> {
  // Aquí puedes adaptar la lógica de historial_firmadas_cdr_page.dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas CyC'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: Center(
        child: Text('Aquí irá el historial de entregas CyC.'),
      ),
    );
  }
}
