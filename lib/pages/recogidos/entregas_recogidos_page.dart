import 'package:flutter/material.dart';
import '../../utils/firebase_cache_utils.dart';
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
  const keys = [
    'fechaFirma',
    'createdAt',
    'fecha',
    'timestamp',
    'date',
    'fechaValidacion'
  ];
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
          SelectableText('${value ?? '-'}',
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, height: 1.15)),
        ],
      ),
    ),
  );
}

class EntregasRecogidosPage extends StatefulWidget {
  final String usuario;
  const EntregasRecogidosPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<EntregasRecogidosPage> createState() => _EntregasRecogidosPageState();
}

class _EntregasRecogidosPageState extends State<EntregasRecogidosPage> {
  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _sincronizarFirmasPendientes();
  }

  Future<void> _sincronizarFirmasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'firmas_pendientes_recogidos';
    final data = prefs.getString(key);
    if (data != null) {
      try {
        final List<dynamic> pendientes = jsonDecode(data);
        if (pendientes.isNotEmpty) {
          // Enviar pendientes a la subcolección 'firmas' en Firestore
          final firestore = FirebaseFirestore.instance;
          final batch = firestore.batch();
          final coll = firestore
              .collection('historial_entregas')
              .doc('recogidos_firmadas')
              .collection('firmas');
          for (final p in pendientes) {
            try {
              final dataMap = Map<String, dynamic>.from(p);
              if (dataMap.containsKey('__docId')) {
                final ref = coll.doc(dataMap['__docId']);
                batch.set(ref, Map.of(dataMap)..remove('__docId'));
              } else if (dataMap.containsKey('id')) {
                batch.set(coll.doc(dataMap['id']), dataMap);
              } else {
                final newDoc = coll.doc();
                batch.set(newDoc, dataMap);
              }
            } catch (_) {}
          }
          await batch.commit();
          await prefs.remove(key);
          await _cargarDatos(forzarFirestore: true);
        }
      } catch (_) {}
    }
  }

  final TextEditingController _lpController = TextEditingController();
  String _lpBusqueda = '';
  String _jefaturaSeleccionada = '';
  List<Map<String, dynamic>> _entregas = [];
  List<Map<String, dynamic>> _historialFirmadas = [];
  Set<int> _seleccionados = {};
  bool _cargando = true;

  Set<String> get _lpsFirmadas => _historialFirmadas
      .map((e) => e['LP']?.toString().replaceAll(' ', '').toUpperCase())
      .whereType<String>()
      .toSet();

  Future<void> _cargarDatos({bool forzarFirestore = false}) async {
    setState(() => _cargando = true);
    Map<String, dynamic>? entregasRaw;
    Map<String, dynamic>? historialRaw;
    if (forzarFirestore) {
      final entregasDoc = await FirebaseFirestore.instance
          .collection('entregas')
          .doc('recogidos')
          .get();
      entregasRaw = entregasDoc.exists ? entregasDoc.data() : {};
      final historialDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('recogidos_firmadas')
          .get();
      historialRaw = historialDoc.exists ? historialDoc.data() : {};
      await guardarDatosFirestoreYCache(
          'entregas', 'recogidos', entregasRaw ?? {});
      await guardarDatosFirestoreYCache(
          'historial_entregas', 'recogidos_firmadas', historialRaw ?? {});
      // Además, leer la subcolección 'firmas' y combinar
      try {
        final firmasSnap = await FirebaseFirestore.instance
            .collection('historial_entregas')
            .doc('recogidos_firmadas')
            .collection('firmas')
            .get();
        final List<Map<String, dynamic>> extra = firmasSnap.docs
            .map((d) => Map<String, dynamic>.from(d.data()))
            .toList();
        if (extra.isNotEmpty) {
          final existing = (historialRaw?['items'] is List)
              ? List<Map<String, dynamic>>.from((historialRaw?['items'] ?? []))
              : <Map<String, dynamic>>[];
          existing.addAll(extra);
          historialRaw = {'items': existing};
        }
      } catch (_) {}
    } else {
      entregasRaw = await leerDatosConCache('entregas', 'recogidos');
      historialRaw =
          await leerDatosConCache('historial_entregas', 'recogidos_firmadas');
      // Si el cache tiene 0 o 1 items, verificar directamente en Firestore
      try {
        final cachedItems =
            (entregasRaw != null && entregasRaw['items'] is List)
                ? List.from(entregasRaw['items'])
                : <dynamic>[];
        if (cachedItems.length <= 1) {
          final doc = await FirebaseFirestore.instance
              .collection('entregas')
              .doc('recogidos')
              .get();
          final fsItems = (doc.exists && doc.data()?['items'] is List)
              ? List.from(doc.data()!['items'])
              : <dynamic>[];
          if (fsItems.length > cachedItems.length) {
            entregasRaw = {'items': fsItems};
            await guardarDatosFirestoreYCache(
                'entregas', 'recogidos', entregasRaw);
          }
        }
      } catch (_) {}
      // Si el cache no contiene items, intentar leer subcolección 'firmas'
      if ((historialRaw == null || historialRaw['items'] == null)) {
        try {
          final firmasSnap = await FirebaseFirestore.instance
              .collection('historial_entregas')
              .doc('recogidos_firmadas')
              .collection('firmas')
              .get();
          final List<Map<String, dynamic>> extra = firmasSnap.docs
              .map((d) => Map<String, dynamic>.from(d.data()))
              .toList();
          if (extra.isNotEmpty) {
            historialRaw = {'items': extra};
            // actualizar cache con los items combinados
            await guardarDatosFirestoreYCache(
                'historial_entregas', 'recogidos_firmadas', historialRaw);
          }
        } catch (_) {}
      }
    }
    List<Map<String, dynamic>> entregas = [];
    if (entregasRaw != null && entregasRaw['items'] is List) {
      for (var e in (entregasRaw['items'] as List)) {
        if (e is Map) {
          entregas.add(Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }
    List<Map<String, dynamic>> historial = [];
    if (historialRaw != null && historialRaw['items'] is List) {
      for (var e in (historialRaw['items'] as List)) {
        if (e is Map) {
          historial.add(Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }
    setState(() {
      _entregas = entregas;
      _historialFirmadas = historial;
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _entregasFiltradas {
    final lpsFirmadas = _lpsFirmadas;
    final result = _entregas
        .where((e) => !lpsFirmadas
            .contains(e['LP']?.toString().replaceAll(' ', '').toUpperCase()))
        .where((e) =>
            _lpBusqueda.isEmpty ||
            (e['LP']?.toString().toLowerCase() ?? '')
                .contains(_lpBusqueda.toLowerCase()))
        .where((e) =>
            _jefaturaSeleccionada.isEmpty ||
            (e['JEFATURA']?.toString() ?? '') == _jefaturaSeleccionada)
        .toList();

    // Ordenar por fecha descendente (más nuevo primero)
    result.sort((a, b) {
      final fechaA = _fechaRegistro(a);
      final fechaB = _fechaRegistro(b);
      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;
      return fechaB.compareTo(fechaA);
    });

    return result;
  }

  Future<void> _firmarSeleccionados(BuildContext context) async {
    final seleccionadas =
        _seleccionados.map((idx) => _entregasFiltradas[idx]).toList();
    final lpsFirmadas = _lpsFirmadas;
    // Validar que ningún LP esté ya firmado
    final lpsSeleccionadas =
        seleccionadas.map((e) => e['LP']?.toString()).toSet();
    final lpsYaFirmadas = lpsSeleccionadas.intersection(lpsFirmadas);
    if (lpsYaFirmadas.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Al menos un LP ya fue firmado. Actualiza la lista.')));
      setState(() => _seleccionados.clear());
      return;
    }
    final mediaQuery = MediaQuery.of(context);
    final isMobile =
        mediaQuery.size.shortestSide <= 600 || mediaQuery.size.width < 700;
    final nombreController = TextEditingController();
    final signatureController = SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white);
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
    final ahora = DateTime.now();
    final nuevasFirmadas = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> preparados = [];
    try {
      // Preparar objetos nuevos y seleccionar ids
      preparados = [];
      final Set selectedIds = {};
      for (final e in seleccionadas) {
        final nuevo = {
          ...e,
          'nombreRecibe': resultado['nombre'],
          'firma': resultado['firma'],
          'fechaFirma': ahora.toIso8601String(),
          'usuarioEntrega': widget.usuario,
        };
        final docId = nuevo['id'] ??
            firestore
                .collection('historial_entregas')
                .doc('recogidos_firmadas')
                .collection('firmas')
                .doc()
                .id;
        nuevo['__docId'] = docId;
        preparados.add(nuevo);
        final idVal = nuevo['id'] ?? nuevo['ID'] ?? docId;
        if (idVal != null) selectedIds.add(idVal);
      }

      // Ejecutar transacción única: escribir firmas y eliminar solo ids seleccionados
      final entregasDocRef = firestore.collection('entregas').doc('recogidos');
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(entregasDocRef);
        final List items =
            List.from(snap.exists ? (snap.data()?['items'] ?? []) : []);
        final filtered = items
            .where((it) => !selectedIds
                .contains(it is Map ? (it['id'] ?? it['ID']) : null))
            .toList();
        tx.update(entregasDocRef, {'items': filtered});
        for (final nuevo in preparados) {
          final docRef = firestore
              .collection('historial_entregas')
              .doc('recogidos_firmadas')
              .collection('firmas')
              .doc(nuevo['__docId']);
          tx.set(docRef, Map.of(nuevo)..remove('__docId'));
        }
      });
      nuevasFirmadas
          .addAll(preparados.map((p) => Map.of(p)..remove('__docId')));
      setState(() {
        _seleccionados.clear();
      });
      await _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entregas firmadas y movidas a historial.'),
      ));
    } catch (e) {
      // Si falla la subida, guardar localmente como pendiente
      final prefs = await SharedPreferences.getInstance();
      final key = 'firmas_pendientes_recogidos';
      List<dynamic> pendientes = [];
      final data = prefs.getString(key);
      if (data != null) {
        try {
          pendientes = jsonDecode(data);
        } catch (_) {}
      }
      if (nuevasFirmadas.isNotEmpty) {
        pendientes.addAll(nuevasFirmadas);
      } else if (preparados.isNotEmpty) {
        pendientes.addAll(preparados.map((p) => Map.of(p)..remove('__docId')));
      }
      await prefs.setString(key, jsonEncode(pendientes));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No hay conexión. La firma se guardó localmente y se subirá cuando vuelva el internet.'),
        backgroundColor: Colors.orange,
      ));
      setState(() {
        _seleccionados.clear();
      });
      await _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final jefaturas = _entregasFiltradas
        .map((e) => (e['JEFATURA'] ?? '').toString())
        .where((j) => j.isNotEmpty)
        .toSet()
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: const Text('Entregas Recogidos',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar (forzar Firestore)',
            onPressed: () => _cargarDatos(forzarFirestore: true),
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
                            hintText: 'Buscar o escanear LP',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (v) {
                            setState(() => _lpBusqueda = v);
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
                        onChanged: (v) =>
                            setState(() => _jefaturaSeleccionada = v ?? ''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _entregasFiltradas.isEmpty
                        ? const Center(
                            child: Text('No hay entregas para mostrar.',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _entregasFiltradas.length,
                            itemBuilder: (context, index) {
                              final entrega = _entregasFiltradas[index];
                              final seleccionado =
                                  _seleccionados.contains(index);
                              final esFaltante =
                                  (entrega['BOX']?.toString().toUpperCase() ==
                                      'FALTANTE');
                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 7, horizontal: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: esFaltante
                                        ? Colors.red.shade300
                                        : const Color(0xFF2D6A4F),
                                    width: esFaltante ? 2.2 : 1.2,
                                  ),
                                ),
                                color:
                                    esFaltante ? Colors.red[50] : Colors.white,
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
                                      final fechaRegistro =
                                          _fechaRegistro(entrega);
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
                                                child: SelectableText(
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
                                                    _campoUniforme('CANTIDAD',
                                                        entrega['CANTIDAD'],
                                                        width: fieldWidth),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme('SECCION',
                                                        entrega['SECCION'],
                                                        width: fieldWidth),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme('JEFATURA',
                                                        entrega['JEFATURA'],
                                                        width: fieldWidth),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme(
                                                        'DESCRIPCION',
                                                        entrega['DESCRIPCION'],
                                                        width: maxWidth - 20),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme('VALIDACION',
                                                        entrega['VALIDACION'],
                                                        width: fieldWidth),
                                                    const SizedBox(height: 8),
                                                    _campoUniforme(
                                                        'Validado',
                                                        entrega['usuarioValido'] ??
                                                            '-',
                                                        width: fieldWidth),
                                                    if (esFaltante)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 8.0),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .red.shade100,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .red
                                                                    .shade400),
                                                          ),
                                                          child: const Text(
                                                            'FALTANTE',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                              letterSpacing:
                                                                  1.2,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
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
                                                    _campoUniforme('CANTIDAD',
                                                        entrega['CANTIDAD'],
                                                        width: fieldWidth),
                                                    _campoUniforme('SECCION',
                                                        entrega['SECCION'],
                                                        width: fieldWidth),
                                                    _campoUniforme('JEFATURA',
                                                        entrega['JEFATURA'],
                                                        width: fieldWidth),
                                                    _campoUniforme(
                                                        'DESCRIPCION',
                                                        entrega['DESCRIPCION'],
                                                        width: fieldWidth),
                                                    _campoUniforme('VALIDACION',
                                                        entrega['VALIDACION'],
                                                        width: fieldWidth),
                                                    _campoUniforme(
                                                        'Validado',
                                                        entrega['usuarioValido'] ??
                                                            '-',
                                                        width: fieldWidth),
                                                    if (esFaltante)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .red.shade100,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                              color: Colors.red
                                                                  .shade400),
                                                        ),
                                                        child: const Text(
                                                          'FALTANTE',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                            letterSpacing: 1.2,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                        ],
                                      );
                                    },
                                  ),
                                  subtitle: esFaltante
                                      ? const Text(
                                          'Este LP está marcado como FALTANTE',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13),
                                        )
                                      : null,
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

  @override
  void dispose() {
    _lpController.dispose();
    super.dispose();
  }
}
