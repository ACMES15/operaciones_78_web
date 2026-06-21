import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_cache_utils.dart';

/// Sincroniza devoluciones de entregas/mkp a guias/mkp (solo las nuevas y sin guía)
Future<int> sincronizarDevolucionesMKP() async {
  final db = FirebaseFirestore.instance;

  // Leer en paralelo: entregas (legado + subcolección) y guías (legado + subcolección)
  final results = await Future.wait<dynamic>([
    db.collection('entregas').doc('mkp').get(),
    db.collection('entregas').doc('mkp').collection('items').get(),
    db.collection('guias').doc('mkp').get(),
    db.collection('guias').doc('mkp').collection('items').get(),
  ]);

  final docEntregas = results[0] as DocumentSnapshot<Map<String, dynamic>>;
  final subEntregas = results[1] as QuerySnapshot<Map<String, dynamic>>;
  final docGuias = results[2] as DocumentSnapshot<Map<String, dynamic>>;
  final subGuias = results[3] as QuerySnapshot<Map<String, dynamic>>;

  final entregasDoc = List<Map<String, dynamic>>.from(
    ((docEntregas.data()?['items'] ?? []) as List)
        .whereType<Map<String, dynamic>>(),
  );
  final entregasSub =
      subEntregas.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();

  final guiasDoc = List<Map<String, dynamic>>.from(
    ((docGuias.data()?['items'] ?? []) as List)
        .whereType<Map<String, dynamic>>(),
  );
  final guiasSub =
      subGuias.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();

  // Unificar entregas sin duplicar por (devolucion_mkp + fecha)
  final seenEntregas = <String>{};
  final entregas = <Map<String, dynamic>>[];
  for (final e in [...entregasSub, ...entregasDoc]) {
    final key = '${e['devolucion_mkp'] ?? ''}_${e['fecha'] ?? ''}';
    if (seenEntregas.add(key)) entregas.add(e);
  }

  // Devoluciones ya existentes en guías (doc + sub)
  final devolucionesGuias = <String>{
    ...guiasDoc
        .map((g) => (g['devolucion'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty),
    ...guiasSub
        .map((g) => (g['devolucion'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty),
  };

  // Solo devoluciones nuevas y sin guía
  final nuevas = entregas.where((e) {
    final dev = (e['devolucion_mkp'] ?? '').toString().trim();
    if (dev.isEmpty) return false;
    return !devolucionesGuias.contains(dev);
  }).toList();

  if (nuevas.isEmpty) return 0;

  // 1) Mantener doc legado para compatibilidad
  final nuevaLista = List<Map<String, dynamic>>.from(guiasDoc);
  for (final n in nuevas) {
    nuevaLista.insert(0, {
      'devolucion': n['devolucion_mkp'] ?? '',
      'guia': '',
      'fecha': n['fecha'] ?? '',
    });
  }
  await guardarDatosFirestoreYCache('guias', 'mkp', {'items': nuevaLista});

  // 2) Guardar también en subcolección nueva (lectura rápida en guias_mkp_page)
  final batch = db.batch();
  for (final n in nuevas) {
    final devolucion = (n['devolucion_mkp'] ?? '').toString().trim();
    if (devolucion.isEmpty) continue;
    final fecha = (n['fecha'] ?? '').toString();
    final docId = '${devolucion}_$fecha';
    final ref =
        db.collection('guias').doc('mkp').collection('items').doc(docId);
    batch.set(
        ref,
        {
          'devolucion': devolucion,
          'guia': '',
          'fecha': fecha,
        },
        SetOptions(merge: true));
  }
  await batch.commit();

  return nuevas.length;
}
