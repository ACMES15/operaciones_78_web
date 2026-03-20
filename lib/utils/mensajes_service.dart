import 'package:cloud_firestore/cloud_firestore.dart';

class MensajesService {
  static Stream<int> mensajesNoLeidosStream(
      String usuario, String tipoUsuario) {
    if (tipoUsuario == 'ADMIN') {
      return FirebaseFirestore.instance
          .collection('mensajes')
          .where('leido', isEqualTo: false)
          .snapshots()
          .map((snap) => snap.docs.length);
    } else {
      return FirebaseFirestore.instance
          .collection('mensajes')
          .where('leido', isEqualTo: false)
          .where('destino', isEqualTo: 'ADMIN')
          .snapshots()
          .map((snap) => snap.docs.length);
    }
  }
}
