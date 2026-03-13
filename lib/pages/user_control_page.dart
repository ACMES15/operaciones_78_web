import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the StatefulWidget for this State class
class UserControlPageBody extends StatefulWidget {
  const UserControlPageBody({Key? key}) : super(key: key);

  @override
  _UserControlPageBodyState createState() => _UserControlPageBodyState();
}

class _UserControlPageBodyState extends State<UserControlPageBody> {
  // Estado
  String _busqueda = '';
  List<String> tiposUsuario = [];
  List<Map<String, dynamic>> usuarios = [];

  Map<String, Map<String, bool>> permisosPorTipo = {};
  bool _cargandoPermisos = true;
  final List<String> paginasDisponibles = [
    'Inicio',
    'Control de usuarios',
    // 'Permisos de usuario',
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

  void initState() {
    super.initState();
    _cargarUsuarios();
    _cargarPermisosTipoUsuario();
  }

  Future<void> _cargarUsuarios() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('usuarios').get();
    setState(() {
      usuarios =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }

  List<Map<String, dynamic>> get _usuariosFiltrados {
    if (_busqueda.trim().isEmpty) return usuarios;
    final filtro = _busqueda.trim().toLowerCase();
    return usuarios.where((u) {
      final id = (u['id'] ?? '').toString().toLowerCase();
      final nombre = (u['nombre'] ?? '').toString().toLowerCase();
      final tipo = (u['tipo'] ?? '').toString().toLowerCase();
      return id.contains(filtro) ||
          nombre.contains(filtro) ||
          tipo.contains(filtro);
    }).toList();
  }

  Future<void> _editarTipoPorUsuario(String usuarioKey) async {
    final usuario = usuarios.firstWhere((u) => u['id'] == usuarioKey);
    final tipoController = TextEditingController(text: usuario['tipo'] ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar tipo de usuario'),
        content: TextField(
            controller: tipoController,
            decoration: const InputDecoration(labelText: 'Tipo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final tipo = tipoController.text.trim();
              if (tipo.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(usuarioKey)
                    .update({'tipo': tipo});
                Navigator.pop(ctx);
                _cargarUsuarios();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarUsuarioPorUsuario(String usuarioKey) async {
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuarioKey)
        .delete();
    _cargarUsuarios();
  }

  // Métodos permisos por tipo (esqueleto)
  Future<void> _cargarPermisosTipoUsuario() async {
    setState(() => _cargandoPermisos = true);
    final doc = await FirebaseFirestore.instance
        .collection('permisos_tipo_usuario')
        .doc('permisos')
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        permisosPorTipo =
            data.map((k, v) => MapEntry(k, Map<String, bool>.from(v)));
        tiposUsuario = permisosPorTipo.keys.toList();
        _cargandoPermisos = false;
      });
    } else {
      setState(() {
        permisosPorTipo = {};
        tiposUsuario = [];
        _cargandoPermisos = false;
      });
    }
  }

  Future<void> _guardarPermisosTipoUsuario() async {
    await FirebaseFirestore.instance
        .collection('permisos_tipo_usuario')
        .doc('permisos')
        .set(permisosPorTipo);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos guardados en Firestore')));
  }

  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gestión de usuarios',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por usuario, nombre o tipo',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _busqueda = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _agregarUsuario,
                        child: const Text('Agregar usuario'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _agregarMasivo,
                        child: const Text('Carga masiva'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: _usuariosFiltrados.isEmpty
                        ? const Center(child: Text('No hay usuarios'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _usuariosFiltrados.length,
                            itemBuilder: (ctx, i) {
                              final u = _usuariosFiltrados[i];
                              return ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(u['nombre'] ?? u['id'] ?? ''),
                                subtitle: Text(
                                    'Usuario: ${u['id'] ?? ''}\nCorreo: ${u['correo'] ?? ''}\nTipo: ${u['tipo'] ?? ''}'),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Editar tipo',
                                      onPressed: () =>
                                          _editarTipoPorUsuario(u['id']),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Eliminar usuario',
                                      onPressed: () =>
                                          _eliminarUsuarioPorUsuario(u['id']),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(thickness: 2),
          const SizedBox(height: 12),
          const Text('Permisos por tipo de usuario',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildPermisosPorTipo(),
            ),
          ),
        ],
      ),
    );
  }

  void _agregarUsuario() {
    final nombreController = TextEditingController();
    final usuarioController = TextEditingController();
    final correoController = TextEditingController();
    final tipoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
                controller: usuarioController,
                decoration: const InputDecoration(labelText: 'Usuario')),
            TextField(
                controller: correoController,
                decoration: const InputDecoration(labelText: 'Correo')),
            TextField(
                controller: tipoController,
                decoration: const InputDecoration(labelText: 'Tipo')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreController.text.trim();
              final usuario = usuarioController.text.trim();
              final correo = correoController.text.trim();
              final tipo = tipoController.text.trim();
              if (nombre.isNotEmpty &&
                  usuario.isNotEmpty &&
                  correo.isNotEmpty &&
                  tipo.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(usuario)
                    .set({
                  'nombre': nombre,
                  'usuario': usuario,
                  'correo': correo,
                  'tipo': tipo
                });
                Navigator.pop(ctx);
                _cargarUsuarios();
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _agregarMasivo() {
    final csvController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Carga masiva de usuarios'),
        content: TextField(
          controller: csvController,
          decoration: const InputDecoration(
            labelText:
                'Pega aquí los usuarios (nombre,usuario,correo,tipo) por línea',
            hintText: 'Ejemplo: Juan Perez,jperez,jperez@email.com,ADMIN',
          ),
          maxLines: 8,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final lines = csvController.text.trim().split('\n');
              for (final line in lines) {
                final parts = line.split(',');
                if (parts.length == 4) {
                  final nombre = parts[0].trim();
                  final usuario = parts[1].trim();
                  final correo = parts[2].trim();
                  final tipo = parts[3].trim();
                  if (nombre.isNotEmpty &&
                      usuario.isNotEmpty &&
                      correo.isNotEmpty &&
                      tipo.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(usuario)
                        .set({
                      'nombre': nombre,
                      'usuario': usuario,
                      'correo': correo,
                      'tipo': tipo
                    });
                  }
                }
              }
              Navigator.pop(ctx);
              _cargarUsuarios();
            },
            child: const Text('Cargar usuarios'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermisosPorTipo() {
    if (_cargandoPermisos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tiposUsuario.isEmpty) {
      return const Text('No hay tipos de usuario definidos.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...tiposUsuario.map((tipo) => Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tipo,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton(
                          onPressed: _guardarPermisosTipoUsuario,
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: paginasDisponibles.map((pagina) {
                        final checked = permisosPorTipo[tipo]?[pagina] ?? false;
                        return FilterChip(
                          label: Text(pagina),
                          selected: checked,
                          onSelected: (val) {
                            setState(() {
                              permisosPorTipo[tipo] ??= {};
                              permisosPorTipo[tipo]![pagina] = val;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
