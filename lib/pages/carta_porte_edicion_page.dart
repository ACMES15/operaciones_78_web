import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartaPorteEdicionPage extends StatefulWidget {
  final Map<String, dynamic> carta;
  final String docId;
  const CartaPorteEdicionPage(
      {Key? key, required this.carta, required this.docId})
      : super(key: key);

  @override
  State<CartaPorteEdicionPage> createState() => _CartaPorteEdicionPageState();
}

class _CartaPorteEdicionPageState extends State<CartaPorteEdicionPage> {
  late TextEditingController choferController;
  late TextEditingController destinoController;
  late TextEditingController fechaController;
  late TextEditingController numeroControlController;
  late TextEditingController rfcController;
  late TextEditingController unidadController;
  List<Map<String, dynamic>> filas = [];

  @override
  void initState() {
    super.initState();
    choferController =
        TextEditingController(text: widget.carta['chofer'] ?? '');
    destinoController =
        TextEditingController(text: widget.carta['destino'] ?? '');
    fechaController = TextEditingController(text: widget.carta['fecha'] ?? '');
    numeroControlController =
        TextEditingController(text: widget.carta['numero_control'] ?? '');
    rfcController = TextEditingController(text: widget.carta['rfc'] ?? '');
    unidadController =
        TextEditingController(text: widget.carta['unidad'] ?? '');
    final rawFilas = widget.carta['filas'];
    if (rawFilas is List) {
      filas = rawFilas.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  @override
  void dispose() {
    choferController.dispose();
    destinoController.dispose();
    fechaController.dispose();
    numeroControlController.dispose();
    rfcController.dispose();
    unidadController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final data = {
      'chofer': choferController.text,
      'destino': destinoController.text,
      'fecha': fechaController.text,
      'numero_control': numeroControlController.text,
      'rfc': rfcController.text,
      'unidad': unidadController.text,
      'filas': filas,
    };
    await FirebaseFirestore.instance
        .collection('cartas_porte')
        .doc(widget.docId)
        .update(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carta porte actualizada')),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Carta Porte'),
        backgroundColor: const Color(0xFF2D6A4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Guardar',
            onPressed: _guardar,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: choferController,
              decoration: const InputDecoration(labelText: 'Chofer'),
            ),
            TextField(
              controller: destinoController,
              decoration: const InputDecoration(labelText: 'Destino'),
            ),
            TextField(
              controller: fechaController,
              decoration: const InputDecoration(labelText: 'Fecha'),
            ),
            TextField(
              controller: numeroControlController,
              decoration: const InputDecoration(labelText: 'Número de control'),
            ),
            TextField(
              controller: rfcController,
              decoration: const InputDecoration(labelText: 'RFC'),
            ),
            TextField(
              controller: unidadController,
              decoration: const InputDecoration(labelText: 'Unidad'),
            ),
            const SizedBox(height: 24),
            const Text('Filas:', style: TextStyle(fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filas.length,
              itemBuilder: (context, idx) {
                final fila = filas[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fila.entries
                          .map((e) => Text('${e.key}: ${e.value}'))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
