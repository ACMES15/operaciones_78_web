import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({Key? key}) : super(key: key);

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  List<Map<String, dynamic>>? _notificaciones;
  bool _cargando = false;

  Future<void> _cargarNotificaciones() async {
    setState(() {
      _cargando = true;
    });
    final doc = await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc('password')
        .get();
    if (!doc.exists || doc.data() == null) {
      setState(() {
        _notificaciones = [];
        _cargando = false;
      });
      return;
    }
    final items = (doc.data()!['items'] ?? []) as List;
    setState(() {
      _notificaciones = items.cast<Map<String, dynamic>>();
      _cargando = false;
    });
  }

  Future<void> _marcarAtendidoYResetear(int idx, String? usuario) async {
    if (_notificaciones == null) return;
    _notificaciones![idx]['atendido'] = true;
    await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc('password')
        .set({'items': _notificaciones});

    // Marcar como leída la notificación correspondiente en la colección principal (campana)
    final notif = _notificaciones![idx];
    final mensaje = notif['mensaje'] ?? '';
    final detalle = notif['detalle'] ?? '';
    final fecha = notif['fecha'] ?? '';
    final para = notif['usuario'] ?? '';
    if (mensaje.isNotEmpty && para.isNotEmpty && fecha.isNotEmpty) {
      final query = await FirebaseFirestore.instance
          .collection('notificaciones')
          .where('mensaje', isEqualTo: mensaje)
          .where('detalle', isEqualTo: detalle)
          .where('fecha', isEqualTo: fecha)
          .where('para', isEqualTo: para)
          .where('leida', isEqualTo: false)
          .get();
      for (final doc in query.docs) {
        await doc.reference.update({'leida': true});
      }
    }

    // Resetear contraseña si usuario es válido
    if (usuario != null && usuario.isNotEmpty) {
      final usuarioNormalizado = usuario.trim().toLowerCase();
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioNormalizado)
          .update({'password': usuarioNormalizado});
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
  }

  @override
  Widget build(BuildContext context) {
    final notificaciones = _notificaciones;
    final pendientes =
        (notificaciones ?? []).where((n) => n['atendido'] != true).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones de Faltantes'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : (pendientes.isEmpty
              ? const Center(child: Text('No hay notificaciones pendientes.'))
              : ListView.builder(
                  itemCount: pendientes.length,
                  itemBuilder: (context, idx) {
                    final notif = pendientes[idx];
                    final indexInAll = notificaciones!.indexOf(notif);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        title: Text(notif['mensaje'] ?? 'FALTANTE'),
                        subtitle: Text(
                            'Detalle: ${notif['detalle'] ?? ''}\nFecha: ${notif['fecha'] ?? ''}'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            // Extraer usuario del mensaje o detalle
                            String? usuario;
                            if (notif['usuario'] != null) {
                              usuario = notif['usuario'];
                            } else {
                              final msg = (notif['mensaje'] ?? '').toString();
                              final match =
                                  RegExp(r"'([^']+)' solicita reseteo")
                                      .firstMatch(msg);
                              if (match != null) {
                                usuario = match.group(1);
                              }
                            }
                            await _marcarAtendidoYResetear(indexInAll, usuario);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Contraseña de $usuario reseteada.')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: const Text('Atendido'),
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}
