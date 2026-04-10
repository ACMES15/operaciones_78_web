import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EntregasCycPage extends StatefulWidget {
  final String usuario;
  const EntregasCycPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EntregasCycPage> createState() => _EntregasCycPageState();
}

class _EntregasCycPageState extends State<EntregasCycPage> {
  String _jefaturaSeleccionada = '';
  List<Map<String, dynamic>> _pendientes = [];
  List<Map<String, dynamic>> _originales = [];
  bool _cargando = true;
  Set<int> _seleccionados = {};
  late TextEditingController _busquedaController;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _cargarPendientes();
    _sincronizarFirmasPendientes();
  }

  Future<void> _sincronizarFirmasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'firmas_pendientes_cyc';
    final data = prefs.getString(key);
    if (data != null) {
      try {
        final List<dynamic> pendientes = jsonDecode(data);
        if (pendientes.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          final historialRef =
              firestore.collection('historial_entregas').doc('cyc_firmadas');
          final historialDoc = await historialRef.get();
          List<dynamic> historial = [];
          if (historialDoc.exists &&
              historialDoc.data() != null &&
              historialDoc.data()!['items'] is List) {
            historial = List.from(historialDoc.data()!['items']);
          }
          historial.addAll(pendientes.cast<Map<String, dynamic>>());
          await historialRef.set({'items': historial}, SetOptions(merge: true));
          await prefs.remove(key);
          await _cargarPendientes();
        }
      } catch (_) {}
    }
  }

  Future<void> _cargarPendientes() async {
    setState(() => _cargando = true);
    final snap =
        await FirebaseFirestore.instance.collection('entregas_cyc').get();
    final docs = snap.docs;
    final List<Map<String, dynamic>> nuevos = docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    setState(() {
      _pendientes = nuevos;
      _originales = nuevos;
      _cargando = false;
      _seleccionados.clear();
    });
  }

  void _filtrar(String value) {
    setState(() {
      _filtro = value.toLowerCase();
      _pendientes = _originales
          .where((e) => e.entries.any((entry) {
                final v = entry.value;
                if (v == null) return false;
                return v.toString().toLowerCase().contains(_filtro);
              }))
          .toList();
    });
  }

  Future<void> _firmarSeleccionados(BuildContext context) async {
    final seleccionadas =
        _seleccionados.map((idx) => _pendientes[idx]).toList();
    final nombreController = TextEditingController();
    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
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
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('Limpiar firma'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    final firmaBytes = await signatureController.toPngBytes();
                    if (nombreController.text.trim().isEmpty ||
                        firmaBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Nombre y firma requeridos.')));
                      return;
                    }
                    Navigator.of(context).pop({
                      'nombre': nombreController.text.trim().toUpperCase(),
                      'firma': base64Encode(firmaBytes),
                    });
                  },
                  child: const Text('Guardar'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
    );
    if (resultado == null) return;
    final nombre = resultado['nombre'] as String;
    final firma = resultado['firma'] as String;
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final historialRef =
        firestore.collection('historial_entregas').doc('cyc_firmadas');
    final historialDoc = await historialRef.get();
    List<dynamic> historial = [];
    if (historialDoc.exists &&
        historialDoc.data() != null &&
        historialDoc.data()!['items'] is List) {
      historial = List.from(historialDoc.data()!['items']);
    }
    final ahora = DateTime.now();
    final nuevasFirmadas = <Map<String, dynamic>>[];
    for (final item in seleccionadas) {
      final nuevo = Map<String, dynamic>.from(item);
      nuevo['validadoPor'] = widget.usuario;
      nuevo['fechaValidacion'] = ahora.toIso8601String();
      nuevo['recibidoPor'] = nombre;
      nuevo['firma'] = firma;
      historial.add(nuevo);
      nuevasFirmadas.add(nuevo);
      batch.delete(firestore.collection('entregas_cyc').doc(item['id']));
    }
    try {
      batch.set(historialRef, {'items': historial}, SetOptions(merge: true));
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entregas firmadas y movidas a historial.')));
      await _cargarPendientes();
    } catch (e) {
      // Si falla la subida, guardar localmente como pendiente
      final prefs = await SharedPreferences.getInstance();
      final key = 'firmas_pendientes_cyc';
      List<dynamic> pendientes = [];
      final data = prefs.getString(key);
      if (data != null) {
        try {
          pendientes = jsonDecode(data);
        } catch (_) {}
      }
      pendientes.addAll(nuevasFirmadas);
      await prefs.setString(key, jsonEncode(pendientes));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No hay conexión. La firma se guardó localmente y se subirá cuando vuelva el internet.'),
        backgroundColor: Colors.orange,
      ));
      await _cargarPendientes();
    }
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // Obtener todas las jefaturas únicas de los pendientes
    final jefaturas = _pendientes
        .map((e) => (e['JEFATURA'] ?? '').toString())
        .where((j) => j.isNotEmpty)
        .toSet()
        .toList();
    // Filtrado visual y por jefatura
    final resultados = _pendientes
        .where((e) =>
            (_filtro.isEmpty ||
                e.entries.any((entry) {
                  final v = entry.value;
                  if (v == null) return false;
                  return v.toString().toLowerCase().contains(_filtro);
                })) &&
            (_jefaturaSeleccionada.isEmpty ||
                (e['JEFATURA']?.toString() ?? '') == _jefaturaSeleccionada))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: const Text('Entregas CyC',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargarPendientes,
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
                          controller: _busquedaController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Buscar o escanear CyC',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: _filtrar,
                          onTap: () => _busquedaController.selection =
                              TextSelection(
                                  baseOffset: 0,
                                  extentOffset:
                                      _busquedaController.text.length),
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
                        onChanged: (v) =>
                            setState(() => _jefaturaSeleccionada = v ?? ''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: resultados.isEmpty
                        ? const Center(
                            child: Text('No hay entregas para mostrar.',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)))
                        : ListView.builder(
                            itemCount: resultados.length,
                            itemBuilder: (context, index) {
                              final entrega = resultados[index];
                              final seleccionado =
                                  _seleccionados.contains(index);
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
                                color: Colors.white,
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
                                  title: isMobile
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _mobileField('NUMERO DE PEDIDO',
                                                entrega['NUMERO DE PEDIDO']),
                                            _mobileField('SKU', entrega['SKU']),
                                            _mobileField('LP', entrega['LP']),
                                            _mobileField('CANTIDAD',
                                                entrega['CANTIDAD']),
                                            _mobileField(
                                                'SECCION', entrega['SECCION']),
                                            _mobileField('JEFATURA',
                                                entrega['JEFATURA']),
                                            _mobileField('DESCRIPCION',
                                                entrega['DESCRIPCION']),
                                            _mobileField('Valido',
                                                entrega['validadoPor'] ?? '-'),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            _infoChip(
                                                'NUMERO DE PEDIDO',
                                                entrega['NUMERO DE PEDIDO'] ??
                                                    entrega[
                                                        'NUMERO DE PEDIDO']),
                                            _infoChip('SKU', entrega['SKU']),
                                            _infoChip('LP', entrega['LP']),
                                            _infoChip(
                                                'CANT', entrega['CANTIDAD']),
                                            _infoChip(
                                                'SECC', entrega['SECCION']),
                                            _infoChip(
                                                'JEF', entrega['JEFATURA']),
                                            _infoChip(
                                                'DESC', entrega['DESCRIPCION']),
                                            _infoChip('Valido',
                                                entrega['validadoPor'] ?? '-'),
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

  Widget _mobileField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
              child: Text('${value ?? '-'}',
                  style: const TextStyle(fontSize: 16))),
        ],
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
