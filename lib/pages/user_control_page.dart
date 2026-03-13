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
  bool _tieneCambios = false;
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

  @override
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
      final tipo = (u['tipo'] ?? '').toString().toLowerCase();
      return id.contains(filtro) || tipo.contains(filtro);
    }).toList();
  }

  // Métodos CRUD usuario (esqueleto)
  Future<void> _agregarUsuario() async {
    final emailController = TextEditingController();
    final tipoController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email')),
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
              final email = emailController.text.trim();
              final tipo = tipoController.text.trim();
              if (email.isNotEmpty && tipo.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(email)
                    .set({'tipo': tipo});
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

  Future<void> _agregarMasivo() async {
    // Implementación opcional: puedes abrir un diálogo para pegar varios emails/tipos
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

  Future<void> _restablecerPasswordPorUsuario(String usuarioKey) async {
    // Implementación opcional: puedes enviar un correo de reseteo usando Firebase Auth
  }

  Future<void> _guardarCambios() async {
    // Si tienes cambios en batch, puedes implementarlo aquí
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

  Widget _buildPermisosPorTipo() {
    if (_cargandoPermisos) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      );
    }
    if (permisosPorTipo.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No hay permisos configurados.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Permisos por tipo de usuario',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Tipo')),
              ...paginasDisponibles.map((p) => DataColumn(label: Text(p))),
            ],
            rows: tiposUsuario.map((tipo) {
              return DataRow(cells: [
                DataCell(Text(tipo)),
                ...paginasDisponibles.map((pagina) {
                  final checked = permisosPorTipo[tipo]?[pagina] ?? false;
                  return DataCell(Checkbox(
                    value: checked,
                    onChanged: (val) {
                      setState(() {
                        permisosPorTipo[tipo]![pagina] = val ?? false;
                      });
                    },
                  ));
                }).toList(),
              ]);
            }).toList(),
          ),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: _guardarPermisosTipoUsuario,
              child: const Text('Guardar permisos'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar por usuario o tipo',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _busqueda = value),
          ),
        ),
        Expanded(
          child: _usuariosFiltrados.isEmpty
              ? const Center(child: Text('No hay usuarios'))
              : ListView.builder(
                  itemCount: _usuariosFiltrados.length,
                  itemBuilder: (ctx, i) {
                    final u = _usuariosFiltrados[i];
                    return ListTile(
                      title: Text(u['id'] ?? ''),
                      subtitle: Text('Tipo: ${u['tipo'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editarTipoPorUsuario(u['id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                _eliminarUsuarioPorUsuario(u['id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _agregarUsuario,
                child: const Text('Agregar usuario'),
              ),
              const SizedBox(width: 16),
              // ElevatedButton(
              //   onPressed: _agregarMasivo,
              //   child: const Text('Agregar masivo'),
              // ),
            ],
          ),
        ),
        _buildPermisosPorTipo(),
      ],
    );
  }
}
