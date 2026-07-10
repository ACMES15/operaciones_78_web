import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RegistroCaminataForm extends StatefulWidget {
  final String usuario;
  final String jefe;
  final DateTime? date;
  const RegistroCaminataForm(
      {Key? key, required this.usuario, required this.jefe, this.date})
      : super(key: key);

  @override
  State<RegistroCaminataForm> createState() => _RegistroCaminataFormState();
}

class _RegistroCaminataFormState extends State<RegistroCaminataForm> {
  final TextEditingController _notesController = TextEditingController();
  TimeOfDay? _startTime;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final now = TimeOfDay.now();
    final res =
        await showTimePicker(context: context, initialTime: _startTime ?? now);
    if (res != null) setState(() => _startTime = res);
  }

  Future<void> _saveCaminata() async {
    final date = widget.date ?? DateTime.now();
    final start = DateTime(
        date.year,
        date.month,
        date.day,
        _startTime?.hour ?? DateTime.now().hour,
        _startTime?.minute ?? DateTime.now().minute);
    try {
      await FirebaseFirestore.instance.collection('caminatas').add({
        'usuario': widget.usuario,
        'jefe': widget.jefe,
        'date': Timestamp.fromDate(date),
        'startAt': Timestamp.fromDate(start),
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Caminata registrada')));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando caminata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Formulario Caminata')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Jefatura: ${widget.jefe}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Usuario: ${widget.usuario}'),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: _pickStartTime,
              child: Text(_startTime == null
                  ? 'Seleccionar hora de inicio'
                  : 'Inicio: ${_startTime!.format(context)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 6,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'Notas'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: _saveCaminata,
                  child: const Text('Guardar caminata'),
                ),
              )
            ])
          ],
        ),
      ),
    );
  }
}
