import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../dialogs/dialog_agregar_usuario.dart';
import '../dialogs/dialog_agregar_masivo.dart';
import '../dialogs/dialog_editar_tipo.dart';

class UserControlPage extends StatelessWidget {
  const UserControlPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _UserControlPageBody();
  }
}

class _UserControlPageBody extends StatefulWidget {
  // ...existing code...
  const _UserControlPageBody();
  @override
  State<_UserControlPageBody> createState() => _UserControlPageBodyState();
}

class _UserControlPageBodyState extends State<_UserControlPageBody> {
  String _busqueda = '';
  List<String> tiposUsuario = [];
  @override
  void initState() {
    super.initState();
    _cargarTiposUsuario();
    _cargarUsuarios();
  }

  Future<void> _cargarTiposUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final tipos = prefs.getString('tipos_usuario');
    if (tipos != null) {
      tiposUsuario = List<String>.from(jsonDecode(tipos));
    } else {
      tiposUsuario = [
        'ADMINISTRATIVO',
        'STAFF AUXILIAR',
        'JEFATURA',
        'VENTAS',
        'PREVENCION',
        'ADMIN OMNICANAL',
        'ADMIN ENVIOS',
      ];
    }
    setState(() {});
  }

  List<Map<String, dynamic>> usuarios = [];
  bool _tieneCambios = false;
  bool _cargando = true;

  // ...existing code...

  Future<void> _cargarUsuarios() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('usuarios_guardados');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() {
        usuarios = decoded
            .cast<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final existeAcmes = usuarios.any((u) => u['usuario'] == 'acmes15');
        if (!existeAcmes) {
          usuarios.add({
            'nombre': 'Administrador General',
            'usuario': 'acmes15',
            'correo': 'acmes15@empresa.com',
            'tipo': 'SUPERADMIN',
            'activo': true,
            'password': 'cecoatl1315',
            'requiereCambioPassword': false,
          });
        }
      });
    }
    setState(() {
      _cargando = false;
    });
  }

  Future<void> _guardarCambios() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuarios_guardados', jsonEncode(usuarios));
    setState(() {
      _tieneCambios = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambios guardados correctamente.')),
    );
  }

  void _agregarUsuario() async {
    final nuevo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogAgregarUsuario(tiposUsuario: tiposUsuario),
    );
    if (nuevo != null) {
      nuevo['password'] = nuevo['usuario'];
      setState(() {
        usuarios.add(nuevo);
        _tieneCambios = true;
      });
      await _guardarCambios();
    }
  }

  void _agregarMasivo() async {
    final nuevos = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => const DialogAgregarMasivo(),
    );
    if (nuevos != null && nuevos.isNotEmpty) {
      setState(() {
        usuarios.addAll(nuevos);
        _tieneCambios = true;
      });
      await _guardarCambios();
    }
  }

  void _editarTipo(int index) async {
    if (usuarios[index]['usuario'] == 'acmes15') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede editar el usuario maestro.')),
      );
      return;
    }
    final tipo = await showDialog<String>(
      context: context,
      builder: (context) =>
          DialogEditarTipo(tipoActual: usuarios[index]['tipo']),
    );
    if (tipo != null) {
      setState(() {
        usuarios[index]['tipo'] = tipo;
        _tieneCambios = true;
      });
      await _guardarCambios();
    }
  }

  void _eliminarUsuario(int index) async {
    if (usuarios[index]['usuario'] == 'acmes15') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede eliminar el usuario maestro.')),
      );
      return;
    }
    setState(() {
      usuarios.removeAt(index);
      _tieneCambios = true;
    });
    await _guardarCambios();
  }

  void _restablecerPassword(int index) async {
    final nueva = await showDialog<String>(
      context: context,
      builder: (context) {
        String nuevaPass = '';
        return AlertDialog(
          title: const Text('Restablecer contraseña'),
          content: TextField(
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            onChanged: (v) => nuevaPass = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, nuevaPass),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (nueva != null && nueva.isNotEmpty) {
      setState(() {
        usuarios[index]['password'] = nueva;
        _tieneCambios = true;
      });
      // Notificar al usuario que su contraseña fue restablecida
      final prefs = await SharedPreferences.getInstance();
      final notificaciones = prefs.getString('notificaciones_password') ?? '[]';
      final List<dynamic> lista = jsonDecode(notificaciones);
      lista.add({
        'usuario': usuarios[index]['usuario'],
        'fecha': DateTime.now().toIso8601String(),
        'mensaje': 'Tu contraseña ha sido restablecida por el administrador',
      });
      await prefs.setString('notificaciones_password', jsonEncode(lista));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Contraseña restablecida. Se notificó al usuario.')),
      );
      await _guardarCambios();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    // Filtrar usuarios según búsqueda
    final usuariosFiltrados = _busqueda.isEmpty
        ? usuarios
        : usuarios.where((u) {
            final nombre = (u['nombre'] ?? '').toString().toLowerCase();
            final usuario = (u['usuario'] ?? '').toString().toLowerCase();
            final correo = (u['correo'] ?? '').toString().toLowerCase();
            final query = _busqueda.toLowerCase();
            return nombre.contains(query) ||
                usuario.contains(query) ||
                correo.contains(query);
          }).toList();
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
                        const Icon(Icons.admin_panel_settings_outlined,
                            color: Color(0xFF2D6A4F)),
                        const SizedBox(width: 10),
                        Text('Control de usuarios',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Buscar usuario, nombre o correo',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 12),
                            ),
                            onChanged: (v) {
                              setState(() {
                                _busqueda = v;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar cambios'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _tieneCambios
                                ? const Color(0xFF2D6A4F)
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _tieneCambios ? _guardarCambios : null,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Agregar usuario'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A4F),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _agregarUsuario,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.group_add_outlined),
                          label: const Text('Carga masiva'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF40916C),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _agregarMasivo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: usuariosFiltrados.isEmpty
                          ? Center(
                              child: Text('No hay usuarios registrados.',
                                  style: Theme.of(context).textTheme.bodyLarge),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth - 120),
                                    child: DataTable(
                                      columnSpacing: 32,
                                      headingRowColor:
                                          MaterialStateProperty.all(
                                              const Color(0xFFE9F5EE)),
                                      columns: const [
                                        DataColumn(label: Text('Nombre')),
                                        DataColumn(label: Text('Usuario')),
                                        DataColumn(label: Text('Correo')),
                                        DataColumn(label: Text('Tipo')),
                                        DataColumn(label: Text('Activo')),
                                        DataColumn(label: Text('Opciones')),
                                      ],
                                      rows: List.generate(
                                          usuariosFiltrados.length, (i) {
                                        final u = usuariosFiltrados[i];
                                        final esMaestro =
                                            u['usuario'] == 'acmes15';
                                        return DataRow(cells: [
                                          DataCell(Text(u['nombre'] ?? '')),
                                          DataCell(Text(u['usuario'] ?? '')),
                                          DataCell(Text(u['correo'] ?? '')),
                                          DataCell(Row(
                                            children: [
                                              Text(u['tipo'] ?? ''),
                                              if (!esMaestro)
                                                IconButton(
                                                  icon: const Icon(Icons.edit,
                                                      size: 18),
                                                  tooltip: 'Editar tipo',
                                                  onPressed: () =>
                                                      _editarTipo(i),
                                                ),
                                            ],
                                          )),
                                          DataCell(Checkbox(
                                            value: u['activo'] ?? false,
                                            onChanged: esMaestro
                                                ? null
                                                : (val) {
                                                    setState(() {
                                                      u['activo'] = val;
                                                      _tieneCambios = true;
                                                    });
                                                  },
                                          )),
                                          DataCell(Row(
                                            children: [
                                              ...(!esMaestro
                                                  ? [
                                                      IconButton(
                                                        icon: const Icon(Icons
                                                            .delete_outline),
                                                        tooltip: 'Eliminar',
                                                        onPressed: () =>
                                                            _eliminarUsuario(i),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.password,
                                                            size: 18),
                                                        tooltip:
                                                            'Restablecer contraseña',
                                                        onPressed: () =>
                                                            _restablecerPassword(
                                                                i),
                                                      ),
                                                    ]
                                                  : []),
                                            ],
                                          )),
                                        ]);
                                      }),
                                    ),
                                  ),
                                ),
                              ),
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
}
