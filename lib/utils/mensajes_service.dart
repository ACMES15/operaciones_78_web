import 'package:cloud_firestore/cloud_firestore.dart';

class MensajesService {
  static Stream<int> mensajesNoLeidosStream(
      String usuario, String tipoUsuario) {
    // ADMIN nunca ve badge
    if ([
      'ADMIN',
      'ADMIN OMNICANAL',
      'ADMIN ENVIOS',
    ].contains(tipoUsuario)) {
      return Stream.value(0);
    }
    return FirebaseFirestore.instance
        .collection('mensajes')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) {
      final ahora = DateTime.now();
      int count = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Expiración
        final fecha = data['fecha'];
        if (fecha is Timestamp) {
          final dt = fecha.toDate();
          final importante = data['importante'] == true;
          final duracion = Duration(hours: importante ? 24 : 12);
          if (ahora.difference(dt) > duracion) continue;
        }
        // Solo mensajes enviados por ADMIN
        final origenTipo = (data['origenTipo'] ?? '').toString().toUpperCase();
        if (!origenTipo.contains('ADMIN')) continue;
        // No leídos por este usuario
        final leidosPor = (data['leidosPor'] ?? []) as List;
        if (leidosPor.contains(usuario)) continue;
        // Destino: usuario, grupo o todos
        final destino = (data['destino'] ?? '').toString();
        final destinoTipo =
            (data['destinoTipo'] ?? '').toString().toUpperCase();
        if (destino == usuario ||
            destinoTipo == tipoUsuario.toUpperCase() ||
            destino == 'TODOS' ||
            destinoTipo == 'TODOS') {
          count++;
        }
      }
      return count;
    });
  }
}
