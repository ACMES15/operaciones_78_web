import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

class HistorialEntregasCdrPage extends StatefulWidget {
  final String usuario;
  const HistorialEntregasCdrPage({Key? key, required this.usuario})
      : super(key: key);

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
    final isMobile = MediaQuery.of(context).size.shortestSide <= 600;
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => isMobile
          ? Dialog(
              insetPadding: const EdgeInsets.all(0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Firmar entregas',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D6A4F),
                                  fontSize: 22)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nombreController,
                            decoration: const InputDecoration(
                                labelText: 'Nombre de quien recibe',
                                border: OutlineInputBorder()),
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (value) {
                              final upper = value.toUpperCase();
                              if (value != upper) {
                                nombreController.value =
                                    nombreController.value.copyWith(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                      offset: upper.length),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text('Firma:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D6A4F))),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFF2D6A4F)),
                            ),
                            width: double.infinity,
                            height: 180,
                            child: Signature(
                              controller: signatureController,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => signatureController.clear(),
                              icon:
                                  const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Limpiar firma'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final firmaBytes =
                                      await signatureController.toPngBytes();
                                  if (nombreController.text.trim().isEmpty ||
                                      firmaBytes == null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Nombre y firma requeridos.')));
                                    return;
                                  }
                                  Navigator.of(ctx).pop({
                                    'nombre': nombreController.text
                                        .trim()
                                        .toUpperCase(),
                                    'firma': base64Encode(firmaBytes),
                                  });
                                },
                                child: const Text('Guardar'),
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : AlertDialog(
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
                            nombreController.value =
                                nombreController.value.copyWith(
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
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D6A4F))),
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
                    if (nombreController.text.trim().isEmpty ||
                        firmaBytes == null) {
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
      nuevaEntrega['usuarioEntrega'] = widget.usuario;
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
      final data = doc.data();
      data['id'] = doc.id;
      nuevos.add(data);
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
    // Implementar exportación a Excel si se requiere
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
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: const Text('ENTREGAS DE CDR',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar (forzar Firestore)',
            onPressed: _cargarDesdeFirestore,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 24, vertical: isMobile ? 8 : 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lpController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Buscar LP',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (v) {
                            setState(() => _lpBusqueda = v);
                            _aplicarFiltro();
                          },
                          onTap: () => _lpController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _lpController.text.length),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _jefaturaSeleccionada.isEmpty
                            ? null
                            : _jefaturaSeleccionada,
                        hint: const Text('Jefatura'),
                        isExpanded: false,
                        items: [
                          const DropdownMenuItem<String>(
                              value: '', child: Text('Todas')),
                          ...jefaturas
                              .map((j) =>
                                  DropdownMenuItem(value: j, child: Text(j)))
                              .toList(),
                        ],
                        onChanged: (v) {
                          setState(() => _jefaturaSeleccionada = v ?? '');
                          _aplicarFiltro();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _resultados.isEmpty
                        ? const Center(
                            child: Text('No hay entregas para mostrar.',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _resultados.length,
                            itemBuilder: (context, index) {
                              final entrega = _resultados[index];
                              final seleccionado =
                                  _seleccionados.contains(index);
                              final isFaltante = entrega['BOX'] == true ||
                                  entrega['BOX'] == 'true';
                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 7, horizontal: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFF2D6A4F),
                                    width: 1.2,
                                  ),
                                ),
                                color: isFaltante
                                    ? const Color(0xFFFFCDD2)
                                    : Colors.white,
                                child: CheckboxListTile(
                                  value: seleccionado,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _seleccionados.add(index);
                                      } else {
                                        _seleccionados.remove(index);
                                      }
                                    });
                                  },
                                  title: Row(
                                    children: [
                                      _infoChip('DOCTO', entrega['DOCUMENTO']),
                                      _infoChip('SKU', entrega['SKU']),
                                      _infoChip('CANT', entrega['CANTIDAD']),
                                      _infoChip('SECC', entrega['SECCION']),
                                      _infoChip('JEF', entrega['JEFATURA']),
                                      _infoChip('DESC', entrega['DESCRIPCION']),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (entrega['firma'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('Firma:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              SizedBox(
                                                height: 80,
                                                child: entrega['firma']
                                                        is String
                                                    ? Image.memory(
                                                        base64Decode(
                                                            entrega['firma']),
                                                        fit: BoxFit.contain,
                                                      )
                                                    : const Text(
                                                        'Firma no disponible'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (entrega['nombreRecibe'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                              'Recibió: ${entrega['nombreRecibe']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      if (entrega['fechaFirma'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2.0),
                                          child: Text(
                                              'Fecha: ${entrega['fechaFirma']}'),
                                        ),
                                    ],
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_seleccionados.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_document),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 244, 247, 245),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                        ),
                        label: const Text('Firmar seleccionados',
                            style: TextStyle(fontSize: 18)),
                        onPressed: () => _firmarSeleccionados(context),
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
