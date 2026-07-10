import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'registro_caminata_form.dart';

class RegistroCaminatasPage extends StatefulWidget {
  final String usuario;
  const RegistroCaminatasPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<RegistroCaminatasPage> createState() => _RegistroCaminatasPageState();
}

class _RegistroCaminatasPageState extends State<RegistroCaminatasPage> {
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  bool _loading = true;
  Map<String, String> _plantilla = {};
  List<String> _jefes = [];

  @override
  void initState() {
    super.initState();
    _loadPlantilla();
  }

  Future<void> _loadPlantilla() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('plantilla_ejecutiva')
          .doc('datos')
          .get();
      if (snap.exists && snap.data() != null && snap.data()!['datos'] is List) {
        for (final e in List<dynamic>.from(snap.data()!['datos'])) {
          if (e is Map && e['SECCION'] != null && e['NOMBRE'] != null) {
            _plantilla[e['SECCION'].toString()] = e['NOMBRE'].toString();
          }
        }
      }
      _jefes = _plantilla.values.toSet().toList()..sort();
    } catch (e) {
      debugPrint('Error cargando plantilla ejecutiva: $e');
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Registro de Caminatas',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                      elevation: 2,
                      child: Row(children: [
                        // Left: list of jefaturas
                        Expanded(
                          child: ListView.separated(
                            itemCount: _jefes.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final jefe = _jefes[index];
                              return ListTile(
                                title: Text(jefe),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                RegistroCaminataForm(
                                                    usuario: widget.usuario,
                                                    jefe: jefe,
                                                    date: _selectedDate)));
                                  },
                                  child: const Text('Inicio de caminata'),
                                ),
                              );
                            },
                          ),
                        ),

                        // Right: columna con botón Histórico
                        Container(
                          width: 140,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  // Placeholder: abrir histórico (puedes conectar página real)
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(
                                          backgroundColor: Colors.black,
                                          title: const Text(
                                              'Histórico Caminatas')),
                                      body: const Center(
                                          child: Text(
                                              'Histórico - implementar vista')),
                                    ),
                                  ));
                                },
                                child: const Text('Historico'),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
