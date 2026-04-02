import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';

/// Sincroniza devoluciones de entregas/mkp a guias/mkp (solo las nuevas y sin guía)
Future<int> sincronizarDevolucionesMKP() async {
  // Leer devoluciones de entregas/mkp
  final docEntregas =
      await FirebaseFirestore.instance.collection('entregas').doc('mkp').get();
  final entregas = (docEntregas.data()?['items'] ?? []) as List;

  // Leer guias actuales
  final docGuias =
      await FirebaseFirestore.instance.collection('guias').doc('mkp').get();
  final guias = (docGuias.data()?['items'] ?? []) as List;

  // Solo devoluciones nuevas y sin guía
  final nuevas = entregas.where((e) {
    final dev = (e['devolucion_mkp'] ?? '').toString().trim();
    if (dev.isEmpty) return false;
    // No duplicar si ya existe en guias
    final yaExiste = guias.any((g) => (g['devolucion'] ?? '') == dev);
    return !yaExiste;
  }).toList();

  if (nuevas.isEmpty) return 0;

  // Agregar a guias
  final nuevaLista = List<Map<String, dynamic>>.from(guias);
  for (final n in nuevas) {
    nuevaLista.insert(0, {
      'devolucion': n['devolucion_mkp'] ?? '',
      'guia': '',
      'fecha': n['fecha'] ?? '',
    });
  }
  await guardarDatosFirestoreYCache('guias', 'mkp', {'items': nuevaLista});
  return nuevas.length;
}
