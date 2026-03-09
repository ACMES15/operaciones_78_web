import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/firebase_cache_utils.dart';
import 'hoja_de_ruta_enviadas_page.dart'; // Asegúrate de que este archivo existe y contiene HojaDeRutaEnviadasPage
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeRutaExtraPage extends StatefulWidget {
  // Claves para almacenamiento local
  static const String tiendasKey = 'tiendasCache';
  static const String proveedoresKey = 'proveedoresCache';

  // Guardar tiendas y proveedores en Firestore y cache
  static Future<void> saveTiendasProveedoresCache() async {
    await guardarDatosFirestoreYCache(
        'hoja_ruta', tiendasKey, {'items': tiendasCache});
    await guardarDatosFirestoreYCache(
        'hoja_ruta', proveedoresKey, {'items': proveedoresCache});
  }

  // Cargar tiendas y proveedores de Firestore/cache
  static Future<void> loadTiendasProveedoresCache() async {
    final tiendasData = await leerDatosConCache('hoja_ruta', tiendasKey);
    if (tiendasData != null && tiendasData['items'] != null) {
      tiendasCache = List<List<String>>.from(
        (tiendasData['items'] as List).map((e) => List<String>.from(e)),
      );
    }
    final proveedoresData =
        await leerDatosConCache('hoja_ruta', proveedoresKey);
    if (proveedoresData != null && proveedoresData['items'] != null) {
      proveedoresCache = List<List<String>>.from(
        (proveedoresData['items'] as List).map((e) => List<String>.from(e)),
      );
    }
  }

  const HojaDeRutaExtraPage({super.key});

  // Caché en memoria (temporal)
  static List<List<String>> tiendasCache = [];
  static List<List<String>> proveedoresCache = [];

  // Flag para habilitar edición en hojas enviadas
  static bool isAdmin = false;

  // Almacenamiento de hojas de ruta guardadas (enviadas)
  // Cada elemento: { 'origen':String, 'fecha':String, 'numeroControl':String, 'tipo':String, 'caja':String, 'rows': List<List<String>>, 'createdAt': String }
  static List<Map<String, dynamic>> sentHojaRutas = [];

  // Cargar desde Firestore/cache
  static Future<void> loadSentHojaRutasCache() async {
    final data = await leerDatosConCache('hoja_ruta', 'sentHojaRutas');
    if (data != null && data['items'] != null) {
      sentHojaRutas = List<Map<String, dynamic>>.from(
        (data['items'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
  }

  // Guardar en Firestore/cache
  static Future<void> saveSentHojaRutasCache() async {
    await guardarDatosFirestoreYCache(
        'hoja_ruta', 'sentHojaRutas', {'items': sentHojaRutas});
  }

  @override
  State<HojaDeRutaExtraPage> createState() => _HojaDeRutaExtraPageState();
}

class _HojaDeRutaExtraPageState extends State<HojaDeRutaExtraPage> {
  final List<List<TextEditingController>> _tiendasControllers = [];
  final List<List<TextEditingController>> _proveedoresControllers = [];

  @override
  void initState() {
    super.initState();
    // Cargar hojas de ruta enviadas y tiendas/proveedores desde cache local
    HojaDeRutaExtraPage.loadSentHojaRutasCache();
    HojaDeRutaExtraPage.loadTiendasProveedoresCache().then((_) {
      // Inicializar controladores desde caché si existe, sino crear 3 filas vacías
      if (HojaDeRutaExtraPage.tiendasCache.isNotEmpty) {
        for (var row in HojaDeRutaExtraPage.tiendasCache) {
          _tiendasControllers.add([
            TextEditingController(text: row.length > 0 ? row[0] : ''),
            TextEditingController(text: row.length > 1 ? row[1] : ''),
          ]);
        }
      } else {
        for (int i = 0; i < 3; i++) {
          _tiendasControllers
              .add([TextEditingController(), TextEditingController()]);
        }
      }
      if (HojaDeRutaExtraPage.proveedoresCache.isNotEmpty) {
        for (var row in HojaDeRutaExtraPage.proveedoresCache) {
          _proveedoresControllers.add([
            TextEditingController(text: row.length > 0 ? row[0] : ''),
            TextEditingController(text: row.length > 1 ? row[1] : ''),
          ]);
        }
      } else {
        for (int i = 0; i < 3; i++) {
          _proveedoresControllers
              .add([TextEditingController(), TextEditingController()]);
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (var r in _tiendasControllers) {
      for (var c in r) {
        c.dispose();
      }
    }
    for (var r in _proveedoresControllers) {
      for (var c in r) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addTiendaRow() {
    setState(() {
      _tiendasControllers
          .add([TextEditingController(), TextEditingController()]);
    });
  }

  void _addProveedorRow() {
    setState(() {
      _proveedoresControllers
          .add([TextEditingController(), TextEditingController()]);
    });
  }

  Future<void> _guardarCambios() async {
    // Guardar filas no vacías en caché estática
    try {
      HojaDeRutaExtraPage.tiendasCache = _tiendasControllers
          .map((r) => [r[0].text.trim(), r[1].text.trim()])
          .where((r) => r[0].isNotEmpty || r[1].isNotEmpty)
          .toList();
      HojaDeRutaExtraPage.proveedoresCache = _proveedoresControllers
          .map((r) => [r[0].text.trim(), r[1].text.trim()])
          .where((r) => r[0].isNotEmpty || r[1].isNotEmpty)
          .toList();
      await HojaDeRutaExtraPage.saveTiendasProveedoresCache();

      // Guardar la hoja actual en el almacenamiento de hojas enviadas
      final Map<String, dynamic> hoja = {
        'origen': 'Tiendas/Proveedores',
        'fecha': DateTime.now().toString(),
        'numeroControl': 'Hoja de Ruta Extra',
        'tipo': 'Hoja de Ruta',
        'caja': 'Caja de Control',
        'rows': _tiendasControllers
            .map((r) => [r[0].text.trim(), r[1].text.trim()])
            .toList(),
        'createdAt': DateTime.now().toString(),
      };
      HojaDeRutaExtraPage.sentHojaRutas.add(hoja);
      await HojaDeRutaExtraPage.saveSentHojaRutasCache();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Datos guardados en Firestore y caché'),
            duration: Duration(seconds: 2)),
      );
      if (mounted) {
        // Log de éxito
        print('[HojaDeRutaExtraPage] Guardado exitoso en Firestore y caché.');
      }
    } catch (e, st) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al guardar: $e'),
            duration: const Duration(seconds: 4)),
      );
      print(
          '[HojaDeRutaExtraPage] Error al guardar en Firestore/caché: $e\n$st');
    }
  }

  Widget _buildRow(
      List<TextEditingController> controllers, String hint1, String hint2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          Flexible(
            flex: 2, // campo número más pequeño
            child: TextField(
              controller: controllers[0],
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: hint1,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 5, // campo nombre más amplio y adaptable
            child: TextField(
              controller: controllers[1],
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: hint2,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiendas y Proveedores'),
        backgroundColor: const Color.fromARGB(184, 69, 70, 69),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Tiendas
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tiendas',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Row(
                              children: const [
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text('No. Tienda',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text('Nombre Tienda',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _tiendasControllers.length,
                                itemBuilder: (context, idx) {
                                  return _buildRow(_tiendasControllers[idx],
                                      'No. Tienda', 'Nombre Tienda');
                                },
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar fila'),
                                onPressed: _addTiendaRow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Proveedores
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Proveedores',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Row(
                              children: const [
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text('No. Proveedor',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text('Nombre Proveedor',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _proveedoresControllers.length,
                                itemBuilder: (context, idx) {
                                  return _buildRow(_proveedoresControllers[idx],
                                      'No. Proveedor', 'Nombre Proveedor');
                                },
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar fila'),
                                onPressed: _addProveedorRow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor:
                          Colors.white // <- texto e ícono en blanco
                      ),
                  onPressed: _guardarCambios,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
