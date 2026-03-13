import 'package:flutter/material.dart';

class AgregarTipoUsuarioWidget extends StatefulWidget {
  final void Function(String) onAgregar;
  const AgregarTipoUsuarioWidget({Key? key, required this.onAgregar})
      : super(key: key);

  @override
  State<AgregarTipoUsuarioWidget> createState() =>
      _AgregarTipoUsuarioWidgetState();
}

class _AgregarTipoUsuarioWidgetState extends State<AgregarTipoUsuarioWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Nuevo tipo'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Agregar tipo',
          onPressed: () {
            final nuevoTipo = _controller.text.trim();
            if (nuevoTipo.isNotEmpty) {
              widget.onAgregar(nuevoTipo);
              _controller.clear();
            }
          },
        ),
      ],
    );
  }
}
