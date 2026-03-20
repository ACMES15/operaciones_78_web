import 'package:cloud_firestore/cloud_firestore.dart';

class MensajesService {
  static Stream<int> mensajesNoLeidosStream(
      String usuario, String tipoUsuario) {
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
        // Solo mensajes enviados por el otro grupo (ADMIN ve de no ADMIN, no ADMIN ve de ADMIN)
        final origenTipo = (data['origenTipo'] ?? '').toString().toUpperCase();
        final esAdmin = [
          'ADMIN',
          'ADMIN OMNICANAL',
          'ADMIN ENVIOS',
        ].contains(tipoUsuario.toUpperCase());
        if (esAdmin) {
          // ADMIN solo ve mensajes enviados por NO ADMIN
          if (origenTipo.contains('ADMIN')) continue;
        } else {
          // NO ADMIN solo ve mensajes enviados por ADMIN
          if (!origenTipo.contains('ADMIN')) continue;
        }
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
