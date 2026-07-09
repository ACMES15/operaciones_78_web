import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventarioHistoricoPage extends StatefulWidget {
  const InventarioHistoricoPage({Key? key}) : super(key: key);

  @override
  State<InventarioHistoricoPage> createState() =>
      _InventarioHistoricoPageState();
}

class _InventarioHistoricoPageState extends State<InventarioHistoricoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Histórico Inventarios',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventarios_historico')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty)
            return const Center(
                child: Text('No hay auditorías guardadas',
                    style: TextStyle(color: Colors.white)));
          final docs = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final jefe = data['jefe']?.toString() ?? 'Desconocido';
              final created = (data['createdAt'] is Timestamp)
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null;
              final percent = (data['percentScanned'] is num)
                  ? (data['percentScanned'] as num).toDouble()
                  : ((data['percentScanned'] is double)
                      ? data['percentScanned']
                      : 0.0);
              final quality = (data['qualityScore'] is num)
                  ? (data['qualityScore'] as num).toDouble()
                  : 0.0;

              return Card(
                color: Colors.white,
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  onTap: () => _openDetails(context, data),
                  title: Text('$jefe',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.black)),
                  subtitle: Text(created != null ? created.toString() : '',
                      style: const TextStyle(color: Colors.black54)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(percent * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      Text('Calidad ${quality.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
        context: context,
        builder: (ctx) {
          final skus = <MapEntry<String, dynamic>>[];
          if (data['skus'] is Map) {
            (data['skus'] as Map).forEach((k, v) {
              skus.add(MapEntry(k.toString(), v));
            });
          }
          final percent = (data['percentScanned'] is num)
              ? (data['percentScanned'] as num).toDouble()
              : 0.0;
          final quality = (data['qualityScore'] is num)
              ? (data['qualityScore'] as num).toDouble()
              : 0.0;

          return AlertDialog(
            title: Text('Resultado - ${data['jefe'] ?? 'Jefe'}'),
            content: SizedBox(
              width: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            'Escaneado: ${data['totalScanned'] ?? 0} / ${data['totalPdis'] ?? 0}')),
                    Text('${(percent * 100).toStringAsFixed(1)}%')
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: Text('Calidad: ${quality.toStringAsFixed(1)}%'))
                  ]),
                  const SizedBox(height: 12),
                  // mostrar respuestas del formulario q1..q4
                  if (data['q1'] != null ||
                      data['q2'] != null ||
                      data['q3'] != null ||
                      data['q4'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Respuestas:'),
                        const SizedBox(height: 6),
                        Text(
                            '1) Mercancía identificada con SKU y PDIS?: ${data['q1'] == true ? 'Sí' : 'No'}'),
                        Text(
                            '2) Se tuvo faltante en el primer escaneo?: ${data['q2'] == true ? 'Sí' : 'No'}'),
                        Text(
                            '3) Hay mercancía dañada?: ${data['q3'] == true ? 'Sí' : 'No'}'),
                        Text(
                            '4) Hay mercancía en bodega?: ${data['q4'] == true ? 'Sí' : 'No'}'),
                        const SizedBox(height: 12),
                      ],
                    ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('SKUs'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: ListView.builder(
                      itemCount: skus.length,
                      itemBuilder: (context, i) {
                        final k = skus[i].key;
                        final v = skus[i].value;
                        final pdis = (v is Map && v['pdis'] != null)
                            ? v['pdis'].toString()
                            : '';
                        final scanned = (v is Map && v['scanned'] != null)
                            ? v['scanned'].toString()
                            : '0';
                        return ListTile(
                          dense: true,
                          title: Text(k),
                          trailing: SizedBox(
                              width: 140,
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(pdis),
                                    const SizedBox(width: 12),
                                    Text(scanned)
                                  ])),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'))
            ],
          );
        });
  }
}
