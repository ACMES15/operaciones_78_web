import 'package:flutter/material.dart';

class DialogEditarTipo extends StatefulWidget {
  final String tipoActual;
  const DialogEditarTipo({required this.tipoActual, super.key});
  @override
  State<DialogEditarTipo> createState() => _DialogEditarTipoState();
}

class _DialogEditarTipoState extends State<DialogEditarTipo> {
  late String tipo;
  @override
  void initState() {
    super.initState();
    tipo = widget.tipoActual;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar tipo de usuario'),
      content: DropdownButtonFormField<String>(
        value: tipo,
        items: const [
          DropdownMenuItem(
              value: 'ADMINISTRATIVO', child: Text('ADMINISTRATIVO')),
          DropdownMenuItem(
              value: 'STAFF AUXILIAR', child: Text('STAFF AUXILIAR')),
          DropdownMenuItem(value: 'JEFATURA', child: Text('JEFATURA')),
          DropdownMenuItem(value: 'VENTAS', child: Text('VENTAS')),
          DropdownMenuItem(value: 'PREVENCION', child: Text('PREVENCION')),
          DropdownMenuItem(
              value: 'ADMIN OMNICANAL', child: Text('ADMIN OMNICANAL')),
          DropdownMenuItem(value: 'ADMIN ENVIOS', child: Text('ADMIN ENVIOS')),
        ],
        onChanged: (v) => setState(() => tipo = v ?? 'ADMINISTRATIVO'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, tipo),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
