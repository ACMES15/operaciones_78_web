import 'package:flutter/material.dart';
import '../../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'dart:convert';

class EntregasMbodasPage extends StatefulWidget {
  final String usuario;
  const EntregasMbodasPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EntregasMbodasPage> createState() => _EntregasMbodasPageState();
}

class _EntregasMbodasPageState extends State<EntregasMbodasPage> {
  final TextEditingController _lpController = TextEditingController();
  String _lpBusqueda = '';
  String _jefaturaSeleccionada = '';
  List<Map<String, dynamic>> _entregas = [];
  List<Map<String, dynamic>> _historialFirmadas = [];
  Set<int> _seleccionados = {};
  bool _cargando = true;

  Set<String> get _lpsFirmadas => _historialFirmadas
      .map((e) => e['LP']?.toString())
      .whereType<String>()
      .toSet();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos({bool forzarFirestore = false}) async {
    setState(() => _cargando = true);
    Map<String, dynamic>? entregasRaw;
    Map<String, dynamic>? historialRaw;
    if (forzarFirestore) {
      final entregasDoc = await FirebaseFirestore.instance
          .collection('entregas')
          .doc('mbodas')
          .get();
      entregasRaw = entregasDoc.exists ? entregasDoc.data() : {};
      final historialDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('mbodas_firmadas')
          .get();
      historialRaw = historialDoc.exists ? historialDoc.data() : {};
      await guardarDatosFirestoreYCache(
          'entregas', 'mbodas', entregasRaw ?? {});
      await guardarDatosFirestoreYCache(
          'historial_entregas', 'mbodas_firmadas', historialRaw ?? {});
    } else {
      entregasRaw = await leerDatosConCache('entregas', 'mbodas');
      historialRaw =
          await leerDatosConCache('historial_entregas', 'mbodas_firmadas');
    }
    List<Map<String, dynamic>> entregas = [];
    if (entregasRaw != null && entregasRaw['items'] is List) {
      entregas = List<Map<String, dynamic>>.from(entregasRaw['items']);
    }
    List<Map<String, dynamic>> historial = [];
    if (historialRaw != null && historialRaw['items'] is List) {
      historial = List<Map<String, dynamic>>.from(historialRaw['items']);
    }
    setState(() {
      _entregas = entregas;
      _historialFirmadas = historial;
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _entregasFiltradas {
    final lpsFirmadas = _lpsFirmadas;
    return _entregas
        .where((e) => !lpsFirmadas.contains(e['LP']?.toString()))
        .where((e) =>
            _lpBusqueda.isEmpty ||
            (e['LP']?.toString().toLowerCase() ?? '')
                .contains(_lpBusqueda.toLowerCase()))
        .where((e) =>
            _jefaturaSeleccionada.isEmpty ||
            (e['JEFATURA']?.toString() ?? '') == _jefaturaSeleccionada)
        .toList();
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
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Color(0xFF2D6A4F), width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Signature(
                              controller: signatureController,
                              height: 150,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => signatureController.clear(),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  if (nombreController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Ingresa el nombre de quien recibe.')));
                                    return;
                                  }
                                  if (signatureController.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Debes firmar antes de continuar.')));
                                    return;
                                  }
                                  final signature =
                                      await signatureController.toPngBytes();
                                  if (signature == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Error al capturar la firma.')));
                                    return;
                                  }
                                  Navigator.of(ctx).pop({
                                    'nombre': nombreController.text.trim(),
                                    'firma': base64Encode(signature),
                                  });
                                },
                                child: const Text('Aceptar'),
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
          : Dialog(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                            selection:
                                TextSelection.collapsed(offset: upper.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Firma:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFF2D6A4F), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Signature(
                        controller: signatureController,
                        height: 150,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => signatureController.clear(),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (nombreController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Ingresa el nombre de quien recibe.')));
                              return;
                            }
                            if (signatureController.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Debes firmar antes de continuar.')));
                              return;
                            }
                            final signature =
                                await signatureController.toPngBytes();
                            if (signature == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Error al capturar la firma.')));
                              return;
                            }
                            Navigator.of(ctx).pop({
                              'nombre': nombreController.text.trim(),
                              'firma': base64Encode(signature),
                            });
                          },
                          child: const Text('Aceptar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
    if (resultado == null) return;
    // Guardar firmas
    for (final entrega in seleccionadas) {
      entrega['FIRMADO_POR'] = resultado['nombre'];
      entrega['FIRMA'] = resultado['firma'];
      entrega['FECHA_FIRMA'] = DateTime.now().toIso8601String();
    }
    // Actualizar historial y entregas
    setState(() {
      _historialFirmadas.addAll(seleccionadas);
      _entregas.removeWhere((e) => seleccionadas.contains(e));
      _seleccionados.clear();
    });
    await guardarDatosFirestoreYCache(
        'historial_entregas', 'mbodas_firmadas', {'items': _historialFirmadas});
    await guardarDatosFirestoreYCache(
        'entregas', 'mbodas', {'items': _entregas});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entregas firmadas y guardadas correctamente.')));
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.shortestSide <= 600;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.cake, color: Color(0xFF2D6A4F), size: 28),
            SizedBox(width: 10),
            Text(
              'Entregas MBODAS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: Color(0xFF2D6A4F),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFE9ECEF),
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lpController,
                          decoration: const InputDecoration(
                            labelText: 'Buscar LP',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            setState(() {
                              _lpBusqueda = v;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _cargarDatos,
                        child: const Text('Actualizar'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _entregasFiltradas.isEmpty
                      ? const Center(child: Text('No hay entregas pendientes'))
                      : ListView.builder(
                          itemCount: _entregasFiltradas.length,
                          itemBuilder: (context, idx) {
                            final entrega = _entregasFiltradas[idx];
                            final seleccionado = _seleccionados.contains(idx);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: Checkbox(
                                  value: seleccionado,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _seleccionados.add(idx);
                                      } else {
                                        _seleccionados.remove(idx);
                                      }
                                    });
                                  },
                                ),
                                title: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _infoChip('LP', entrega['LP']),
                                    _infoChip('SKU', entrega['SKU']),
                                    _infoChip(
                                        'DESCRIPCION', entrega['DESCRIPCION']),
                                    _infoChip('CANTIDAD', entrega['CANTIDAD']),
                                    _infoChip('SECCION', entrega['SECCION']),
                                    _infoChip('JEFATURA', entrega['JEFATURA']),
                                    _infoChip('MBODAS', entrega['MBODAS']),
                                  ],
                                ),
                                subtitle: isMobile
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _mobileField('LP', entrega['LP']),
                                          _mobileField('SKU', entrega['SKU']),
                                          _mobileField('DESCRIPCION',
                                              entrega['DESCRIPCION']),
                                          _mobileField(
                                              'CANTIDAD', entrega['CANTIDAD']),
                                          _mobileField(
                                              'SECCION', entrega['SECCION']),
                                          _mobileField(
                                              'JEFATURA', entrega['JEFATURA']),
                                          _mobileField(
                                              'MBODAS', entrega['MBODAS']),
                                        ],
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
                if (_entregasFiltradas.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_document, size: 22),
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
    );
  }
}
