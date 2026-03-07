import 'package:flutter/material.dart';

class DialogAgregarUsuario extends StatefulWidget {
  final List<String> tiposUsuario;
  const DialogAgregarUsuario({super.key, required this.tiposUsuario});
  @override
  State<DialogAgregarUsuario> createState() => _DialogAgregarUsuarioState();
}

class _DialogAgregarUsuarioState extends State<DialogAgregarUsuario> {
  final _formKey = GlobalKey<FormState>();
  String nombre = '';
  String usuario = '';
  String correo = '';
  String tipo = '';
  bool activo = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar usuario'),
      content: SizedBox(
        width: 350,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese nombre' : null,
                onChanged: (v) => nombre = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Usuario'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese usuario' : null,
                onChanged: (v) => usuario = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese correo' : null,
                onChanged: (v) => correo = v,
              ),
              DropdownButtonFormField<String>(
                value: tipo.isEmpty && widget.tiposUsuario.isNotEmpty
                    ? widget.tiposUsuario.first
                    : tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: widget.tiposUsuario
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    tipo = v ??
                        (widget.tiposUsuario.isNotEmpty
                            ? widget.tiposUsuario.first
                            : '');
                  });
                },
                validator: (v) =>
                    v == null || v.isEmpty ? 'Seleccione tipo' : null,
              ),
              SwitchListTile(
                value: activo,
                onChanged: (v) {
                  setState(() {
                    activo = v;
                  });
                },
                title: const Text('Activo'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              if (tipo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Seleccione un tipo de usuario.')),
                );
                return;
              }
              Navigator.pop(context, {
                'nombre': nombre,
                'usuario': usuario,
                'correo': correo,
                'tipo': tipo,
                'activo': activo,
                'password': usuario,
                'requiereCambioPassword': true,
              });
            }
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
