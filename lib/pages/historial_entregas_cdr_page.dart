import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
// ...existing code...
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistorialEntregasCdrPage extends StatefulWidget {
  final String usuario;
  const HistorialEntregasCdrPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<HistorialEntregasCdrPage> createState() =>
      _HistorialEntregasCdrPageState();
}

class _HistorialEntregasCdrPageState extends State<HistorialEntregasCdrPage> {
  // ...existing code...

  Future<void> _sincronizarFirmasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'firmas_pendientes_cdr';
    final data = prefs.getString(key);
    if (data != null) {
      try {
        final List<dynamic> pendientes = jsonDecode(data);
        if (pendientes.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          final historialDoc =
              firestore.collection('historial_entregas').doc('cdr_firmadas');
          final historialSnap = await historialDoc.get();
          List<dynamic> historial = [];
          if (historialSnap.exists &&
              historialSnap.data() != null &&
              historialSnap.data()!['items'] is List) {
            historial = List.from(historialSnap.data()!['items']);
          }
          historial.addAll(pendientes.cast<Map<String, dynamic>>());
          await historialDoc.set({'items': historial});
          await prefs.remove(key);
          await _cargarDesdeHiveYFirestore();
        }
      } catch (e, stack) {
        // Mostrar el error en consola para web y debug
        // ignore: avoid_print
        print('Error al sincronizar firmas pendientes: ' + e.toString());
        // ignore: avoid_print
        print(stack);
      }
    }
  }

  Future<void> _guardarFirmas(List<Map<String, dynamic>> nuevasFirmadas) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final col = firestore
          .collection('historial_entregas')
          .doc('cdr_firmadas')
          .collection('firmas');
      for (final reg in nuevasFirmadas) {
        final docRef = col.doc(reg['id'] ?? UniqueKey().toString());
        // Agregar usuario que entrega
        reg['usuarioEntrego'] = widget.usuario;
        await docRef.set(Map<String, dynamic>.from(reg));
        // Eliminar de Hive y de la lista local de pendientes
        await _hiveHistorial.delete(reg['id']);
      }
      // Actualizar la lista local
      _datosOriginales
          .removeWhere((e) => nuevasFirmadas.any((r) => r['id'] == e['id']));
      setState(() {
        _seleccionados.clear();
        _aplicarFiltro();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Firmas guardadas en Firestore y eliminadas de pendientes.')),
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error al guardar en Firestore: ' + e.toString());
      // ignore: avoid_print
      print(stack);
      for (final reg in nuevasFirmadas) {
        await _hiveHistorial.put(reg['id'], reg);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar en Firestore: ' +
                e.toString() +
                '\nLa firma se guardó localmente y se subirá cuando vuelva el internet.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Sincroniza firmas locales pendientes con Firestore
  Future<void> sincronizarFirmasLocales() async {
    if (!mounted || _hiveHistorial.isEmpty) return;
    final firestore = FirebaseFirestore.instance;
    final col = firestore
        .collection('historial_entregas')
        .doc('cdr_firmadas')
        .collection('firmas');
    bool huboCambios = false;
    for (final reg in _hiveHistorial.values) {
      final docId = reg['id'] ?? UniqueKey().toString();
      final docRef = col.doc(docId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        await docRef.set(Map<String, dynamic>.from(reg));
        huboCambios = true;
      }
    }
    if (huboCambios && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Firmas locales sincronizadas con Firestore.')),
      );
    }
  }

  // Busca el valor de un campo por variantes de nombre
  dynamic _getCampoFlexible(
      Map<String, dynamic> entrega, List<String> variantes) {
    for (final key in entrega.keys) {
      final keyNorm = key.replaceAll(' ', '').replaceAll('_', '').toLowerCase();
      for (final variante in variantes) {
        final varianteNorm =
            variante.replaceAll(' ', '').replaceAll('_', '').toLowerCase();
        if (keyNorm == varianteNorm) {
          return entrega[key];
        }
      }
    }
    return null;
  }

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
    if (resultado != null) {
      // Agregar datos de firma a cada entrega seleccionada
      final fechaFirma = DateTime.now().toIso8601String();
      final nuevasFirmadas = seleccionadas.map((entrega) {
        final reg = Map<String, dynamic>.from(entrega);
        reg['nombreRecibe'] = resultado['nombre'];
        reg['firma'] = resultado['firma'];
        reg['fechaFirma'] = fechaFirma;
        reg['id'] = reg['id'] ?? UniqueKey().toString();
        return reg;
      }).toList();
      await _guardarFirmas(nuevasFirmadas);
    }
  }

  // Caja Hive para historial local
  late Box<Map> _hiveHistorial;

  @override
  void initState() {
    super.initState();
    _lpController = TextEditingController();
    Hive.openBox<Map>('historial_entregas_cdr').then((box) {
      setState(() {
        _hiveHistorial = box;
      });
      _cargarDesdeHiveYFirestore();
      sincronizarFirmasLocales();
    });
    _sincronizarFirmasPendientes();
  }

  // Cargar historial: primero local, luego intenta sincronizar con Firestore
  Future<void> _cargarDesdeHiveYFirestore() async {
    setState(() => _cargando = true);
    // 1. Cargar local (Hive)
    final List<Map<String, dynamic>> local = _hiveHistorial.values
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // 2. Cargar pendientes de Firestore (entregas_cdr)
    List<Map<String, dynamic>> firestorePendientes = [];
    try {
      final firestore = FirebaseFirestore.instance;
      final snap = await firestore.collection('entregas_cdr').get();
      firestorePendientes = snap.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (_) {}

    // 3. Cargar ids ya firmados en Firestore
    Set idsFirmados = {};
    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('historial_entregas')
          .doc('cdr_firmadas')
          .collection('firmas')
          .get();
      idsFirmados = querySnapshot.docs.map((doc) => doc.id).toSet();
    } catch (_) {}

    // 4. Unir locales y Firestore, quitar duplicados por id
    final Map<String, Map<String, dynamic>> todos = {};
    for (final e in [...local, ...firestorePendientes]) {
      if (e['id'] != null && !idsFirmados.contains(e['id'])) {
        todos[e['id'].toString()] = e;
      }
    }
    _datosOriginales = todos.values.toList();
    _aplicarFiltro();
    if (mounted) setState(() => _cargando = false);
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

  // ...existing code...

  @override
  void dispose() {
    _lpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile =
        mediaQuery.size.shortestSide <= 600 || mediaQuery.size.width < 700;
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
            onPressed: _cargarDesdeHiveYFirestore,
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
                              // DEPURACIÓN: mostrar las claves de cada registro en consola
                              print('ENTREGA KEYS: ' + entrega.keys.join(', '));
                              print(
                                  'VALORES - HOJA DE RUTA: \\${entrega['HOJA DE RUTA']}, TIPO DOCTO: \\${entrega['TIPO DOCTO']}, DOCUMENTO: \\${entrega['DOCUMENTO']}');
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
                                child: isMobile
                                    ? CheckboxListTile(
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
                                        title: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _mobileField(
                                                'HOJA DE RUTA',
                                                _getCampoFlexible(entrega, [
                                                  'HOJA DE RUTA',
                                                  'hojaDeRuta',
                                                  'hoja_de_ruta',
                                                  'hojaderuta'
                                                ])),
                                            _mobileField(
                                                'TIPO DOCTO',
                                                _getCampoFlexible(entrega, [
                                                  'TIPO DOCTO',
                                                  'tipoDocto',
                                                  'tipo_docto',
                                                  'tipodocto'
                                                ])),
                                            _mobileField(
                                                'DOCUMENTO',
                                                _getCampoFlexible(entrega, [
                                                  'DOCUMENTO',
                                                  'documento'
                                                ])),
                                            _mobileField('SKU', entrega['SKU']),
                                            _mobileField('Cantidad',
                                                entrega['CANTIDAD']),
                                            _mobileField(
                                                'Sección', entrega['SECCION']),
                                            _mobileField('Jefatura',
                                                entrega['JEFATURA']),
                                            _mobileField('Descripción',
                                                entrega['DESCRIPCION']),
                                            _mobileField(
                                                'Valido',
                                                _getCampoFlexible(entrega, [
                                                      'validadoPor',
                                                      'Valido',
                                                      'validado',
                                                      'usuarioValido',
                                                      'usuario_valido',
                                                      'validado_por',
                                                      'validado por'
                                                    ]) ??
                                                    '-'),
                                            if (entrega['firma'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Firma:',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    SizedBox(
                                                      height: 80,
                                                      child: entrega['firma']
                                                              is String
                                                          ? Image.memory(
                                                              base64Decode(
                                                                  entrega[
                                                                      'firma']),
                                                              fit: BoxFit
                                                                  .contain)
                                                          : const Text(
                                                              'Firma no disponible'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (entrega['nombreRecibe'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Text(
                                                    'Recibió: ${entrega['nombreRecibe']}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            if (entrega['fechaFirma'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2.0),
                                                child: Text(
                                                    'Fecha: ${entrega['fechaFirma']}'),
                                              ),
                                          ],
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      )
                                    : CheckboxListTile(
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
                                            Builder(
                                              builder: (context) {
                                                print(
                                                    'DEBUG PC - HOJA DE RUTA: \\${entrega['HOJA DE RUTA']}');
                                                print(
                                                    'DEBUG PC - TIPO DOCTO: \\${entrega['TIPO DOCTO']}');
                                                print(
                                                    'DEBUG PC - DOCUMENTO: \\${entrega['DOCUMENTO']}');
                                                return Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: [
                                                    _infoChip(
                                                        'HOJA DE RUTA',
                                                        _getCampoFlexible(
                                                            entrega, [
                                                          'HOJA DE RUTA',
                                                          'hojaDeRuta',
                                                          'hoja_de_ruta',
                                                          'hojaderuta'
                                                        ])),
                                                    _infoChip(
                                                        'TIPO DOCTO',
                                                        _getCampoFlexible(
                                                            entrega, [
                                                          'TIPO DOCTO',
                                                          'tipoDocto',
                                                          'tipo_docto',
                                                          'tipodocto'
                                                        ])),
                                                    _infoChip(
                                                        'DOCUMENTO',
                                                        _getCampoFlexible(
                                                            entrega, [
                                                          'DOCUMENTO',
                                                          'documento'
                                                        ])),
                                                    _infoChip(
                                                        'SKU', entrega['SKU']),
                                                    _infoChip('CANT',
                                                        entrega['CANTIDAD']),
                                                    _infoChip('SECC',
                                                        entrega['SECCION']),
                                                    _infoChip('JEF',
                                                        entrega['JEFATURA']),
                                                    _infoChip('DESC',
                                                        entrega['DESCRIPCION']),
                                                    _infoChip(
                                                        'Valido',
                                                        _getCampoFlexible(
                                                                entrega, [
                                                              'validadoPor',
                                                              'Valido',
                                                              'validado',
                                                              'usuarioValido',
                                                              'usuario_valido',
                                                              'validado_por',
                                                              'validado por'
                                                            ]) ??
                                                            '-'),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (entrega['firma'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Firma:',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    SizedBox(
                                                      height: 80,
                                                      child: entrega['firma']
                                                              is String
                                                          ? Image.memory(
                                                              base64Decode(
                                                                  entrega[
                                                                      'firma']),
                                                              fit: BoxFit
                                                                  .contain)
                                                          : const Text(
                                                              'Firma no disponible'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (entrega['nombreRecibe'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Text(
                                                    'Recibió: ${entrega['nombreRecibe']}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            if (entrega['fechaFirma'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2.0),
                                                child: Text(
                                                    'Fecha: ${entrega['fechaFirma']}'),
                                              ),
                                          ],
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
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
    final displayValue =
        (value == null || (value is String && value.trim().isEmpty))
            ? '-'
            : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
              child:
                  Text('$displayValue', style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _infoChip(String label, dynamic value) {
    final displayValue =
        (value == null || (value is String && value.trim().isEmpty))
            ? '-'
            : value;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D6A4F)),
      ),
      child: Text('$label: $displayValue',
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
