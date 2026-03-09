import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../utils/firebase_cache_utils.dart';

class PlantillaEjecutivaPage extends StatelessWidget {
  const PlantillaEjecutivaPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _PlantillaEjecutivaBody(),
    );
  }
}

class _PlantillaEjecutivaBody extends StatefulWidget {
  const _PlantillaEjecutivaBody({Key? key}) : super(key: key);

  @override
  State<_PlantillaEjecutivaBody> createState() =>
      _PlantillaEjecutivaBodyState();
}

class _PlantillaEjecutivaBodyState extends State<_PlantillaEjecutivaBody> {
  Future<void> _guardarDatosFirebase() async {
    try {
      await guardarDatosFirestoreYCache(
        'plantilla_ejecutiva',
        'datos',
        {'datos': datos},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Datos guardados en Firebase/cache.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  static const String _storageKey = 'plantilla_ejecutiva_datos';
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // void _guardarDatosLocales() {
  //   try {
  //     final encoded = datos.map((fila) => fila.join('|')).join('~');
  //     html.window.localStorage[_storageKey] = encoded;
  //   } catch (e) {
  //     print('Error guardando datos locales: $e');
  //   }
  // }

  // Botón alternativo solo para web usando input HTML nativo
  Widget _botonImportarHtmlWeb() {
    return ElevatedButton(
      onPressed: () async {
        final uploadInput = html.FileUploadInputElement();
        uploadInput.accept = '.xlsx';
        uploadInput.click();
        uploadInput.onChange.listen((e) async {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final reader = html.FileReader();
            reader.readAsArrayBuffer(files[0]);
            reader.onLoadEnd.listen((event) async {
              final bytes = reader.result as Uint8List;
              final nuevosDatos = _procesarExcelDirecto(bytes, columnas);
              setState(() {
                datos = nuevosDatos;
              });
              // Guardar en Firestore y cache
              try {
                await guardarDatosFirestoreYCache(
                  'plantilla_ejecutiva',
                  'datos',
                  {'datos': nuevosDatos},
                );
              } catch (e) {
                print('Error guardando en Firestore/cache: $e');
              }
            });
          }
        });
      },
      child: const Text('Importar Excel'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
    );
  }

  // Botón de prueba temporal para FilePicker en web

  static const List<String> columnas = [
    'ID',
    'SECCION',
    'NOMBRE',
    'PISO',
    'DEPARTAMENTO',
    'GERENCIA',
    'DIRECCION',
    'INV PROMEDIO',
    'NUMERO DE EMPLEADO',
  ];

  List<List<String>> datos = [];

  // Indices de columnas numéricas
  final List<int> columnasNumericas = [
    0,
    1,
    6,
    8
  ]; // ID, SECCION, DIRECCION, NUMERO DE EMPLEADO
  bool cargando = false;

  // Procesamiento directo para web
  List<List<String>> _procesarExcelDirecto(
      Uint8List bytes, List<String> columnas) {
    final excel = Excel.decodeBytes(bytes);
    final List<List<String>> datos = [];
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        final fila = List<String>.generate(
          columnas.length,
          (i) =>
              i < row.length && row[i] != null ? row[i]!.value.toString() : '',
        );
        datos.add(fila);
      }
      break; // Solo la primera hoja
    }
    return datos;
  }

  Future<void> _cargarDatos() async {
    try {
      // Leer primero del cache local, luego de Firestore si no hay datos
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('plantilla_ejecutiva_datos');
      if (cacheData != null) {
        final datosCache = jsonDecode(cacheData);
        if (datosCache != null && datosCache['datos'] != null) {
          setState(() {
            datos = List<List<String>>.from((datosCache['datos'] as List)
                .map((fila) => List<String>.from(fila)));
          });
          return;
        }
      }
      // Si no hay en cache, intenta Firestore
      final firestore = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();
      if (firestore.exists &&
          firestore.data() != null &&
          firestore.data()!['datos'] != null) {
        setState(() {
          datos = List<List<String>>.from((firestore.data()!['datos'] as List)
              .map((fila) => List<String>.from(fila)));
        });
        // Actualizar cache local
        await prefs.setString(
            'plantilla_ejecutiva_datos', jsonEncode(firestore.data()));
        return;
      }
      // Como último recurso, intenta localStorage (legacy)
      final encoded = html.window.localStorage[_storageKey];
      if (encoded != null && encoded.isNotEmpty) {
        final filas = encoded.split('~');
        setState(() {
          datos = filas.map((f) => f.split('|')).toList();
        });
      }
    } catch (e) {
      print('Error cargando datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, color: Color(0xFF2D6A4F), size: 32),
              const SizedBox(width: 12),
              const Text('Plantilla Ejecutiva',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              _botonImportarHtmlWeb(),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: datos.isEmpty ? null : _guardarDatosFirebase,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (cargando) const Center(child: CircularProgressIndicator()),
          if (!cargando)
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 900),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: columnas
                            .map((col) => DataColumn(
                                label: Text(col,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))))
                            .toList(),
                        rows: datos.isEmpty
                            ? []
                            : datos
                                .map((fila) => DataRow(
                                      cells: List.generate(
                                        columnas.length,
                                        (i) {
                                          final valor =
                                              i < fila.length ? fila[i] : '';
                                          final isNumeric =
                                              columnasNumericas.contains(i);
                                          return DataCell(
                                            Align(
                                              alignment: isNumeric
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              child: Text(
                                                isNumeric
                                                    ? (valor.isEmpty
                                                        ? ''
                                                        : num.tryParse(valor)
                                                                ?.toString() ??
                                                            valor)
                                                    : valor,
                                                style: TextStyle(
                                                  fontFeatures: isNumeric
                                                      ? [
                                                          const FontFeature
                                                              .tabularFigures()
                                                        ]
                                                      : null,
                                                  fontWeight: isNumeric
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ))
                                .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
