import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:excel/excel.dart' as excel;

class GuiasCycHistorialPage extends StatefulWidget {
  final String usuario;
  const GuiasCycHistorialPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<GuiasCycHistorialPage> createState() => _GuiasCycHistorialPageState();
}

class _GuiasCycHistorialPageState extends State<GuiasCycHistorialPage> {
  bool _descargando = false;

  Future<void> _descargarExcel(List<QueryDocumentSnapshot> guias) async {
    setState(() => _descargando = true);
    final excel.Excel excelFile = excel.Excel.createExcel();
    final sheet = excelFile['GuiasCYC'];
    sheet.appendRow(['Guía', 'Fecha', 'Hora', 'Usuario']);
    for (final doc in guias) {
      final data = doc.data() as Map<String, dynamic>;
      sheet.appendRow([
        data['guia'] ?? '',
        data['fecha'] ?? '',
        data['hora'] ?? '',
        data['usuario'] ?? '',
      ]);
    }
    final bytes = excelFile.encode()!;
    final blob = html.Blob([bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'historial_guias_cyc.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
    setState(() => _descargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final pink = const Color(0xFFF06292);
    final darkPink = const Color(0xFFD81B60);
    final bg = const Color(0xFFFCE4EC);
    final border = const Color(0xFFF8BBD0);
    final titleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 28,
      color: darkPink,
      letterSpacing: 1.2,
    );
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: pink,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.white, size: 30),
            const SizedBox(width: 10),
            Text('Historial de Guias CYC',
                style: titleStyle.copyWith(color: Colors.white)),
            const Spacer(),
            IconButton(
              icon: _descargando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download, color: Colors.white, size: 28),
              tooltip: 'Descargar Excel',
              onPressed: _descargando
                  ? null
                  : () async {
                      final snapshot = await FirebaseFirestore.instance
                          .collection('guias_cyc')
                          .orderBy('fecha', descending: true)
                          .get();
                      final guias = snapshot.docs;
                      if (guias.isNotEmpty) await _descargarExcel(guias);
                    },
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('guias_cyc')
            .orderBy('fecha', descending: true)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay guías registradas.'));
          }
          final guias = snapshot.data!.docs;
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: pink.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(pink),
                headingTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return pink.withOpacity(0.18);
                    }
                    return null;
                  },
                ),
                columns: const [
                  DataColumn(label: Center(child: Text('Guía'))),
                  DataColumn(label: Center(child: Text('Fecha'))),
                  DataColumn(label: Center(child: Text('Hora'))),
                  DataColumn(label: Center(child: Text('Usuario'))),
                ],
                rows: guias.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(
                    cells: [
                      DataCell(Center(
                          child: Text(data['guia'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)))),
                      DataCell(Center(child: Text(data['fecha'] ?? ''))),
                      DataCell(Center(child: Text(data['hora'] ?? ''))),
                      DataCell(Center(child: Text(data['usuario'] ?? ''))),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
