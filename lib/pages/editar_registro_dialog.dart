import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarRegistroDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const EditarRegistroDialog({required this.docId, required this.data});

  @override
  State<EditarRegistroDialog> createState() => _EditarRegistroDialogState();
}

class _EditarRegistroDialogState extends State<EditarRegistroDialog> {
  late TextEditingController guiaController;
  late TextEditingController bultosController;
  late TextEditingController pedidoController;
  late TextEditingController contrareciboController;
  late TextEditingController nombreRecibeController;

  @override
  void initState() {
    super.initState();
    guiaController = TextEditingController(text: widget.data['guia'] ?? '');
    bultosController = TextEditingController(text: widget.data['bultos'] ?? '');
    pedidoController = TextEditingController(text: widget.data['pedido'] ?? '');
    contrareciboController =
        TextEditingController(text: widget.data['contrarecibo'] ?? '');
    nombreRecibeController =
        TextEditingController(text: widget.data['nombreRecibe'] ?? '');
  }

  @override
  void dispose() {
    guiaController.dispose();
    bultosController.dispose();
    pedidoController.dispose();
    contrareciboController.dispose();
    nombreRecibeController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    await FirebaseFirestore.instance
        .collection('paqueteria_externa')
        .doc(widget.docId)
        .update({
      'guia': guiaController.text.trim(),
      'bultos': bultosController.text.trim(),
      'pedido': pedidoController.text.trim(),
      'contrarecibo': contrareciboController.text.trim(),
      'nombreRecibe': nombreRecibeController.text.trim(),
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar registro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: guiaController,
              decoration: const InputDecoration(labelText: 'Guía'),
            ),
            TextField(
              controller: bultosController,
              decoration: const InputDecoration(labelText: 'Bultos'),
            ),
            TextField(
              controller: pedidoController,
              decoration: const InputDecoration(labelText: 'Pedido'),
            ),
            TextField(
              controller: contrareciboController,
              decoration: const InputDecoration(labelText: 'Contrarecibo'),
            ),
            TextField(
              controller: nombreRecibeController,
              decoration:
                  const InputDecoration(labelText: 'Nombre de quien recibe'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D6A4F),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
