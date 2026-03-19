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

  @override
  Widget build(BuildContext context) {
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
          : Center(
              child: Text('Aquí irá el proceso de Entregas MBODAS'),
            ),
    );
  }
}
