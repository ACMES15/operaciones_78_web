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
  String? _selectedJefe;

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (res != null) setState(() => _selectedDate = res);
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
            Text('Usuario: ${widget.usuario}',
                style: const TextStyle(color: Colors.black)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: _pickDate,
              child: const Text('Seleccionar fecha'),
            ),
            const SizedBox(height: 8),
            Text(_selectedDate == null
                ? 'Fecha no seleccionada'
                : _selectedDate!.toLocal().toString().split(' ')[0]),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                      elevation: 2,
                      child: ListView.separated(
                        itemCount: _jefes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final jefe = _jefes[index];
                          final selected = jefe == _selectedJefe;
                          return ListTile(
                            title: Text(jefe),
                            onTap: () => setState(
                                () => _selectedJefe = selected ? null : jefe),
                            trailing: selected
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black),
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
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas de la caminata (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Notas temporales guardadas')));
                  },
                  child: const Text('Guardar notas'),
                ),
              ),
            ])
          ],
        ),
      ),
    );
  }
}
