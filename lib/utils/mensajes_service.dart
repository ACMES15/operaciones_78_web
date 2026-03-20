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
        final origenTipo = (data['origenTipo'] ?? '').toString().toUpperCase();
        final esAdmin = [
          'ADMIN',
          'ADMIN OMNICANAL',
          'ADMIN ENVIOS',
        ].contains(tipoUsuario.toUpperCase());
        // No leídos por este usuario
        final leidosPor = (data['leidosPor'] ?? []) as List;
        if (leidosPor.contains(usuario)) continue;
        final destino = (data['destino'] ?? '').toString();
        final destinoTipo =
            (data['destinoTipo'] ?? '').toString().toUpperCase();
        if (esAdmin) {
          // ADMIN solo ve mensajes enviados por NO ADMIN y dirigidos a ADMIN
          if (origenTipo.contains('ADMIN')) continue;
          if (!(destino == usuario ||
              destinoTipo.contains('ADMIN') ||
              destino == 'ADMIN' ||
              destino == 'TODOS' ||
              destinoTipo == 'TODOS')) continue;
        } else {
          // NO ADMIN solo ve mensajes enviados por ADMIN y dirigidos a ellos
          if (!origenTipo.contains('ADMIN')) continue;
          if (!(destino == usuario ||
              destinoTipo == tipoUsuario.toUpperCase() ||
              destino == 'TODOS' ||
              destinoTipo == 'TODOS')) continue;
        }
        count++;
      }
      return count;
    });
  }
}
