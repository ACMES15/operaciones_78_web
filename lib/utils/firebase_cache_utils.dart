import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Guarda datos en Firestore y en cache local (SharedPreferences)
Future<void> guardarDatosFirestoreYCache(
    String coleccion, String docId, Map<String, dynamic> datos) async {
  try {
    await FirebaseFirestore.instance
        .collection(coleccion)
        .doc(docId)
        .set(datos);
  } catch (e, st) {
    print('Error guardando en Firestore: $e\n$st');
    rethrow;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${coleccion}_$docId';
    await prefs.setString(cacheKey, jsonEncode(datos));
  } catch (e, st) {
    print('Error guardando en cache local: $e\n$st');
  }
}

/// Lee datos primero del cache local, si no existen los busca en Firestore y los cachea
Future<Map<String, dynamic>?> leerDatosConCache(
    String coleccion, String docId) async {
  final prefs = await SharedPreferences.getInstance();
  final cacheKey = '${coleccion}_$docId';
  final cacheData = prefs.getString(cacheKey);
  if (cacheData != null) {
    return jsonDecode(cacheData);
  }
  final doc =
      await FirebaseFirestore.instance.collection(coleccion).doc(docId).get();
  if (doc.exists) {
    final data = doc.data() ?? {};
    await prefs.setString(cacheKey, jsonEncode(data));
    return data;
  }
  return null;
}

/// Elimina una entrada concreta del cache local (SharedPreferences).
Future<void> invalidateCache(String coleccion, String docId) async {
  final prefs = await SharedPreferences.getInstance();
  final realKey = '${coleccion}_$docId';
  if (prefs.containsKey(realKey)) await prefs.remove(realKey);
}

/// Elimina todas las entradas del cache que pertenezcan a una colección.
Future<void> invalidateCollectionCache(String coleccion) async {
  final prefs = await SharedPreferences.getInstance();
  final keys =
      prefs.getKeys().where((k) => k.startsWith('${coleccion}_')).toList();
  for (final k in keys) {
    await prefs.remove(k);
  }
}
