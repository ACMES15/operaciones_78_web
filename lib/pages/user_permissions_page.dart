import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ...existing code...
class UserPermissionsPage extends StatelessWidget {
  const UserPermissionsPage({super.key});
  static const List<String> tipos = [
    'ADMINISTRATIVO',
    'STAFF AUXILIAR',
    'JEFATURA',
    'VENTAS',
    'PREVENCION',
  ];
  static const List<String> paginas = [
    'Control de usuarios',
    'Permisos de usuario',
    'Hoja de ruta',
    'Hoja de XD',
    'Historial Hoja de XD',
    'Carta Porte',
    'Historial Carta Porte',
    'Plantilla Ejecutiva',
    'DevCan',
    'Historial Entregas DevCan',
    'Recogidos',
    'Historial Entregas Recogidos',
  ];
  @override
  Widget build(BuildContext context) {
    return const _PermisosBody();
  }
}

class _PermisosBody extends StatefulWidget {
  const _PermisosBody();
  @override
  State<_PermisosBody> createState() => _PermisosBodyState();
}

class _PermisosBodyState extends State<_PermisosBody> {
  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => cargando = true);
    await _cargarTiposUsuario(internal: true);
    await _cargarPermisos(internal: true);
    setState(() => cargando = false);
  }

  Future<void> _cargarTiposUsuario({bool internal = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final tipos = prefs.getString('tipos_usuario');
    if (tipos != null) {
      tiposUsuario = List<String>.from(jsonDecode(tipos));
    } else {
      tiposUsuario = List<String>.from(UserPermissionsPage.tipos);
    }
    if (!internal) setState(() {});
  }

  Future<void> _cargarPermisos({bool internal = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('permisos_tipo_usuario');
    if (data != null) {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      permisos = decoded.map((tipo, pags) => MapEntry(
            tipo,
            (pags as Map<String, dynamic>)
                .map((pag, val) => MapEntry(pag, val == true)),
          ));
      // Sincronizar: agregar páginas nuevas a cada tipo
      for (final tipo in tiposUsuario) {
        permisos[tipo] ??= {};
        for (final pag in UserPermissionsPage.paginas) {
          if (!permisos[tipo]!.containsKey(pag)) {
            permisos[tipo]![pag] = true;
          }
        }
      }
      // Opcional: eliminar páginas que ya no existen
      for (final tipo in tiposUsuario) {
        permisos[tipo]?.removeWhere(
            (pag, _) => !UserPermissionsPage.paginas.contains(pag));
      }
      // Guardar sincronización si hubo cambios
      await prefs.setString('permisos_tipo_usuario', jsonEncode(permisos));
    } else {
      for (final tipo in tiposUsuario) {
        permisos[tipo] = {};
        for (final pag in UserPermissionsPage.paginas) {
          permisos[tipo]![pag] = true;
        }
      }
    }
    if (!internal) setState(() {});
  }

  String? tipoSeleccionado;
  Map<String, Map<String, bool>> permisos = {};
  bool cargando = true;
  List<String> tiposUsuario = [];
  bool _tieneCambios = false;

  Future<void> _guardarTiposUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tipos_usuario', jsonEncode(tiposUsuario));
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tiposUsuario.isEmpty) {
      return Center(child: Text('No hay tipos de usuario registrados.'));
    }
    tipoSeleccionado ??= tiposUsuario.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: const Color(0xFFF6F7FB),
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline,
                            color: Color(0xFF2D6A4F)),
                        const SizedBox(width: 10),
                        Text('Permisos de usuario',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar tipo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A4F),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _agregarTipoUsuario,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Text('Tipo de usuario:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: tipoSeleccionado,
                          items: tiposUsuario
                              .map((tipo) => DropdownMenuItem(
                                    value: tipo,
                                    child: Text(tipo),
                                  ))
                              .toList(),
                          onChanged: (nuevo) {
                            setState(() {
                              tipoSeleccionado = nuevo;
                            });
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Editar tipo',
                          onPressed: () async {
                            String nuevoNombre = tipoSeleccionado!;
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Editar tipo de usuario'),
                                  content: TextField(
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Nuevo nombre'),
                                    controller: TextEditingController(
                                        text: tipoSeleccionado),
                                    onChanged: (v) => nuevoNombre = v,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (nuevoNombre.isNotEmpty &&
                                            nuevoNombre != tipoSeleccionado &&
                                            !tiposUsuario
                                                .contains(nuevoNombre)) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (nuevoNombre.isNotEmpty &&
                                nuevoNombre != tipoSeleccionado &&
                                !tiposUsuario.contains(nuevoNombre)) {
                              final idx =
                                  tiposUsuario.indexOf(tipoSeleccionado!);
                              tiposUsuario[idx] = nuevoNombre;
                              permisos[nuevoNombre] =
                                  permisos[tipoSeleccionado]!;
                              permisos.remove(tipoSeleccionado);
                              tipoSeleccionado = nuevoNombre;
                              await _guardarTiposUsuario();
                              await _guardarPermisos();
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Tipo "${tipoSeleccionado!}" editado a "$nuevoNombre".')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Eliminar tipo',
                          onPressed: () async {
                            if (tipoSeleccionado == 'ADMINISTRATIVO' ||
                                tipoSeleccionado == 'STAFF AUXILIAR' ||
                                tipoSeleccionado == 'JEFATURA' ||
                                tipoSeleccionado == 'VENTAS' ||
                                tipoSeleccionado == 'PREVENCION' ||
                                tipoSeleccionado == 'ADMIN OMNICANAL' ||
                                tipoSeleccionado == 'ADMIN ENVIOS') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'No se puede eliminar un tipo base.')),
                              );
                              return;
                            }
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Eliminar tipo de usuario'),
                                  content: Text(
                                      '¿Seguro que deseas eliminar "$tipoSeleccionado"? Todos los usuarios de este tipo serán eliminados.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirm == true) {
                              tiposUsuario.remove(tipoSeleccionado);
                              permisos.remove(tipoSeleccionado);
                              await _guardarTiposUsuario();
                              await _guardarPermisos();
                              // Eliminar usuarios de ese tipo
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final data =
                                  prefs.getString('usuarios_guardados');
                              List<Map<String, dynamic>> usuarios = [];
                              if (data != null) {
                                final List<dynamic> decoded = jsonDecode(data);
                                usuarios = decoded
                                    .cast<Map<String, dynamic>>()
                                    .map((e) => Map<String, dynamic>.from(e))
                                    .toList();
                              }
                              usuarios.removeWhere(
                                  (u) => u['tipo'] == tipoSeleccionado);
                              await prefs.setString(
                                  'usuarios_guardados', jsonEncode(usuarios));
                              setState(() {
                                tipoSeleccionado = tiposUsuario.isNotEmpty
                                    ? tiposUsuario.first
                                    : null;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Tipo "$tipoSeleccionado" y sus usuarios eliminados.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView(
                        children: UserPermissionsPage.paginas.map((pag) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 0),
                            child: ListTile(
                              title: Text(pag),
                              trailing: Switch(
                                value:
                                    permisos[tipoSeleccionado]?[pag] ?? false,
                                onChanged: (val) {
                                  setState(() {
                                    permisos[tipoSeleccionado]![pag] = val;
                                    _tieneCambios = true;
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar cambios'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tieneCambios
                              ? const Color(0xFF2D6A4F)
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _tieneCambios ? _guardarPermisos : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _agregarTipoUsuario() async {
    String nuevoTipo = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar tipo de usuario'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tipo de usuario'),
            onChanged: (v) => nuevoTipo = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nuevoTipo.isNotEmpty && !tiposUsuario.contains(nuevoTipo)) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
    if (nuevoTipo.isNotEmpty && !tiposUsuario.contains(nuevoTipo)) {
      tiposUsuario.add(nuevoTipo);
      permisos[nuevoTipo] = {};
      for (final pag in UserPermissionsPage.paginas) {
        permisos[nuevoTipo]![pag] = true;
      }
      await _guardarTiposUsuario();
      await _guardarPermisos();
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('tipos_usuario', jsonEncode(tiposUsuario));
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tipo "$nuevoTipo" agregado.')),
      );
    }
  }
  // ...existing code...
  // (Removed misplaced code block that was outside any function)

  Future<void> _guardarPermisos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('permisos_tipo_usuario', jsonEncode(permisos));
    setState(() {
      _tieneCambios = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permisos guardados.')),
    );
  }
}
