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
    // Siempre traer todos los mensajes y filtrar en el builder
    return FirebaseFirestore.instance
        .collection('mensajes')
        .orderBy('fecha', descending: true)
        .snapshots();
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
    String destinoTipo = 'ADMIN';
    if (_esAdmin) {
      destino = _usuarioDestino ?? 'TODOS';
      // Buscar tipo de usuario del destinatario si es individual
      if (_usuarioDestino != null && _usuarioDestino != 'TODOS') {
        final usuario = _usuarios.firstWhere(
          (u) => u['usuario'] == _usuarioDestino || u['id'] == _usuarioDestino,
          orElse: () => {},
        );
        destinoTipo = usuario['tipo'] ?? destino;
      } else if (_usuarioDestino == 'TODOS') {
        destinoTipo = 'TODOS';
      } else {
        destinoTipo = destino;
      }
    }
    await FirebaseFirestore.instance.collection('mensajes').add({
      'mensaje': _mensajeController.text.trim(),
      'fecha': DateTime.now(),
      'origen': widget.usuario,
      'origenTipo': widget.tipoUsuario,
      'destino': destino,
      'destinoTipo': destinoTipo,
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

  int _contarNoLeidos(List<QueryDocumentSnapshot> docs) {
    if (_esAdmin) return 0;
    int count = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final esLeido = data['leidosPor'] != null &&
          (data['leidosPor'] as List).contains(widget.usuario);
      if (!esLeido) count++;
    }
    return count;
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
        title: const Text(
          'Mensajes',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: 1.2,
            color: Color.fromARGB(255, 238, 247, 243),
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 129, 234, 187),
        elevation: 4,
        centerTitle: true,
        actions: [],
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
                    if (esAdmin) {
                      // Solo mostrar mensajes dirigidos a ADMIN (usuario, grupo o todos los ADMIN)
                      final destino = (data['destino'] ?? '').toString();
                      final destinoTipo =
                          (data['destinoTipo'] ?? '').toString().toUpperCase();
                      if (!(destino == widget.usuario ||
                          destinoTipo.contains('ADMIN') ||
                          destino == 'ADMIN' ||
                          destino == 'TODOS' ||
                          destinoTipo == 'TODOS')) {
                        return const SizedBox.shrink();
                      }
                    } else {
                      // Solo mostrar mensajes que NO sean para ADMIN
                      final destino = (data['destino'] ?? '').toString();
                      final destinoTipo =
                          (data['destinoTipo'] ?? '').toString().toUpperCase();
                      if (destino == 'ADMIN' || destinoTipo.contains('ADMIN')) {
                        return const SizedBox.shrink();
                      }
                      String normaliza(String s) =>
                          s.toString().toLowerCase().replaceAll(' ', '');
                      final tipoUsuarioNorm = normaliza(widget.tipoUsuario);
                      final usuarioNorm = normaliza(widget.usuario);
                      final destinoNorm = normaliza(data['destino'] ?? '');
                      final destinoTipoNorm =
                          normaliza(data['destinoTipo'] ?? '');
                      final origenTipoNorm =
                          (data['origenTipo'] ?? '').toString().toUpperCase();
                      final esMensajeParaGrupo =
                          destinoNorm == tipoUsuarioNorm ||
                              destinoTipoNorm == tipoUsuarioNorm;
                      final esMensajeParaTodos =
                          destinoNorm == 'todos' || destinoTipoNorm == 'todos';
                      final esMensajeIndividual = destinoNorm == usuarioNorm ||
                          destinoTipoNorm == usuarioNorm;
                      // Solo mostrar mensajes de origen ADMIN si el destino es válido para el usuario
                      final esMensajeDeAdmin = [
                            'ADMIN',
                            'ADMIN OMNICANAL',
                            'ADMIN ENVIOS'
                          ].contains(origenTipoNorm) &&
                          (esMensajeParaGrupo ||
                              esMensajeParaTodos ||
                              esMensajeIndividual);
                      if (!(esMensajeParaGrupo ||
                          esMensajeParaTodos ||
                          esMensajeIndividual ||
                          esMensajeDeAdmin)) {
                        return const SizedBox.shrink();
                      }
                    }
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'De: ${data['origen']}  Para: ${data['destino']}'),
                            if (_esAdmin &&
                                data['leidosPor'] != null &&
                                (data['leidosPor'] as List).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Leído por: ' +
                                      (data['leidosPor'] as List).join(', '),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.green),
                                ),
                              ),
                          ],
                        ),
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
