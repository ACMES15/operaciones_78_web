import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is Map && value['_seconds'] != null) {
    final sec = (value['_seconds'] is num ? value['_seconds'] : 0);
    final nsec = (value['_nanoseconds'] is num ? value['_nanoseconds'] : 0);
    return DateTime.fromMillisecondsSinceEpoch(
        sec.toInt() * 1000 + (nsec / 1000000).round());
  }
  return null;
}

DateTime? _fechaRegistro(Map<String, dynamic> entrega) {
  const keys = ['fechaValidacion', 'createdAt', 'fecha', 'timestamp', 'date'];
  for (final key in keys) {
    final dt = _toDate(entrega[key]);
    if (dt != null) return dt;
  }
  return null;
}

String _formatearFecha(dynamic value) {
  final dt = _toDate(value);
  if (dt == null) return '-';
  final local = dt.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

Widget _campoUniforme(String label, dynamic value, {double? width}) {
  return SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2D6A4F).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D6A4F),
                  letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text('${value ?? '-'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, height: 1.15)),
        ],
      ),
    ),
  );
}

class EntregasCycPage extends StatefulWidget {
  final String usuario;
  const EntregasCycPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EntregasCycPage> createState() => _EntregasCycPageState();
}

class _EntregasCycPageState extends State<EntregasCycPage> {
  String _jefaturaSeleccionada = '';
  List<Map<String, dynamic>> _pendientes = [];
  bool _cargando = true;
  Set<int> _seleccionados = {}; // índices de la lista filtrada
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
      _cargando = false;
      _seleccionados.clear();
    });
  }

  void _filtrar(String value) {
    setState(() {
      _filtro = value.toLowerCase();
      // No modificamos _pendientes, solo el filtro visual
      _seleccionados.clear();
    });
  }

  Future<void> _firmarSeleccionados(BuildContext context) async {
    // Usar los índices de la lista filtrada (resultados)
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
    final seleccionadas = _seleccionados.map((idx) => resultados[idx]).toList();
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
    final ahora = DateTime.now();
    final nuevasFirmadas = <Map<String, dynamic>>[];
    try {
      for (final item in seleccionadas) {
        final nuevo = Map<String, dynamic>.from(item);
        nuevo['validadoPor'] = widget.usuario;
        nuevo['fechaValidacion'] = ahora.toIso8601String();
        nuevo['recibidoPor'] = nombre;
        nuevo['firma'] = firma;
        final docId = nuevo['id'] ??
            firestore
                .collection('historial_entregas')
                .doc('cyc_firmadas')
                .collection('firmas')
                .doc()
                .id;
        await firestore
            .collection('historial_entregas')
            .doc('cyc_firmadas')
            .collection('firmas')
            .doc(docId)
            .set(nuevo);
        await firestore.collection('entregas_cyc').doc(nuevo['id']).delete();
        nuevasFirmadas.add(nuevo);
      }
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

    // Ordenar por fecha descendente (más nuevo primero)
    resultados.sort((a, b) {
      final fechaA = _fechaRegistro(a);
      final fechaB = _fechaRegistro(b);
      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;
      return fechaB.compareTo(fechaA);
    });

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
                              final fechaRegistro = _fechaRegistro(entrega);
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
                                  title: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final maxWidth = constraints.maxWidth;
                                      final isMobileLayout = maxWidth < 600;
                                      final fieldWidth = isMobileLayout
                                          ? ((maxWidth - 20) / 2)
                                              .clamp(140.0, 220.0)
                                          : 160.0;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (fechaRegistro != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8.0),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE9F5EC),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF2D6A4F),
                                                  ),
                                                ),
                                                child: Text(
                                                  _formatearFecha(
                                                      fechaRegistro),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          isMobileLayout
                                              ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _campoUniforme(
                                                        'LP', entrega['LP'],
                                                        width: fieldWidth),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme(
                                                        'SKU', entrega['SKU'],
                                                        width: fieldWidth),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme(
                                                        'DESCRIPCION',
                                                        entrega['DESCRIPCION'],
                                                        width: maxWidth - 20),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme('JEFATURA',
                                                        entrega['JEFATURA'],
                                                        width: fieldWidth),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme(
                                                        'Validado',
                                                        entrega['validadoPor'] ??
                                                            '-',
                                                        width: fieldWidth),
                                                  ],
                                                )
                                              : Wrap(
                                                  spacing: 10,
                                                  runSpacing: 8,
                                                  children: [
                                                    _campoUniforme(
                                                        'LP', entrega['LP'],
                                                        width: fieldWidth),
                                                    _campoUniforme(
                                                        'SKU', entrega['SKU'],
                                                        width: fieldWidth),
                                                    _campoUniforme(
                                                        'DESCRIPCION',
                                                        entrega['DESCRIPCION'],
                                                        width: fieldWidth),
                                                    _campoUniforme('JEFATURA',
                                                        entrega['JEFATURA'],
                                                        width: fieldWidth),
                                                    _campoUniforme(
                                                        'Validado',
                                                        entrega['validadoPor'] ??
                                                            '-',
                                                        width: fieldWidth),
                                                  ],
                                                ),
                                        ],
                                      );
                                    },
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
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
}
