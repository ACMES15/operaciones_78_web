import 'package:cloud_firestore/cloud_firestore.dart';

Future<List<List<String>>> obtenerSkusLigadosHojaDeRuta(
    String numeroControl) async {
  final doc = await FirebaseFirestore.instance
      .collection('hoja_ruta_skus')
      .doc(numeroControl)
      .get();
  if (doc.exists && doc.data() != null && doc.data()!['skus'] != null) {
    final List<dynamic> skus = doc.data()!['skus'];
    return skus.map<List<String>>((col) => List<String>.from(col)).toList();
  }
  return [];
}

String skusToTexto(List<List<String>> skus) {
  // Convierte la matriz de SKUs a texto tabular para copiar
  final buffer = StringBuffer();
  final maxRows = skus.isNotEmpty
      ? skus.map((col) => col.length).reduce((a, b) => a > b ? a : b)
      : 0;
  for (int r = 0; r < maxRows; r++) {
    for (int c = 0; c < skus.length; c++) {
      if (c > 0) buffer.write('\t');
      final col = skus[c];
      buffer.write(r < col.length ? col[r] : '');
    }
    if (r < maxRows - 1) buffer.write('\n');
  }
  return buffer.toString();
}
