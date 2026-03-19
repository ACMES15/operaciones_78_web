import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agregar_tipo_usuario_widget.dart';

// Define the StatefulWidget for this State class
class UserControlPageBody extends StatefulWidget {
  const UserControlPageBody({Key? key}) : super(key: key);

  @override
  _UserControlPageBodyState createState() => _UserControlPageBodyState();
}

class _UserControlPageBodyState extends State<UserControlPageBody> {
  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
    _cargarPermisosTipoUsuario();
  }

  String? tipoSeleccionadoPermisos;
  // Estado
  String _busqueda = '';
  // Tipos de usuario predefinidos
  final List<String> tiposUsuarioFijos = [
    'ADMIN',
    'ADMIN ENVIOS',
    'ADMIN OMNICANAL',
    'STAFF XD',
    'STAFF ENVIOS',
    'JEFATURA',
    'PREVENCION',
    'VENTAS',
    'INVENTARIOS',
    'MESADEBODAS',
  ];
  List<String> tiposUsuario = [];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _permisosKey = GlobalKey();
  List<Map<String, dynamic>> usuarios = [];

  Map<String, Map<String, bool>> permisosPorTipo = {};
  bool _cargandoPermisos = true;
  // Las páginas disponibles se obtendrán dinámicamente desde HomePage
  List<String> get paginasDisponibles {
    // Debe coincidir con el menú de HomePage
    return [
      'Control de usuarios',
      'Hoja de ruta',
      'Hoja de XD',
      'Historial Hoja de XD',
      'Carta Porte',
      'Historial Carta Porte',
      'Plantilla Ejecutiva',
      'DevCan',
      'Dev Mbodas',
      'Dev XD',
      'Historial Entregas DevCan',
      'Recogidos',
      'Historial Entregas Recogidos',
      'Entregas CDR',
      'Historial De Entregas CDR',
      'Historial Entregas Dev Mbodas',
      'Historial Entregas XD',
      'Dev CyC',
    ];
  }

