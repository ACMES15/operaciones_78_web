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
  @override
  void initState() {
    super.initState();
    _cargarDesdeFirestore();
    _sincronizarFirmasPendientes();
  }

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
          await _cargarDesdeFirestore();
        }
      } catch (_) {}
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
    if (resultado == null) return;

    final firestore = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> nuevasFirmadas = [];
    try {
      for (final entrega in seleccionadas) {
        final docRef =
            firestore.collection('entregas_cdr').doc(entrega['id']?.toString());
        final nuevaEntrega = Map<String, dynamic>.from(entrega);
        nuevaEntrega['nombreRecibe'] = resultado['nombre'];
        nuevaEntrega['firma'] = resultado['firma'];
        nuevaEntrega['fechaFirma'] = DateTime.now().toIso8601String();
        nuevaEntrega['usuarioEntrega'] = widget.usuario;
        nuevaEntrega.remove('id');
        await docRef.delete();

        // Notificar a ADMIN OMNICANAL y ADMIN ENVIOS si es faltante (BOX)
        if (entrega['BOX'] == true || entrega['BOX'] == 'true') {
          final mensaje =
              'Faltante en Entregas CDR: DOC ${entrega['DOCUMENTO'] ?? ''}, SKU ${entrega['SKU'] ?? ''}, SECCION ${entrega['SECCION'] ?? ''}';
          for (final tipo in ['ADMIN OMNICANAL', 'ADMIN ENVIOS']) {
            await FirebaseFirestore.instance.collection('notificaciones').add({
              'mensaje': mensaje,
              'fecha': DateTime.now(),
              'destinoTipo': tipo,
              'tipo': 'FALTANTE CDR',
              'leido': false,
              'documento': entrega['DOCUMENTO'] ?? '',
              'sku': entrega['SKU'] ?? '',
              'seccion': entrega['SECCION'] ?? '',
              'usuario': widget.usuario,
            });
          }
        }

        nuevasFirmadas.add(nuevaEntrega);
      }
      // Guardar en historial
      final historialDoc =
          firestore.collection('historial_entregas').doc('cdr_firmadas');
      final historialSnap = await historialDoc.get();
      List<dynamic> historial = [];
      if (historialSnap.exists &&
          historialSnap.data() != null &&
          historialSnap.data()!['items'] is List) {
        historial = List.from(historialSnap.data()!['items']);
      }
      historial.addAll(nuevasFirmadas);
      await historialDoc.set({'items': historial});
      setState(() => _seleccionados.clear());
      await _cargarDesdeFirestore();
    } catch (e) {
      // Si falla la subida, guardar localmente como pendiente
      final prefs = await SharedPreferences.getInstance();
      final key = 'firmas_pendientes_cdr';
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
      setState(() => _seleccionados.clear());
      await _cargarDesdeFirestore();
    }
  }

  Future<void> _cargarDesdeFirestore() async {
    setState(() => _cargando = true);
    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore.collection('entregas_cdr').get();
    List<Map<String, dynamic>> nuevos = querySnapshot.docs.map((doc) {
      final data = doc.data();
      // Asegura que cada registro tenga el id del documento
      return {
        ...data,
        'id': doc.id,
      };
    }).toList();
    print('DEBUG: Registros obtenidos de entregas_cdr: \\${nuevos.length}');
    if (nuevos.isNotEmpty) {
      print('DEBUG: Primer registro: \\${nuevos[0]}');
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
