import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/mensajes_utils.dart';

class MensajesPage extends StatefulWidget {
  final String usuario;
  final String tipoUsuario;
  const MensajesPage(
      {Key? key, required this.usuario, required this.tipoUsuario})
      : super(key: key);

  @override
  State<MensajesPage> createState() => _MensajesPageState();
}

class _MensajesPageState extends State<MensajesPage> {
  final TextEditingController _mensajeController = TextEditingController();
  String? _usuarioDestino;
  List<String> _tiposUsuario = [];
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargandoTipos = false;
  bool _cargandoUsuarios = false;
  bool _enviando = false;
  bool _importante = false;

  bool get _esAdmin => [
        'ADMIN',
        'ADMIN OMNICANAL',
        'ADMIN ENVIOS',
      ].contains(widget.tipoUsuario);

  Stream<QuerySnapshot> get _mensajesStream {
    if (_esAdmin) {
      return FirebaseFirestore.instance
          .collection('mensajes')
          .orderBy('fecha', descending: true)
          .snapshots();
    } else {
      // Recibe mensajes dirigidos a su tipo, a TODOS, o a su nombre de usuario
      return FirebaseFirestore.instance
          .collection('mensajes')
          .where('destino',
              whereIn: [widget.tipoUsuario, 'TODOS', widget.usuario])
          .orderBy('fecha', descending: true)
          .snapshots();
    }
  }

  Future<void> _marcarComoLeidoPorUsuario(
      String id, List<dynamic> leidosPor) async {
    final nuevosLeidos = Set<String>.from(leidosPor)..add(widget.usuario);
    await FirebaseFirestore.instance
        .collection('mensajes')
        .doc(id)
        .update({'leidosPor': nuevosLeidos.toList()});
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    String destino = 'ADMIN';
    if (_esAdmin) {
      destino = _usuarioDestino ?? 'TODOS';
    }
    await FirebaseFirestore.instance.collection('mensajes').add({
      'mensaje': _mensajeController.text.trim(),
      'fecha': DateTime.now(),
      'origen': widget.usuario,
      'destino': destino,
      'leido': false,
      'importante': _esAdmin ? _importante : false,
    });
    _mensajeController.clear();
    setState(() => _enviando = false);
  }

  Future<void> _marcarComoLeido(String id) async {
    await FirebaseFirestore.instance
        .collection('mensajes')
        .doc(id)
        .update({'leido': true});
  }

  @override
  void initState() {
    super.initState();
    _eliminarMensajesExpirados();
    if (_esAdmin) {
      _cargarTiposUsuario();
      _cargarUsuarios();
    }
  }

  Future<void> _eliminarMensajesExpirados() async {
    final ahora = DateTime.now();
    final mensajes =
        await FirebaseFirestore.instance.collection('mensajes').get();
    for (final doc in mensajes.docs) {
      final data = doc.data();
      final fecha = data['fecha'];
      if (fecha is Timestamp) {
        final dt = fecha.toDate();
        final bool importante = data['importante'] == true;
        final duracion = Duration(hours: importante ? 24 : 12);
        if (ahora.difference(dt) > duracion) {
          await FirebaseFirestore.instance
              .collection('mensajes')
              .doc(doc.id)
              .delete();
        }
      }
    }
  }

  Future<void> _cargarTiposUsuario() async {
    setState(() => _cargandoTipos = true);
    final tipos = await MensajesUtils.obtenerTiposUsuario();
    setState(() {
      _tiposUsuario = tipos;
      _cargandoTipos = false;
    });
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargandoUsuarios = true);
    final usuarios = await MensajesUtils.obtenerTodosUsuarios();
    setState(() {
      _usuarios = usuarios;
      _cargandoUsuarios = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _mensajesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No hay mensajes.'));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final esAdmin = _esAdmin;
                    final esLeido = _esAdmin
                        ? data['leido'] == true
                        : (data['leidosPor'] != null &&
                            (data['leidosPor'] as List)
                                .contains(widget.usuario));
                    return Card(
                      color: esLeido ? Colors.white : Colors.red.shade50,
                      child: ListTile(
                        title: Row(
                          children: [
                            if (data['importante'] == true)
                              const Icon(Icons.priority_high,
                                  color: Colors.red, size: 18),
                            const SizedBox(width: 4),
                            Expanded(child: Text(data['mensaje'] ?? '')),
                          ],
                        ),
                        subtitle: Text(
                            'De: ${data['origen']}  Para: ${data['destino']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!esLeido && !_esAdmin)
                              IconButton(
                                icon: const Icon(Icons.mark_email_read,
                                    color: Colors.green),
                                tooltip: 'Leído',
                                onPressed: () => _marcarComoLeidoPorUsuario(
                                    docs[i].id, data['leidosPor'] ?? []),
                              ),
                            if (!esLeido && _esAdmin)
                              IconButton(
                                icon: const Icon(Icons.mark_email_read,
                                    color: Colors.green),
                                tooltip: 'Marcar como leído',
                                onPressed: () => _marcarComoLeido(docs[i].id),
                              ),
                            if (esAdmin) ...[
                              IconButton(
                                icon:
                                    const Icon(Icons.reply, color: Colors.blue),
                                tooltip: 'Responder',
                                onPressed: () {
                                  setState(() {
                                    _usuarioDestino = data['origen'];
                                    _mensajeController.text = '';
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.group,
                                    color: Colors.orange),
                                tooltip: 'Enviar grupal',
                                onPressed: () {
                                  setState(() {
                                    _usuarioDestino = 'TODOS';
                                    _mensajeController.text = '';
                                  });
                                },
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                if (_esAdmin)
                  Expanded(
                    flex: 2,
                    child: _cargandoTipos || _cargandoUsuarios
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _usuarioDestino,
                                hint: const Text('Destino'),
                                items: [
                                  const DropdownMenuItem(
                                      value: 'TODOS', child: Text('Todos')),
                                  ..._tiposUsuario.map((tipo) =>
                                      DropdownMenuItem(
                                          value: tipo,
                                          child: Text('Grupo: $tipo'))),
                                  ..._usuarios.map((u) => DropdownMenuItem(
                                      value: u['usuario'] ?? u['id'],
                                      child: Text(
                                          'Usuario: ${u['nombre'] ?? u['usuario'] ?? u['id']}'))),
                                ],
                                onChanged: (v) =>
                                    setState(() => _usuarioDestino = v),
                              ),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _importante,
                                    onChanged: _esAdmin
                                        ? (v) => setState(
                                            () => _importante = v ?? false)
                                        : null,
                                  ),
                                  const Text('Importante (24h)'),
                                ],
                              ),
                            ],
                          ),
                  ),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _mensajeController,
                    decoration: const InputDecoration(
                      labelText: 'Escribe un mensaje',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _enviando ? null : _enviarMensaje,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
