import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MensajesDialog extends StatefulWidget {
  final String usuario;
  final bool isAdmin;
  const MensajesDialog({Key? key, required this.usuario, required this.isAdmin})
      : super(key: key);

  @override
  State<MensajesDialog> createState() => _MensajesDialogState();
}

class _MensajesDialogState extends State<MensajesDialog> {
  final TextEditingController _mensajeController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    await FirebaseFirestore.instance.collection('mensajes').add({
      'mensaje': _mensajeController.text.trim(),
      'usuario': widget.usuario,
      'fecha': DateTime.now(),
      'respondido': false,
      'paraTodos': false,
    });
    setState(() {
      _enviando = false;
      _mensajeController.clear();
    });
    Navigator.of(context).pop();
  }

  Future<void> _responderMensaje(
      String docId, String usuarioDestino, String respuesta,
      {bool paraTodos = false}) async {
    if (respuesta.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('mensajes').doc(docId).update({
      'respondido': true,
      'respuesta': respuesta,
      'respondidoPor': widget.usuario,
      'fechaRespuesta': DateTime.now(),
    });
    if (paraTodos) {
      // Mensaje grupal: crear un nuevo mensaje para todos
      await FirebaseFirestore.instance.collection('mensajes').add({
        'mensaje': respuesta,
        'usuario': widget.usuario,
        'fecha': DateTime.now(),
        'respondido': false,
        'paraTodos': true,
      });
    } else {
      // Mensaje individual: crear respuesta para el usuario
      await FirebaseFirestore.instance.collection('mensajes').add({
        'mensaje': respuesta,
        'usuario': usuarioDestino,
        'fecha': DateTime.now(),
        'respondido': false,
        'paraTodos': false,
        'respuestaDeAdmin': true,
      });
    }
    setState(() {});
  }

  Future<void> _marcarAtendido(String docId) async {
    await FirebaseFirestore.instance.collection('mensajes').doc(docId).update({
      'respondido': true,
      'respondidoPor': widget.usuario,
      'fechaRespuesta': DateTime.now(),
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.message, color: Color(0xFF2D6A4F), size: 28),
                const SizedBox(width: 12),
                const Text('Mensajes',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D6A4F))),
                const Spacer(),
                if (widget.isAdmin)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('mensajes')
                        .where('respondido', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final pendientes = snapshot.data?.docs ?? [];
                      if (pendientes.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pendientes.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (!widget.isAdmin) ...[
              TextField(
                controller: _mensajeController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Escribe tu mensaje',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _enviando ? null : _enviarMensaje,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white),
                label: const Text('Enviar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 140, 239, 194),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ] else ...[
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('mensajes')
                    .where('respondido', isEqualTo: false)
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No hay mensajes pendientes.')),
                    );
                  }
                  return SizedBox(
                    height: 340,
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final docId = docs[i].id;
                        final usuario = data['usuario'] ?? '';
                        final mensaje = data['mensaje'] ?? '';
                        final fecha =
                            data['fecha'] != null && data['fecha'] is Timestamp
                                ? (data['fecha'] as Timestamp).toDate()
                                : null;
                        final paraTodos = data['paraTodos'] == true;
                        final TextEditingController _respuestaController =
                            TextEditingController();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    paraTodos
                                        ? 'Mensaje grupal'
                                        : 'De: $usuario',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (fecha != null)
                                  Text(
                                    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F3F4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(mensaje,
                                  style: const TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _respuestaController,
                                    decoration: InputDecoration(
                                      hintText: paraTodos
                                          ? 'Responder a todos...'
                                          : 'Responder...',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _responderMensaje(docId, usuario,
                                        _respuestaController.text,
                                        paraTodos: paraTodos);
                                    _respuestaController.clear();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D6A4F),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  child: const Icon(Icons.send,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _marcarAtendido(docId),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: const BorderSide(
                                        color: Color(0xFF2D6A4F)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                  ),
                                  child: const Text('Atendido'),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }
}
