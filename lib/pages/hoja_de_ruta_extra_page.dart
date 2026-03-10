import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../utils/firebase_cache_utils.dart';
import '../utils/sheet_validator.dart';
import 'hoja_de_ruta_enviadas_page.dart'; // Asegúrate de que este archivo existe y contiene HojaDeRutaEnviadasPage
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeRutaExtraPage extends StatefulWidget {
  // Claves para almacenamiento local
  static const String tiendasKey = 'tiendasCache';
  static const String proveedoresKey = 'proveedoresCache';

  // Guardar tiendas y proveedores en Firestore y cache
  static Future<void> saveTiendasProveedoresCache() async {
    // Convertir cada fila a Map para Firestore
    final tiendasList =
        tiendasCache.map((e) => {'col1': e[0], 'col2': e[1]}).toList();
    final proveedoresList =
        proveedoresCache.map((e) => {'col1': e[0], 'col2': e[1]}).toList();
    await guardarDatosFirestoreYCache(
        'hoja_ruta', tiendasKey, {'items': tiendasList});
    await guardarDatosFirestoreYCache(
        'hoja_ruta', proveedoresKey, {'items': proveedoresList});
  }

  // Cargar tiendas y proveedores de Firestore/cache
  static Future<void> loadTiendasProveedoresCache() async {
    // Intentar siempre obtener la versión más reciente desde Firestore
    // y usar el cache local sólo como fallback si falla la lectura remota.
    try {
      final tiendasDoc = await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(tiendasKey)
          .get();
      if (tiendasDoc.exists &&
          tiendasDoc.data() != null &&
          tiendasDoc.data()!['items'] is List) {
        final list = tiendasDoc.data()!['items'] as List;
        tiendasCache = List<List<String>>.from(
          list.map((e) => [e['col1'] ?? '', e['col2'] ?? '']),
        );
      } else {
        final tiendasData = await leerDatosConCache('hoja_ruta', tiendasKey);
        if (tiendasData != null && tiendasData['items'] != null) {
          tiendasCache = List<List<String>>.from(
            (tiendasData['items'] as List)
                .map((e) => [e['col1'] ?? '', e['col2'] ?? '']),
          );
        }
      }
    } catch (e) {
      final tiendasData = await leerDatosConCache('hoja_ruta', tiendasKey);
      if (tiendasData != null && tiendasData['items'] != null) {
        tiendasCache = List<List<String>>.from(
          (tiendasData['items'] as List)
              .map((e) => [e['col1'] ?? '', e['col2'] ?? '']),
        );
      }
    }

    try {
      final provDoc = await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .doc(proveedoresKey)
          .get();
      if (provDoc.exists &&
          provDoc.data() != null &&
          provDoc.data()!['items'] is List) {
        final list = provDoc.data()!['items'] as List;
        proveedoresCache = List<List<String>>.from(
          list.map((e) => [e['col1'] ?? '', e['col2'] ?? '']),
        );
      } else {
        final proveedoresData =
            await leerDatosConCache('hoja_ruta', proveedoresKey);
        if (proveedoresData != null && proveedoresData['items'] != null) {
          proveedoresCache = List<List<String>>.from(
            (proveedoresData['items'] as List)
                .map((e) => [e['col1'] ?? '', e['col2'] ?? '']),
          );
        }
      }
    } catch (e) {
      final proveedoresData =
          await leerDatosConCache('hoja_ruta', proveedoresKey);
      if (proveedoresData != null && proveedoresData['items'] != null) {
        proveedoresCache = List<List<String>>.from(
          (proveedoresData['items'] as List)
              .map((e) => [e['col1'] ?? '', e['col2'] ?? '']),
        );
      }
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
  bool _localDirtyTiendas = false;
  bool _localDirtyProveedores = false;

  // Ya no usamos initState para cargar datos, todo será reactivo con StreamBuilder

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
      _localDirtyTiendas = true;
    });
  }

  void _addProveedorRow() {
    setState(() {
      _proveedoresControllers
          .add([TextEditingController(), TextEditingController()]);
      _localDirtyProveedores = true;
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
      final List<Map<String, String>> rowsAsMap = _tiendasControllers
          .map((r) => {
                'col1': r[0].text.trim(),
                'col2': r[1].text.trim(),
              })
          .where((m) => m['col1']!.isNotEmpty || m['col2']!.isNotEmpty)
          .toList();
      final Map<String, dynamic> hoja = {
        'origen': 'Tiendas/Proveedores',
        'fecha': DateTime.now().toString(),
        'numeroControl': 'Hoja de Ruta Extra',
        'tipo': 'Hoja de Ruta',
        'caja': 'Caja de Control',
        'rows': rowsAsMap,
        'createdAt': DateTime.now().toString(),
      };
      // Validar hoja antes de guardar
      final vr = validateSheet(hoja);
      if (!vr.ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Error al guardar Tiendas/Proveedores: ${vr.errors.join('; ')}')));
        return;
      }

      // En lugar de añadir repetidamente, sobrescribir la entrada existente
      final idx = HojaDeRutaExtraPage.sentHojaRutas.indexWhere((s) {
        try {
          final origen = s['origen']?.toString();
          final num = s['numeroControl']?.toString();
          return origen == 'Tiendas/Proveedores' || num == 'Hoja de Ruta Extra';
        } catch (_) {
          return false;
        }
      });
      if (idx != -1) {
        HojaDeRutaExtraPage.sentHojaRutas[idx] = hoja;
      } else {
        HojaDeRutaExtraPage.sentHojaRutas.add(hoja);
      }
      await HojaDeRutaExtraPage.saveSentHojaRutasCache();

      // Invalidar cache local para forzar re-lectura desde Firestore
      try {
        await invalidateCache('hoja_ruta', HojaDeRutaExtraPage.tiendasKey);
        await invalidateCache('hoja_ruta', HojaDeRutaExtraPage.proveedoresKey);
        await invalidateCache('hoja_ruta', 'sentHojaRutas');
      } catch (_) {}

      // Marcar que los cambios locales fueron guardados
      _localDirtyTiendas = false;
      _localDirtyProveedores = false;

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
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hoja_ruta')
              .doc(HojaDeRutaExtraPage.tiendasKey)
              .snapshots(),
          builder: (context, tiendasSnapshot) {
            final tiendasData = tiendasSnapshot.data?.data();
            final tiendasList =
                tiendasData != null && tiendasData['items'] != null
                    ? List<List<String>>.from((tiendasData['items'] as List)
                        .map((e) => [e['col1'] ?? '', e['col2'] ?? '']))
                    : <List<String>>[];
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('hoja_ruta')
                  .doc(HojaDeRutaExtraPage.proveedoresKey)
                  .snapshots(),
              builder: (context, proveedoresSnapshot) {
                final proveedoresData = proveedoresSnapshot.data?.data();
                final proveedoresList = proveedoresData != null &&
                        proveedoresData['items'] != null
                    ? List<List<String>>.from((proveedoresData['items'] as List)
                        .map((e) => [e['col1'] ?? '', e['col2'] ?? '']))
                    : <List<String>>[];
                // Sincronizar los controladores de estado con los datos del snapshot.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    // Tiendas: si no hay cambios locales, sincronizar completamente;
                    // si hay cambios locales, hacer merge para no perder filas añadidas.
                    if (!_localDirtyTiendas) {
                      if (tiendasList.length != _tiendasControllers.length) {
                        for (var r in _tiendasControllers) {
                          for (var c in r) {
                            c.dispose();
                          }
                        }
                        _tiendasControllers.clear();
                        _tiendasControllers.addAll(tiendasList
                            .map((row) => [
                                  TextEditingController(
                                      text: row.length > 0 ? row[0] : ''),
                                  TextEditingController(
                                      text: row.length > 1 ? row[1] : ''),
                                ])
                            .toList());
                      } else {
                        for (var i = 0; i < tiendasList.length; i++) {
                          _tiendasControllers[i][0].text =
                              tiendasList[i].length > 0
                                  ? tiendasList[i][0]
                                  : '';
                          _tiendasControllers[i][1].text =
                              tiendasList[i].length > 1
                                  ? tiendasList[i][1]
                                  : '';
                        }
                      }
                    } else {
                      final minLen =
                          min(tiendasList.length, _tiendasControllers.length);
                      for (var i = 0; i < minLen; i++) {
                        _tiendasControllers[i][0].text =
                            tiendasList[i].length > 0 ? tiendasList[i][0] : '';
                        _tiendasControllers[i][1].text =
                            tiendasList[i].length > 1 ? tiendasList[i][1] : '';
                      }
                      if (tiendasList.length > _tiendasControllers.length) {
                        for (var i = _tiendasControllers.length;
                            i < tiendasList.length;
                            i++) {
                          _tiendasControllers.add([
                            TextEditingController(
                                text: tiendasList[i].length > 0
                                    ? tiendasList[i][0]
                                    : ''),
                            TextEditingController(
                                text: tiendasList[i].length > 1
                                    ? tiendasList[i][1]
                                    : ''),
                          ]);
                        }
                      }
                      // Si local > remoto, conservar filas locales hasta guardar
                    }

                    // Proveedores: misma política
                    if (!_localDirtyProveedores) {
                      if (proveedoresList.length !=
                          _proveedoresControllers.length) {
                        for (var r in _proveedoresControllers) {
                          for (var c in r) {
                            c.dispose();
                          }
                        }
                        _proveedoresControllers.clear();
                        _proveedoresControllers.addAll(proveedoresList
                            .map((row) => [
                                  TextEditingController(
                                      text: row.length > 0 ? row[0] : ''),
                                  TextEditingController(
                                      text: row.length > 1 ? row[1] : ''),
                                ])
                            .toList());
                      } else {
                        for (var i = 0; i < proveedoresList.length; i++) {
                          _proveedoresControllers[i][0].text =
                              proveedoresList[i].length > 0
                                  ? proveedoresList[i][0]
                                  : '';
                          _proveedoresControllers[i][1].text =
                              proveedoresList[i].length > 1
                                  ? proveedoresList[i][1]
                                  : '';
                        }
                      }
                    } else {
                      final minLenP = min(proveedoresList.length,
                          _proveedoresControllers.length);
                      for (var i = 0; i < minLenP; i++) {
                        _proveedoresControllers[i][0].text =
                            proveedoresList[i].length > 0
                                ? proveedoresList[i][0]
                                : '';
                        _proveedoresControllers[i][1].text =
                            proveedoresList[i].length > 1
                                ? proveedoresList[i][1]
                                : '';
                      }
                      if (proveedoresList.length >
                          _proveedoresControllers.length) {
                        for (var i = _proveedoresControllers.length;
                            i < proveedoresList.length;
                            i++) {
                          _proveedoresControllers.add([
                            TextEditingController(
                                text: proveedoresList[i].length > 0
                                    ? proveedoresList[i][0]
                                    : ''),
                            TextEditingController(
                                text: proveedoresList[i].length > 1
                                    ? proveedoresList[i][1]
                                    : ''),
                          ]);
                        }
                      }
                    }
                  });
                });
                return Column(
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: const [
                                        SizedBox(width: 8),
                                        Expanded(
                                            child: Text('No. Tienda',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        SizedBox(width: 8),
                                        Expanded(
                                            child: Text('Nombre Tienda',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        SizedBox(width: 8),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: _tiendasControllers.length,
                                        itemBuilder: (context, idx) {
                                          return _buildRow(
                                              _tiendasControllers[idx],
                                              'No. Tienda',
                                              'Nombre Tienda');
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: const [
                                        SizedBox(width: 8),
                                        Expanded(
                                            child: Text('No. Proveedor',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        SizedBox(width: 8),
                                        Expanded(
                                            child: Text('Nombre Proveedor',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        SizedBox(width: 8),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount:
                                            _proveedoresControllers.length,
                                        itemBuilder: (context, idx) {
                                          return _buildRow(
                                              _proveedoresControllers[idx],
                                              'No. Proveedor',
                                              'Nombre Proveedor');
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
                              foregroundColor: Colors.white),
                          onPressed: _guardarCambios,
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
