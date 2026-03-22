import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({Key? key}) : super(key: key);

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  Future<List<Map<String, dynamic>>> _cargarNotificaciones() async {
    final doc = await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc('password')
        .get();
    if (!doc.exists || doc.data() == null) return [];
    final items = (doc.data()!['items'] ?? []) as List;
    return items.cast<Map<String, dynamic>>();
  }

  Future<void> _marcarAtendidoYResetear(int idx,
      List<Map<String, dynamic>> notificaciones, String? usuario) async {
    notificaciones[idx]['atendido'] = true;
    await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc('password')
        .set({'items': notificaciones});
    // Resetear contraseña si usuario es válido
    if (usuario != null && usuario.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario)
          .update({'password': usuario});
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones de Faltantes'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cargarNotificaciones(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notificaciones = snapshot.data!;
          final pendientes =
              notificaciones.where((n) => n['atendido'] != true).toList();
          if (pendientes.isEmpty) {
            return const Center(
                child: Text('No hay notificaciones pendientes.'));
          }
          return ListView.builder(
            itemCount: pendientes.length,
            itemBuilder: (context, idx) {
              final notif = pendientes[idx];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text(notif['mensaje'] ?? 'FALTANTE'),
                  subtitle: Text(
                      'Detalle: ${notif['detalle'] ?? ''}\nFecha: ${notif['fecha'] ?? ''}'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final indexInAll = notificaciones.indexOf(notif);
                      // Extraer usuario del mensaje o detalle
                      String? usuario;
                      // Buscar en campos comunes
                      if (notif['usuario'] != null) {
                        usuario = notif['usuario'];
                      } else {
                        // Intentar extraer del mensaje si está en formato conocido
                        final msg = (notif['mensaje'] ?? '').toString();
                        final match = RegExp(r"'([^']+)' solicita reseteo")
                            .firstMatch(msg);
                        if (match != null) {
                          usuario = match.group(1);
                        }
                      }
                      await _marcarAtendidoYResetear(
                          indexInAll, notificaciones, usuario);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Contraseña de $usuario reseteada.')),
                      );
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Atendido'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