// --- Widget para agregar un nuevo tipo de usuario ---
  Future<void> _cargarUsuarios() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('usuarios').get();
    final nuevosUsuarios =
        snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    // Unificar tipos de usuario de usuarios y permisos
    final tiposUsuariosDeUsuarios = nuevosUsuarios
        .map((u) => (u['tipo'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toSet();
    final tiposUsuariosDePermisos = permisosPorTipo.keys.toSet();
    final todosLosTipos = {
      ...tiposUsuariosDeUsuarios,
      ...tiposUsuariosDePermisos
    }.toList()
      ..sort();
    setState(() {
      usuarios = nuevosUsuarios;
      tiposUsuario = todosLosTipos;
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
    String tipoSeleccionado = usuario['tipo'] ?? tiposUsuarioFijos.first;
    bool activo = usuario['activo'] ?? true;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar usuario'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: tipoSeleccionado,
                items: tiposUsuarioFijos
                    .map((tipo) => DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setStateDialog(() => tipoSeleccionado = val);
                },
                decoration: const InputDecoration(labelText: 'Tipo de usuario'),
              ),
              Row(
                children: [
                  Checkbox(
                    value: activo,
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => activo = val);
                    },
                  ),
                  const Text('Activo')
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (tipoSeleccionado.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(usuarioKey)
                    .update({'tipo': tipoSeleccionado, 'activo': activo});
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
      final nuevosPermisos =
          data.map((k, v) => MapEntry(k, Map<String, bool>.from(v)));
      // Unificar tipos de usuario de usuarios y permisos
      final tiposUsuariosDeUsuarios = usuarios
          .map((u) => (u['tipo'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toSet();
      final tiposUsuariosDePermisos = nuevosPermisos.keys.toSet();
      final todosLosTipos = {
        ...tiposUsuariosDeUsuarios,
        ...tiposUsuariosDePermisos
      }.toList()
        ..sort();
      setState(() {
        permisosPorTipo = nuevosPermisos;
        tiposUsuario = todosLosTipos;
        _cargandoPermisos = false;
      });
    } else {
      final tiposUsuariosDeUsuarios = usuarios
          .map((u) => (u['tipo'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toSet();
      setState(() {
        permisosPorTipo = {};
        tiposUsuario = tiposUsuariosDeUsuarios.toList()..sort();
        _cargandoPermisos = false;
      });
    }
  }

  Future<void> _guardarPermisosTipoUsuario() async {
    if (tipoSeleccionadoPermisos == null) return;
    final docRef = FirebaseFirestore.instance
        .collection('permisos_tipo_usuario')
        .doc('permisos');
    final doc = await docRef.get();
    Map<String, dynamic> data = {};
    if (doc.exists) {
      // Protección: si doc.data() es null, usar mapa vacío
      data = Map<String, dynamic>.from(doc.data() ?? {});
    }
    // Actualizar solo el tipo seleccionado
    data[tipoSeleccionadoPermisos!] =
        permisosPorTipo[tipoSeleccionadoPermisos!];
    await docRef.set(data);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos guardados en Firestore')));
    _cargarPermisosTipoUsuario();
  }

  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final horizontalPadding = isWide ? 32.0 : 8.0;
        final fontSize = isWide ? 18.0 : 14.0;
        return SingleChildScrollView(
          controller: _scrollController,
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gestión de usuarios',
                      style: TextStyle(
                          fontSize: fontSize + 2, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('Ir a permisos'),
                    onPressed: () {
                      Scrollable.ensureVisible(
                        _permisosKey.currentContext!,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Agregar usuario'),
                    onPressed: _agregarUsuario,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Carga masiva'),
                    onPressed: _agregarMasivo,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minWidth: 300,
                  maxWidth: isWide ? 1200 : double.infinity,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: isWide ? 32 : 12,
                    columns: [
                      DataColumn(
                          label: Text('Nombre',
                              style: TextStyle(fontSize: fontSize))),
                      DataColumn(
                          label: Text('Usuario',
                              style: TextStyle(fontSize: fontSize))),
                      DataColumn(
                          label: Text('Correo',
                              style: TextStyle(fontSize: fontSize))),
                      DataColumn(
                          label: Text('Tipo de usuario',
                              style: TextStyle(fontSize: fontSize))),
                      DataColumn(
                          label: Text('Activo',
                              style: TextStyle(fontSize: fontSize))),
                      DataColumn(
                          label: Text('Acciones',
                              style: TextStyle(fontSize: fontSize))),
                    ],
                    rows: _usuariosFiltrados.map((u) {
                      return DataRow(cells: [
                        DataCell(Text(u['nombre'] ?? '',
                            style: TextStyle(fontSize: fontSize))),
                        DataCell(Text(u['usuario'] ?? '',
                            style: TextStyle(fontSize: fontSize))),
                        DataCell(Text(u['correo'] ?? '',
                            style: TextStyle(fontSize: fontSize))),
                        DataCell(Text(u['tipo'] ?? '',
                            style: TextStyle(fontSize: fontSize))),
                        DataCell(Checkbox(
                          value: u['activo'] ?? true,
                          onChanged: (val) async {
                            await FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(u['id'])
                                .update({'activo': val ?? true});
                            _cargarUsuarios();
                          },
                        )),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () => _editarTipoPorUsuario(u['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar',
                              onPressed: () =>
                                  _eliminarUsuarioPorUsuario(u['id']),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(thickness: 2),
              const SizedBox(height: 12),
              Text('Permisos por tipo de usuario',
                  style: TextStyle(
                      fontSize: fontSize + 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                key: _permisosKey,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildPermisosPorTipo(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // --- Permisos por tipo de usuario ---

// --- Widget para agregar un nuevo tipo de usuario ---

// Declaración movida al final del archivo

  void _agregarUsuario() {
    final nombreController = TextEditingController();
    final usuarioController = TextEditingController();
    final correoController = TextEditingController();
    String tipoSeleccionado = tiposUsuarioFijos.first;
    bool activo = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar usuario'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
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
              DropdownButtonFormField<String>(
                value: tipoSeleccionado,
                items: tiposUsuarioFijos
                    .map((tipo) => DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setStateDialog(() => tipoSeleccionado = val);
                },
                decoration: const InputDecoration(labelText: 'Tipo de usuario'),
              ),
              Row(
                children: [
                  Checkbox(
                    value: activo,
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => activo = val);
                    },
                  ),
                  const Text('Activo')
                ],
              ),
            ],
          ),
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
              final tipo = tipoSeleccionado;
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
                  'tipo': tipo,
                  'activo': activo,
                  'password': usuario // Contraseña inicial igual al usuario
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
                'Pega aquí los usuarios (nombre,usuario,correo,tipo,activo) por línea',
            hintText: 'Ejemplo: Juan Perez,jperez,jperez@email.com,ADMIN,true',
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
                if (parts.length >= 4) {
                  final nombre = parts[0].trim();
                  final usuario = parts[1].trim();
                  final correo = parts[2].trim();
                  final tipo = parts[3].trim();
                  final activo = parts.length > 4
                      ? (parts[4].trim().toLowerCase() == 'true')
                      : true;
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
                      'tipo': tipo,
                      'activo': activo
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
    if (tiposUsuarioFijos.isEmpty) {
      return const Text('No hay tipos de usuario definidos.');
    }
    if (paginasDisponibles.isEmpty) {
      return const Text('No hay páginas disponibles.');
    }
    // Dropdown para seleccionar tipo de usuario
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Tipo de usuario: ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: tipoSeleccionadoPermisos ?? tiposUsuarioFijos.first,
              items: tiposUsuarioFijos
                  .map((tipo) => DropdownMenuItem(
                        value: tipo,
                        child: Text(tipo),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  tipoSeleccionadoPermisos = val;
                });
              },
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
              onPressed: _cargarPermisosTipoUsuario,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (tipoSeleccionadoPermisos != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecciona las páginas que puede ver:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...paginasDisponibles.map((pagina) {
                final checked =
                    permisosPorTipo[tipoSeleccionadoPermisos]?[pagina] ?? false;
                return CheckboxListTile(
                  title: Text(pagina),
                  value: checked,
                  onChanged: (val) {
                    setState(() {
                      permisosPorTipo[tipoSeleccionadoPermisos!] ??= {};
                      permisosPorTipo[tipoSeleccionadoPermisos!]![pagina] =
                          val ?? false;
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar permisos'),
                onPressed: _guardarPermisosTipoUsuario,
              ),
            ],
          ),
      ],
    );
  }
}
