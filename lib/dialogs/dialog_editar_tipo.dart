import 'package:flutter/material.dart';

class DialogEditarTipo extends StatefulWidget {
  final String tipoActual;
  final List<String> tiposUsuario;
  const DialogEditarTipo(
      {required this.tipoActual, required this.tiposUsuario, super.key});
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
        items: widget.tiposUsuario
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) => setState(() => tipo = v ?? widget.tiposUsuario.first),
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
