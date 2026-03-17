import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' as ex;

class HistorialEntregasCdrPage extends StatefulWidget {
  const HistorialEntregasCdrPage({Key? key}) : super(key: key);

  @override
  State<HistorialEntregasCdrPage> createState() =>
      _HistorialEntregasCdrPageState();
}

class _HistorialEntregasCdrPageState extends State<HistorialEntregasCdrPage> {
  List<Map<String, dynamic>> _resultados = [];
  List<Map<String, dynamic>> _datosOriginales = [];
  late TextEditingController _lpController;
  String _lpBusqueda = '';
  String _jefaturaSeleccionada = '';
  bool _cargando = true;
  Set<int> _seleccionados = {};

  Future<void> _firmarSeleccionados(BuildContext context) async {
    final seleccionadas =
        _seleccionados.map((idx) => _resultados[idx]).toList();
    final nombreController = TextEditingController();
    final signatureController = SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white);
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Firmar entregas',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F))),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre de quien recibe',
                      border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    final upper = value.toUpperCase();
                    if (value != upper) {
                      nombreController.value = nombreController.value.copyWith(
                        text: upper,
                        selection:
                            TextSelection.collapsed(offset: upper.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Firma:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F))),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF2D6A4F)),
                  ),
                  width: double.infinity,
                  height: 140,
                  child: Signature(
                    controller: signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => signatureController.clear(),
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Limpiar firma'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final firmaBytes = await signatureController.toPngBytes();
              if (nombreController.text.trim().isEmpty || firmaBytes == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Nombre y firma requeridos.')));
                return;
              }
              Navigator.of(ctx).pop({
                'nombre': nombreController.text.trim().toUpperCase(),
                'firma': base64Encode(firmaBytes),
              });
            },
            child: const Text('Guardar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    signatureController.dispose();
    if (resultado == null) return;

    final firestore = FirebaseFirestore.instance;
    // 1. Actualizar los datos firmados y eliminarlos de entregas_cdr
    for (final entrega in seleccionadas) {
      final docRef =
          firestore.collection('entregas_cdr').doc(entrega['id']?.toString());
      final nuevaEntrega = Map<String, dynamic>.from(entrega);
      nuevaEntrega['nombreRecibe'] = resultado['nombre'];
      nuevaEntrega['firma'] = resultado['firma'];
      nuevaEntrega['fechaFirma'] = DateTime.now().toIso8601String();
      // Eliminar el id para evitar conflictos en el historial
      nuevaEntrega.remove('id');
      await docRef.delete();

      // 2. Agregar al historial de firmadas
      final historialDoc =
          firestore.collection('historial_entregas').doc('cdr_firmadas');
      final historialSnap = await historialDoc.get();
      List<dynamic> historial = [];
      if (historialSnap.exists &&
          historialSnap.data() != null &&
          historialSnap.data()!['items'] is List) {
        historial = List.from(historialSnap.data()!['items']);
      }
      historial.add(nuevaEntrega);
      await historialDoc.set({'items': historial});
    }
    setState(() => _seleccionados.clear());
    await _cargarDesdeFirestore();
  }

  @override
  void initState() {
    super.initState();
    _lpController = TextEditingController();
    _cargarDesdeFirestore();
  }

  Future<void> _cargarDesdeFirestore() async {
    setState(() => _cargando = true);
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('entregas_cdr').get();
    final docs = snapshot.docs;
    List<Map<String, dynamic>> nuevos = [];
    for (final doc in docs) {
      nuevos.add(doc.data());
    }
    _datosOriginales = List<Map<String, dynamic>>.from(nuevos);
    _aplicarFiltro();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('historial_entregas_cdr', jsonEncode(nuevos));
    setState(() => _cargando = false);
  }

  void _aplicarFiltro() {
    setState(() {
      _resultados = _datosOriginales
          .where((e) =>
              (_lpBusqueda.isEmpty ||
                  (e['LP']?.toString().toLowerCase() ?? '')
                      .contains(_lpBusqueda.toLowerCase())) &&
              (_jefaturaSeleccionada.isEmpty ||
                  (e['JEFATURA']?.toString() ?? '') == _jefaturaSeleccionada))
          .toList();
    });
  }

  void _descargarExcel() {
    // Exportar los resultados actuales a Excel
    final excel = ex.Excel.createExcel();
    final sheet = excel['Historial'];
    if (_resultados.isNotEmpty) {
      final allKeys = <String>{};
      for (final row in _resultados) {
        allKeys.addAll(row.keys);
      }
      final orderedKeys = allKeys.toList();
      sheet.appendRow(orderedKeys);
      for (final row in _resultados) {
        final rowValues = orderedKeys.map((k) => row[k] ?? '').toList();
        sheet.appendRow(rowValues);
      }
    }
    final bytes = excel.encode();
    if (bytes != null) {
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'historial_entregas_cdr.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  void dispose() {
    _lpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final jefaturas = _resultados
        .map((e) => (e['JEFATURA'] ?? '').toString())
        .where((j) => j.isNotEmpty)
        .toSet()
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.fact_check, color: Color(0xFF2D6A4F), size: 30),
            const SizedBox(width: 10),
            const Text(
              'Historial Entregas CDR',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2D6A4F)),
            onPressed: _cargarDesdeFirestore,
            tooltip: 'Actualizar desde Firestore',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF2D6A4F)),
            onPressed: _descargarExcel,
            tooltip: 'Descargar Excel',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _lpController,
              decoration: const InputDecoration(
                labelText: 'Buscar por cualquier campo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => _lpBusqueda = v);
                _aplicarFiltro();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _resultados.isEmpty
                  ? const Center(child: Text('No hay entregas para mostrar.'))
                  : ListView.separated(
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _resultados.length,
                      itemBuilder: (context, index) {
                        final entrega = _resultados[index];
                        final dynamic firmaData = entrega['firma'];
                        Widget? firmaWidget;
                        if (firmaData != null) {
                          try {
                            Uint8List? bytes;
                            if (firmaData is Uint8List) {
                              bytes = firmaData;
                            } else if (firmaData is List<int>) {
                              bytes = Uint8List.fromList(firmaData);
                            } else if (firmaData is String) {
                              bytes = Uint8List.fromList(
                                  const Base64Decoder().convert(firmaData));
                            }
                            if (bytes != null && bytes.isNotEmpty) {
                              firmaWidget = Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    bytes,
                                    width: 70,
                                    height: 40,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            }
                          } catch (_) {}
                        }
                        final isFaltante = entrega['BOX'] == true;
                        return Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          color: isFaltante
                              ? const Color(0xFFFFCDD2)
                              : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isFaltante
                                          ? Colors.red[300]
                                          : const Color(0xFF2D6A4F),
                                      child: const Icon(Icons.fact_check,
                                          color: Colors.white),
                                    ),
                                    if (firmaWidget != null) firmaWidget,
                                  ],
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'DOC: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700]),
                                          ),
                                          Text(
                                            entrega['DOCUMENTO']?.toString() ??
                                                '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Color(0xFF2D6A4F)),
                                          ),
                                          const Spacer(),
                                          Icon(Icons.calendar_today,
                                              size: 18,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            entrega['fechaFirma'] != null
                                                ? entrega['fechaFirma']
                                                    .toString()
                                                    .substring(0, 10)
                                                : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF495057)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 6),
                                          Text(
                                            (entrega['nombreRecibe']
                                                        ?.toString() ??
                                                    '-')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'SKU: \\${entrega['SKU'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Descripción: \\${entrega['DESCRIPCION'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Cantidad: \\${entrega['CANTIDAD'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Sección: \\${entrega['SECCION'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      Text(
                                        'Jefatura: \\${entrega['JEFATURA'] ?? '-'}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF495057)),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.verified_user,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 6),
                                          Text(
                                              'Validó: ' +
                                                  (entrega['usuarioValido']
                                                          ?.toString() ??
                                                      '-'),
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF495057))),
                                          const SizedBox(width: 16),
                                          const Icon(Icons.person_outline,
                                              size: 18,
                                              color: Color(0xFF2D6A4F)),
                                          const SizedBox(width: 6),
                                          Text(
                                              'Entregó: ' +
                                                  (entrega['usuarioEntrega']
                                                          ?.toString() ??
                                                      '-'),
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF495057))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, dynamic value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D6A4F)),
      ),
      child: Text('$label: ${value ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
