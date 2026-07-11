import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:file_picker/file_picker.dart';

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
  final TextEditingController _seccionController = TextEditingController();
  final TextEditingController _terminalController = TextEditingController();
  TimeOfDay? _startTime;

  // Bodega answers
  bool _bodegaOrden = false;
  bool _bodegaMercanciaTirada = false;
  bool _bodegaDevolucionMkp = false;
  bool _bodegaSuministroExceso = false;
  bool _bodegaContenedoresRezagados = false; // NEW

  // Piso answers
  bool _pisoOrdenTerminal = false;
  bool _pisoMercanciaOtras = false;
  bool _pisoObjetosPersonales = false;
  bool _pisoOrdenLugarJefe = false;

  // Photos stored as bytes for preview; not uploaded here
  final List<Uint8List> _bodegaPhotos = [];
  final List<Uint8List> _pisoPhotos = [];

  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _seccionController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final now = TimeOfDay.now();
    final res =
        await showTimePicker(context: context, initialTime: _startTime ?? now);
    if (res != null) setState(() => _startTime = res);
  }

  int _computePercent() {
    final favB1 = _bodegaOrden;
    final favB2 = !_bodegaMercanciaTirada;
    final favB3 = !_bodegaDevolucionMkp;
    final favB4 = !_bodegaSuministroExceso;
    final favB5 = !_bodegaContenedoresRezagados;
    final favP1 = _pisoOrdenTerminal;
    final favP2 = !_pisoMercanciaOtras;
    final favP3 = !_pisoObjetosPersonales;
    final favP4 = _pisoOrdenLugarJefe;
    final favorableCount = (favB1 ? 1 : 0) +
        (favB2 ? 1 : 0) +
        (favB3 ? 1 : 0) +
        (favB4 ? 1 : 0) +
        (favB5 ? 1 : 0) +
        (favP1 ? 1 : 0) +
        (favP2 ? 1 : 0) +
        (favP3 ? 1 : 0) +
        (favP4 ? 1 : 0);
    const total = 9;
    return ((favorableCount / total) * 100).round();
  }

  Future<void> _pickPhotosForDivision(String division,
      {bool fromCamera = true}) async {
    try {
      if (!kIsWeb) {
        Permission perm;
        if (fromCamera) {
          perm = Permission.camera;
        } else {
          perm = Platform.isAndroid ? Permission.storage : Permission.photos;
        }
        final status = await perm.request();
        if (!status.isGranted) {
          final open = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permiso requerido'),
              content: const Text(
                  'La aplicación necesita permiso para acceder a la cámara/galería. Abrir ajustes?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('No')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Abrir ajustes')),
              ],
            ),
          );
          if (open == true) openAppSettings();
          return;
        }
      }

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        if (fromCamera) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'La cámara no está disponible en escritorio. Use Galería.')));
          return;
        }
        final result = await FilePicker.platform
            .pickFiles(type: FileType.image, allowMultiple: true);
        if (result != null && result.files.isNotEmpty) {
          for (final f in result.files) {
            final bytes = f.bytes ?? await File(f.path!).readAsBytes();
            setState(() {
              if (division == 'bodega')
                _bodegaPhotos.add(bytes);
              else
                _pisoPhotos.add(bytes);
            });
          }
        }
      } else {
        if (fromCamera) {
          final XFile? photo = await _picker.pickImage(
              source: ImageSource.camera, imageQuality: 70);
          if (photo != null) {
            final bytes = await photo.readAsBytes();
            setState(() {
              if (division == 'bodega')
                _bodegaPhotos.add(bytes);
              else
                _pisoPhotos.add(bytes);
            });
          }
        } else {
          final List<XFile>? photos =
              await _picker.pickMultiImage(imageQuality: 70);
          if (photos != null && photos.isNotEmpty) {
            for (final p in photos) {
              final bytes = await p.readAsBytes();
              setState(() {
                if (division == 'bodega')
                  _bodegaPhotos.add(bytes);
                else
                  _pisoPhotos.add(bytes);
              });
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando foto: $e')));
    }
  }

  Future<void> _saveCaminata() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final date = widget.date ?? DateTime.now();
    final start = DateTime(
        date.year,
        date.month,
        date.day,
        _startTime?.hour ?? DateTime.now().hour,
        _startTime?.minute ?? DateTime.now().minute);
    final percent = _computePercent();

    try {
      final docRef = FirebaseFirestore.instance.collection('caminatas').doc();
      await docRef.set({
        'usuario': widget.usuario,
        'jefe': widget.jefe,
        'date': Timestamp.fromDate(date),
        'startAt': Timestamp.fromDate(start),
        'notes': _notesController.text.trim(),
        'seccion': _seccionController.text.trim(),
        'terminal': _terminalController.text.trim(),
        'bodega': {
          'orden': _bodegaOrden,
          'mercanciaTirada': _bodegaMercanciaTirada,
          'devolucionMkp': _bodegaDevolucionMkp,
          'suministroExceso': _bodegaSuministroExceso,
          'contenedoresRezagados': _bodegaContenedoresRezagados,
          'photosCount': _bodegaPhotos.length,
          'photos': [],
        },
        'piso': {
          'ordenTerminal': _pisoOrdenTerminal,
          'mercanciaOtras': _pisoMercanciaOtras,
          'objetosPersonales': _pisoObjetosPersonales,
          'ordenLugarJefe': _pisoOrdenLugarJefe,
          'photosCount': _pisoPhotos.length,
          'photos': [],
        },
        'score': percent,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Caminata registrada. Fotos subiendo en background')));
      Navigator.of(context).pop(docRef.id);

      // start background upload without awaiting
      _uploadPhotosInBackground(docRef.id, List<Uint8List>.from(_bodegaPhotos),
          List<Uint8List>.from(_pisoPhotos), {
        'orden': _bodegaOrden,
        'mercanciaTirada': _bodegaMercanciaTirada,
        'devolucionMkp': _bodegaDevolucionMkp,
        'suministroExceso': _bodegaSuministroExceso,
        'contenedoresRezagados': _bodegaContenedoresRezagados,
      }, {
        'ordenTerminal': _pisoOrdenTerminal,
        'mercanciaOtras': _pisoMercanciaOtras,
        'objetosPersonales': _pisoObjetosPersonales,
        'ordenLugarJefe': _pisoOrdenLugarJefe,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando caminata: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadPhotosInBackground(
      String docId,
      List<Uint8List> bodegaPhotos,
      List<Uint8List> pisoPhotos,
      Map<String, dynamic> bodegaAnswers,
      Map<String, dynamic> pisoAnswers) async {
    final storage = firebase_storage.FirebaseStorage.instance;
    final docRef =
        FirebaseFirestore.instance.collection('caminatas').doc(docId);
    final List<String> bodegaUrls = [];
    final List<String> pisoUrls = [];
    try {
      for (var i = 0; i < bodegaPhotos.length; i++) {
        final bytes = bodegaPhotos[i];
        final ref = storage.ref().child(
            'caminatas/$docId/bodega/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        final snap = await ref.putData(bytes,
            firebase_storage.SettableMetadata(contentType: 'image/jpeg'));
        final url = await snap.ref.getDownloadURL();
        bodegaUrls.add(url);
      }
      for (var i = 0; i < pisoPhotos.length; i++) {
        final bytes = pisoPhotos[i];
        final ref = storage.ref().child(
            'caminatas/$docId/piso/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        final snap = await ref.putData(bytes,
            firebase_storage.SettableMetadata(contentType: 'image/jpeg'));
        final url = await snap.ref.getDownloadURL();
        pisoUrls.add(url);
      }
      final bodegaMap = {
        ...bodegaAnswers,
        'photosCount': bodegaUrls.length,
        'photos': bodegaUrls
      };
      final pisoMap = {
        ...pisoAnswers,
        'photosCount': pisoUrls.length,
        'photos': pisoUrls
      };
      await docRef.update({'bodega': bodegaMap, 'piso': pisoMap});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Fotos subidas: bodega ${bodegaUrls.length}, piso ${pisoUrls.length}')));
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error subiendo fotos: $e')));
      });
    }
  }

  Widget _buildPhotoRow(List<Uint8List> photos) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: photos
          .map((b) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(b, width: 80, height: 80, fit: BoxFit.cover)))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = _computePercent();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Formulario', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(
                width: 120,
                height: 120,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 10,
                      color: Colors.blue,
                      backgroundColor: Colors.blue.withOpacity(0.2)),
                  Text('$percent%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Jefatura: ${widget.jefe}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _seccionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Sección (número)',
                          border: OutlineInputBorder())),
                ]))
          ]),
          const SizedBox(height: 8),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white),
              onPressed: _pickStartTime,
              child: Text(_startTime == null
                  ? 'Seleccionar hora de inicio'
                  : 'Inicio: ${_startTime!.format(context)}')),
          const SizedBox(height: 12),
          Text('BODEGA', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
              title: const Text('Bodega en orden?'),
              value: _bodegaOrden,
              onChanged: (v) => setState(() => _bodegaOrden = v)),
          SwitchListTile(
              title: const Text('Mercancía tirada?'),
              value: _bodegaMercanciaTirada,
              onChanged: (v) => setState(() => _bodegaMercanciaTirada = v)),
          SwitchListTile(
              title: const Text('Devolución MKP?'),
              value: _bodegaDevolucionMkp,
              onChanged: (v) => setState(() => _bodegaDevolucionMkp = v)),
          SwitchListTile(
              title: const Text('Suministro en exceso?'),
              value: _bodegaSuministroExceso,
              onChanged: (v) => setState(() => _bodegaSuministroExceso = v)),
          SwitchListTile(
              title: const Text('Contenedores rezagados?'),
              value: _bodegaContenedoresRezagados,
              onChanged: (v) =>
                  setState(() => _bodegaContenedoresRezagados = v)),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    _pickPhotosForDivision('bodega', fromCamera: true),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar foto Bodega')),
            const SizedBox(width: 8),
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    _pickPhotosForDivision('bodega', fromCamera: false),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería')),
          ]),
          const SizedBox(height: 8),
          if (_bodegaPhotos.isNotEmpty) _buildPhotoRow(_bodegaPhotos),
          const Divider(height: 28),
          Text('PISO', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
              controller: _terminalController,
              decoration: const InputDecoration(
                  labelText: 'Terminal', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          SwitchListTile(
              title: const Text('Orden en Terminal?'),
              value: _pisoOrdenTerminal,
              onChanged: (v) => setState(() => _pisoOrdenTerminal = v)),
          SwitchListTile(
              title: const Text('Mercancía de otras secciones?'),
              value: _pisoMercanciaOtras,
              onChanged: (v) => setState(() => _pisoMercanciaOtras = v)),
          SwitchListTile(
              title: const Text('Objetos personales?'),
              value: _pisoObjetosPersonales,
              onChanged: (v) => setState(() => _pisoObjetosPersonales = v)),
          SwitchListTile(
              title: const Text('Orden en lugar de Jefe?'),
              value: _pisoOrdenLugarJefe,
              onChanged: (v) => setState(() => _pisoOrdenLugarJefe = v)),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    _pickPhotosForDivision('piso', fromCamera: true),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar foto Piso')),
            const SizedBox(width: 8),
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    _pickPhotosForDivision('piso', fromCamera: false),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería')),
          ]),
          const SizedBox(height: 8),
          if (_pisoPhotos.isNotEmpty) _buildPhotoRow(_pisoPhotos),
          const SizedBox(height: 12),
          TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'Notas')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white),
                    onPressed: _isSaving ? null : _saveCaminata,
                    child: Text(_isSaving
                        ? 'Guardando...'
                        : 'Guardar caminata — $percent%')))
          ])
        ]),
      ),
    );
  }
}
