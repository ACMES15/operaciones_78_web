import 'package:cloud_firestore/cloud_firestore.dart';

class MensajesUtils {
  static Future<List<String>> obtenerTiposUsuario() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('usuarios').get();
    final tipos = snapshot.docs
        .map((doc) => (doc.data()['tipo'] ?? '').toString())
        .where((tipo) => tipo.isNotEmpty)
        .toSet()
        .toList();
    tipos.sort();
    return tipos;
  }
}
