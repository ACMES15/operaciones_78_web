import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarRegistroDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String usuarioActual;
  const EditarRegistroDialog(
      {required this.docId, required this.data, required this.usuarioActual});

  @override
  State<EditarRegistroDialog> createState() => _EditarRegistroDialogState();
}

class _EditarRegistroDialogState extends State<EditarRegistroDialog> {
  late TextEditingController guiaController;
  late TextEditingController bultosController;
  late TextEditingController nombreRecibeController;
  late List<TextEditingController> pedidoControllers;
  late List<TextEditingController> contrareciboControllers;

  @override
  void initState() {
    super.initState();
    guiaController = TextEditingController(text: widget.data['guia'] ?? '');
    bultosController = TextEditingController(text: widget.data['bultos'] ?? '');
    nombreRecibeController =
        TextEditingController(text: widget.data['nombreRecibe'] ?? '');
    // Soportar lista o string para pedidos
    final pedidos = widget.data['pedido'];
    if (pedidos is List) {
      pedidoControllers = pedidos
          .map<TextEditingController>(
              (p) => TextEditingController(text: p?.toString() ?? ''))
          .toList();
      if (pedidoControllers.isEmpty)
        pedidoControllers.add(TextEditingController());
    } else {
      pedidoControllers = [
        TextEditingController(text: pedidos?.toString() ?? '')
      ];
    }
    // Soportar lista o string para contrarecibos
    final contras = widget.data['contrarecibo'];
    if (contras is List) {
      contrareciboControllers = contras
          .map<TextEditingController>(
              (c) => TextEditingController(text: c?.toString() ?? ''))
          .toList();
      if (contrareciboControllers.isEmpty)
        contrareciboControllers.add(TextEditingController());
    } else {
      contrareciboControllers = [
        TextEditingController(text: contras?.toString() ?? '')
      ];
    }
  }

  @override
  void dispose() {
    guiaController.dispose();
    bultosController.dispose();
    nombreRecibeController.dispose();
    for (final c in pedidoControllers) {
      c.dispose();
    }
    for (final c in contrareciboControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final pedidos = pedidoControllers
        .map((c) => c.text.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final contras = contrareciboControllers
        .map((c) => c.text.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    await FirebaseFirestore.instance
        .collection('paqueteria_externa')
        .doc(widget.docId)
        .update({
      'guia': guiaController.text.trim(),
      'bultos': bultosController.text.trim(),
      'pedido': pedidos,
      'contrarecibo': contras,
      'nombreRecibe': nombreRecibeController.text.trim(),
      'usuarioEdito': widget.usuarioActual,
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      title: Row(
        children: [
          const Icon(Icons.edit, color: Color(0xFF2D6A4F), size: 32),
          const SizedBox(width: 12),
          const Text(
            'Editar registro',
            style: TextStyle(
              fontSize: 24,
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
              // Pedidos múltiples
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pedidos:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...pedidoControllers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final controller = entry.value;
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Pedido',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (pedidoControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () {
                              setState(() {
                                pedidoControllers.removeAt(i).dispose();
                              });
                            },
                          ),
                        if (i == pedidoControllers.length - 1)
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green),
                            onPressed: () {
                              setState(() {
                                pedidoControllers.add(TextEditingController());
                              });
                            },
                          ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 16),
              // Contrarecibos múltiples
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contrarecibos:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...contrareciboControllers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final controller = entry.value;
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Contrarecibo',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (contrareciboControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () {
                              setState(() {
                                contrareciboControllers.removeAt(i).dispose();
                              });
                            },
                          ),
                        if (i == contrareciboControllers.length - 1)
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green),
                            onPressed: () {
                              setState(() {
                                contrareciboControllers
                                    .add(TextEditingController());
                              });
                            },
                          ),
                      ],
                    );
                  }).toList(),
                ],
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
              const SizedBox(height: 16),
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
