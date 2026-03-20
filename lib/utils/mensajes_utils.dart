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

  static Future<List<Map<String, dynamic>>> obtenerUsuariosPorTipo(
      String tipo) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('tipo', isEqualTo: tipo)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  static Future<List<Map<String, dynamic>>> obtenerTodosUsuarios() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('usuarios').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
