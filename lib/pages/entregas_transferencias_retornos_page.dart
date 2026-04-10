import 'package:flutter/material.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntregasTransferenciasRetornosPage extends StatefulWidget {
  const EntregasTransferenciasRetornosPage({Key? key}) : super(key: key);

  @override
  State<EntregasTransferenciasRetornosPage> createState() =>
      _EntregasTransferenciasRetornosPageState();
}

class _EntregasTransferenciasRetornosPageState
    extends State<EntregasTransferenciasRetornosPage> {
  final TextEditingController _busquedaController = TextEditingController();
  String _busqueda = '';
  String _jefaturaSeleccionada = '';
  List<Map<String, dynamic>> _entregas = [];
  List<Map<String, dynamic>> _historialFirmadas = [];
  Set<int> _seleccionados = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _sincronizarFirmasPendientes();
  }

  Future<void> _sincronizarFirmasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'firmas_pendientes_transferencias_retornos';
    final data = prefs.getString(key);
    if (data != null) {
      try {
        final List<dynamic> pendientes = jsonDecode(data);
        if (pendientes.isNotEmpty) {
          final historialActual =
              List<Map<String, dynamic>>.from(_historialFirmadas);
          historialActual.addAll(pendientes.cast<Map<String, dynamic>>());
          await guardarDatosFirestoreYCache('historial_entregas',
              'transferencias_retornos_firmadas', {'items': historialActual});
          await prefs.remove(key);
          await _cargarDatos();
        }
      } catch (_) {}
    }
  }

  Set<String> get _idsFirmados => _historialFirmadas
      .map((e) => e['id']?.toString())
      .whereType<String>()
      .toSet();

  Future<void> _cargarDatos({bool forzarFirestore = false}) async {
    setState(() => _cargando = true);
    Map<String, dynamic>? entregasRaw;
    Map<String, dynamic>? historialRaw;
    if (forzarFirestore) {
      final entregasDoc = await FirebaseFirestore.instance
          .collection('entregas')
          .doc('transferencias_retornos')
          .get();
      entregasRaw = entregasDoc.exists ? entregasDoc.data() : {};
      final historialDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('transferencias_retornos_firmadas')
          .get();
      historialRaw = historialDoc.exists ? historialDoc.data() : {};
      await guardarDatosFirestoreYCache(
          'entregas', 'transferencias_retornos', entregasRaw ?? {});
      await guardarDatosFirestoreYCache('historial_entregas',
          'transferencias_retornos_firmadas', historialRaw ?? {});
    } else {
      entregasRaw =
          await leerDatosConCache('entregas', 'transferencias_retornos');
      historialRaw = await leerDatosConCache(
          'historial_entregas', 'transferencias_retornos_firmadas');
    }
    List<Map<String, dynamic>> entregas = [];
    if (entregasRaw != null && entregasRaw['items'] is List) {
      int idx = 0;
      for (var e in (entregasRaw['items'] as List)) {
        if (e is Map) {
          final map = Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v)));
          if (idx == 0) {
            print('CLAVES DEL PRIMER ELEMENTO:');
            for (var key in map.keys) {
              print('CLAVE: >' + key + '<');
            }
          }
          print('DEBUG TF O DEV carga: ${map['TF O DEV']} id: ${map['id']}');
          // Mapear TF O DEV a TRANSFERENCIA si es necesario
          if (map['TRANSFERENCIA'] == null ||
              map['TRANSFERENCIA'].toString().isEmpty) {
            if (map['TF O DEV '] != null &&
                map['TF O DEV '].toString().isNotEmpty) {
              map['TRANSFERENCIA'] = map['TF O DEV '];
            } else if (map['TF'] != null && map['TF'].toString().isNotEmpty) {
              map['TRANSFERENCIA'] = map['TF'];
            } else if (map['DEV'] != null && map['DEV'].toString().isNotEmpty) {
              map['TRANSFERENCIA'] = map['DEV'];
            }
          }
          map['id'] = map['id']?.toString() ??
              (map['TF O DEV ']?.toString() ?? 'item_$idx');
          entregas.add(map);
          idx++;
        }
      }
    }
    List<Map<String, dynamic>> historial = [];
    if (historialRaw != null && historialRaw['items'] is List) {
      for (var e in (historialRaw['items'] as List)) {
        if (e is Map) {
          final map = Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v)));
          map['id'] =
              map['id']?.toString() ?? (map['TF O DEV ']?.toString() ?? '');
          historial.add(map);
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
    final idsFirmados = _idsFirmados;
    return _entregas
        .where((e) => !idsFirmados.contains(e['id']?.toString()))
        .where((e) =>
            _busqueda.isEmpty ||
            (e['TF O DEV ']?.toString().toLowerCase() ?? '')
                .contains(_busqueda.toLowerCase()) ||
            (e['ORIGEN']?.toString().toLowerCase() ?? '')
                .contains(_busqueda.toLowerCase()) ||
            (e['DESTINO']?.toString().toLowerCase() ?? '')
                .contains(_busqueda.toLowerCase()))
        .where((e) =>
            _jefaturaSeleccionada.isEmpty ||
            (e['JEFATURA']?.toString() ?? '') == _jefaturaSeleccionada)
        .toList();
  }

  Future<void> _firmarSeleccionados(BuildContext context) async {
    final seleccionadas =
        _seleccionados.map((idx) => _entregasFiltradas[idx]).toList();
    final idsFirmados = _idsFirmados;
    final idsSeleccionados =
        seleccionadas.map((e) => e['id']?.toString()).toSet();
    final idsYaFirmados = idsSeleccionados.intersection(idsFirmados);
    if (idsYaFirmados.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Al menos un elemento ya fue firmado. Actualiza la lista.')));
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
    // Guardar en historial
    // Obtener el usuario autenticado desde el contexto del widget principal si es posible
    String usuarioEntrega = '';
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is String && routeArgs.isNotEmpty) {
      usuarioEntrega = routeArgs;
    }
    final nuevasFirmadas = seleccionadas
        .map((e) => {
              ...e,
              'nombreRecibe': resultado['nombre'],
              'firma': resultado['firma'],
              'fechaFirma': DateTime.now().toIso8601String(),
              'usuarioEntrega': usuarioEntrega,
              'id': e['id']?.toString() ?? (e['TF O DEV']?.toString() ?? ''),
            })
        .toList();
    final historialActual = List<Map<String, dynamic>>.from(_historialFirmadas);
    historialActual.addAll(nuevasFirmadas);
    try {
      await guardarDatosFirestoreYCache('historial_entregas',
          'transferencias_retornos_firmadas', {'items': historialActual});
      setState(() {
        _seleccionados.clear();
      });
      await _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entregas firmadas y guardadas correctamente.')));
    } catch (e) {
      // Si falla la subida, guardar localmente como pendiente
      final prefs = await SharedPreferences.getInstance();
      final key = 'firmas_pendientes_transferencias_retornos';
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
      setState(() {
        _seleccionados.clear();
      });
      await _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // jefaturas ya no se usa, el filtro se genera directamente en el Dropdown
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: const Text('Entregas Transferencias y Retornos',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
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
                          controller: _busquedaController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Buscar transferencia, origen o destino',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (v) {
                            setState(() => _busqueda = v);
                          },
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
                          ..._entregasFiltradas
                              .map((e) => (e['JEFATURA'] ?? '').toString())
                              .where((j) => j.isNotEmpty)
                              .toSet()
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
                                            _mobileFieldTFODEV(entrega),
                                            _mobileField(
                                                'ORIGEN', entrega['ORIGEN']),
                                            _mobileField(
                                                'DESTINO', entrega['DESTINO']),
                                            _mobileField(
                                                'SECCION', entrega['SECCION']),
                                            _mobileField('JEFATURA',
                                                entrega['JEFATURA']),
                                            _mobileField(
                                                'Valido',
                                                entrega['usuarioValido'] ??
                                                    '-'),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            _infoChipTFODEV(entrega),
                                            _infoChip(
                                                'ORIGEN', entrega['ORIGEN']),
                                            _infoChip(
                                                'DESTINO', entrega['DESTINO']),
                                            _infoChip(
                                                'SECCION', entrega['SECCION']),
                                            _infoChip('JEFATURA',
                                                entrega['JEFATURA']),
                                            _infoChip(
                                                'Valido',
                                                entrega['usuarioValido'] ??
                                                    '-'),
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

  Widget _mobileFieldTFODEV(Map<String, dynamic> entrega) {
    final value = entrega['TF O DEV'] ??
        entrega['TRANSFERENCIA'] ??
        entrega['TF'] ??
        entrega['DEV'] ??
        '-';
    print('UI TF O DEV: $value id: ${entrega['id']}');
    return _mobileField('TF O DEV', value);
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

  Widget _infoChipTFODEV(Map<String, dynamic> entrega) {
    final value = entrega['TF O DEV'] ??
        entrega['TRANSFERENCIA'] ??
        entrega['TF'] ??
        entrega['DEV'] ??
        '-';
    return _infoChip('TF O DEV', value);
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }
}
