import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _enviando = false;

  Stream<QuerySnapshot> get _mensajesStream {
    if (widget.tipoUsuario == 'ADMIN') {
      return FirebaseFirestore.instance
          .collection('mensajes')
          .orderBy('fecha', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('mensajes')
          .where('destino', isEqualTo: 'ADMIN')
          .orderBy('fecha', descending: true)
          .snapshots();
    }
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    await FirebaseFirestore.instance.collection('mensajes').add({
      'mensaje': _mensajeController.text.trim(),
      'fecha': DateTime.now(),
      'origen': widget.usuario,
      'destino': widget.tipoUsuario == 'ADMIN'
          ? (_usuarioDestino ?? 'TODOS')
          : 'ADMIN',
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
                    final esAdmin = widget.tipoUsuario == 'ADMIN';
                    final esLeido = data['leido'] == true;
                    return Card(
                      color: esLeido ? Colors.white : Colors.red.shade50,
                      child: ListTile(
                        title: Text(data['mensaje'] ?? ''),
                        subtitle: Text(
                            'De: ${data['origen']}  Para: ${data['destino']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!esLeido)
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
                if (widget.tipoUsuario == 'ADMIN')
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _usuarioDestino,
                      hint: const Text('Destino'),
                      items: const [
                        DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                        // Aquí podrías cargar usuarios dinámicamente
                      ],
                      onChanged: (v) => setState(() => _usuarioDestino = v),
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
