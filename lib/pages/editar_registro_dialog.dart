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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      title: Row(
        children: [
          const Icon(Icons.edit, color: Color(0xFF2D6A4F), size: 32),
          const SizedBox(width: 12),
          const Text(
            'Editar registro',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D6A4F),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: guiaController,
                decoration: InputDecoration(
                  labelText: 'Guía',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bultosController,
                decoration: InputDecoration(
                  labelText: 'Bultos',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pedidoController,
                decoration: InputDecoration(
                  labelText: 'Pedido',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contrareciboController,
                decoration: InputDecoration(
                  labelText: 'Contrarecibo',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreRecibeController,
                decoration: InputDecoration(
                  labelText: 'Nombre de quien recibe',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Color(0xFFB7B7B7)),
          label: const Text('Cancelar',
              style: TextStyle(color: Color(0xFFB7B7B7))),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text('Guardar',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 110, 235, 179),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
