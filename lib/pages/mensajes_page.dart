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
  bool _cargandoTipos = false;
  bool _enviando = false;

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
      return FirebaseFirestore.instance
          .collection('mensajes')
          .where('destino', whereIn: [widget.tipoUsuario, 'TODOS'])
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
    await FirebaseFirestore.instance.collection('mensajes').add({
      'mensaje': _mensajeController.text.trim(),
      'fecha': DateTime.now(),
      'origen': widget.usuario,
      'destino': _esAdmin ? (_usuarioDestino ?? 'TODOS') : 'ADMIN',
      'leido': false,
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
    if (_esAdmin) _cargarTiposUsuario();
  }

  Future<void> _cargarTiposUsuario() async {
    setState(() => _cargandoTipos = true);
    final tipos = await MensajesUtils.obtenerTiposUsuario();
    setState(() {
      _tiposUsuario = tipos;
      _cargandoTipos = false;
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
                        title: Text(data['mensaje'] ?? ''),
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
                    child: _usuarioDestino != null &&
                            !_tiposUsuario.contains(_usuarioDestino!) &&
                            _usuarioDestino != 'TODOS'
                        ? TextFormField(
                            initialValue: _usuarioDestino,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Destino',
                              border: OutlineInputBorder(),
                            ),
                          )
                        : (_cargandoTipos
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<String>(
                                value: _usuarioDestino,
                                hint: const Text('Destino'),
                                items: [
                                  const DropdownMenuItem(
                                      value: 'TODOS', child: Text('Todos')),
                                  ..._tiposUsuario
                                      .map((tipo) => DropdownMenuItem(
                                          value: tipo, child: Text(tipo)))
                                      .toList(),
                                ],
                                onChanged: (v) =>
                                    setState(() => _usuarioDestino = v),
                              )),
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
