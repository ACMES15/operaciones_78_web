import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'registro_caminata_form.dart';

class RegistroCaminatasPage extends StatefulWidget {
  final String usuario;
  const RegistroCaminatasPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<RegistroCaminatasPage> createState() => _RegistroCaminatasPageState();
}

class _RegistroCaminatasPageState extends State<RegistroCaminatasPage> {
  bool _loading = true;
  Map<String, String> _plantilla = {};
  List<String> _jefes = [];
  DateTime? _selectedDate;

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

  void _openHistoricForId(String docId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.black,
            title: const Text('Histórico Caminatas',
                style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                  tooltip: 'Exportar PDF',
                  onPressed: () async {
                    // fetch fresh data then export
                    final data = await _getCaminataData(docId);
                    if (data != null) await _exportCaminataPdf(data, docId);
                  },
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white))
            ]),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _getCaminataData(docId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data;
            if (data == null)
              return const Center(child: Text('Caminata no encontrada'));
            final seccion = data['seccion'] ?? '';
            final tsVal = data['date'];
            String dateStr = '';
            if (tsVal is Timestamp) {
              dateStr = tsVal.toDate().toLocal().toString();
            } else if (data['createdAt'] is Timestamp) {
              dateStr = (data['createdAt'] as Timestamp)
                  .toDate()
                  .toLocal()
                  .toString();
            } else if (tsVal is String) {
              dateStr = tsVal;
            }

            final score = data['score'] ?? '';
            final notes = data['notes'] ?? '';
            List<dynamic> bodegaPhotos =
                (data['bodega']?['photos'] as List<dynamic>?)?.toList() ?? [];
            List<dynamic> pisoPhotos =
                (data['piso']?['photos'] as List<dynamic>?)?.toList() ?? [];
            // fallback to local Hive thumbs for this device
            try {
              const boxName = 'caminata_thumbs';
              if (Hive.isBoxOpen(boxName)) {
                final box = Hive.box(boxName);
                final raw = box.get('caminata_$docId');
                if (raw != null) {
                  try {
                    final Map<String, dynamic> thumbs =
                        Map<String, dynamic>.from(jsonDecode(raw));
                    if (bodegaPhotos.isEmpty)
                      bodegaPhotos =
                          (thumbs['bodega'] as List<dynamic>?)?.toList() ?? [];
                    if (pisoPhotos.isEmpty)
                      pisoPhotos =
                          (thumbs['piso'] as List<dynamic>?)?.toList() ?? [];
                  } catch (_) {}
                }
              }
            } catch (_) {}

            Widget _photosWrap(List<dynamic> list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: list.map((s) {
                  if (s is Uint8List) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(s,
                          width: 100, height: 100, fit: BoxFit.cover),
                    );
                  }
                  if (s is String) {
                    // URL -> network image
                    if (s.startsWith('http')) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(s,
                            width: 100, height: 100, fit: BoxFit.cover),
                      );
                    }
                    try {
                      final bytes = base64Decode(s);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(bytes,
                            width: 100, height: 100, fit: BoxFit.cover),
                      );
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  }
                  return const SizedBox.shrink();
                }).toList(),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Executive header with big percent
                      Row(children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(
                              value: (score is num) ? (score / 100) : 0,
                              strokeWidth: 10,
                              color: Colors.blue,
                              backgroundColor: Colors.blue.withOpacity(0.2),
                            ),
                            Text('${score.toString()}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sección: $seccion',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                const SizedBox(height: 6),
                                Text('Fecha: $dateStr'),
                                const SizedBox(height: 6),
                                Text('Score: $score'),
                              ]),
                        )
                      ]),
                      const SizedBox(height: 12),
                      Text('Sección: $seccion',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Fecha: $dateStr'),
                      const SizedBox(height: 8),
                      Text('Score: $score'),
                      const SizedBox(height: 8),
                      if (notes.toString().isNotEmpty) ...[
                        const Text('Notas:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(notes.toString()),
                        const SizedBox(height: 8),
                      ],
                      if (bodegaPhotos.isNotEmpty) ...[
                        const Text('Fotos Bodega:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _photosWrap(bodegaPhotos),
                        const SizedBox(height: 12),
                      ],
                      if (pisoPhotos.isNotEmpty) ...[
                        const Text('Fotos Piso:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _photosWrap(pisoPhotos),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }));
  }

  Future<Map<String, dynamic>?> _getCaminataData(String docId) async {
    final key = 'caminata_$docId';
    const boxName = 'caminatas_cache';
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    final box = Hive.box(boxName);
    if (box.containsKey(key)) {
      try {
        final cached = box.get(key);
        if (cached != null) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(jsonDecode(cached));
          // refresh in background
          FirebaseFirestore.instance
              .collection('caminatas')
              .doc(docId)
              .get()
              .then((snap) async {
            if (snap.exists && snap.data() != null) {
              try {
                box.put(key, jsonEncode(snap.data()));
              } catch (_) {}
            }
          }).catchError((_) {});
          return data;
        }
      } catch (_) {}
    }

    // no cache or parse failed: fetch from server and cache
    final snap = await FirebaseFirestore.instance
        .collection('caminatas')
        .doc(docId)
        .get();
    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data() as Map<String, dynamic>;
    try {
      box.put(key, jsonEncode(data));
    } catch (_) {}
    return data;
  }

  Future<void> _exportCaminataPdf(
      Map<String, dynamic> data, String docId) async {
    final pdf = pw.Document();
    final seccion = data['seccion'] ?? '';
    final title = 'Caminata - Sección $seccion';
    final score = data['score'] ?? 0;
    final notes = data['notes'] ?? '';

    // Prefer full-size photos (Storage URLs). If empty, try local Hive thumbs for this device.
    List<dynamic> bodegaPhotos =
        (data['bodega']?['photos'] as List<dynamic>?)?.toList() ?? [];
    List<dynamic> pisoPhotos =
        (data['piso']?['photos'] as List<dynamic>?)?.toList() ?? [];

    if ((bodegaPhotos.isEmpty || pisoPhotos.isEmpty)) {
      try {
        const boxName = 'caminata_thumbs';
        if (!Hive.isBoxOpen(boxName)) await Hive.openBox(boxName);
        final box = Hive.box(boxName);
        final raw = box.get('caminata_$docId');
        if (raw != null) {
          try {
            final Map<String, dynamic> thumbs =
                Map<String, dynamic>.from(jsonDecode(raw));
            if (bodegaPhotos.isEmpty)
              bodegaPhotos =
                  (thumbs['bodega'] as List<dynamic>?)?.toList() ?? [];
            if (pisoPhotos.isEmpty)
              pisoPhotos = (thumbs['piso'] as List<dynamic>?)?.toList() ?? [];
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Normalize photos into bytes (Uint8List). For URL strings, download them.
    Future<List<Uint8List>> _normalizePhotos(List<dynamic> list) async {
      final out = <Uint8List>[];
      for (final s in list) {
        try {
          if (s is Uint8List) {
            out.add(s);
          } else if (s is String) {
            if (s.startsWith('http')) {
              final res = await http.get(Uri.parse(s));
              if (res.statusCode == 200) out.add(res.bodyBytes);
            } else {
              out.add(base64Decode(s));
            }
          }
        } catch (_) {
          // skip failures
        }
      }
      return out;
    }

    final bodegaBytes = await _normalizePhotos(bodegaPhotos);
    final pisoBytes = await _normalizePhotos(pisoPhotos);

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 26, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 12),
                  pw.Row(children: [
                    pw.Container(
                        width: 140,
                        height: 140,
                        child: pw.Center(
                            child: pw.Text('$score%',
                                style: pw.TextStyle(
                                    fontSize: 36,
                                    fontWeight: pw.FontWeight.bold)))),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text('Sección: ${data['seccion'] ?? ''}',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 6),
                          pw.Text(
                              'Fecha: ${data['date'] is Timestamp ? (data['date'] as Timestamp).toDate().toLocal().toString() : data['date']?.toString() ?? ''}'),
                          pw.SizedBox(height: 6),
                          pw.Text('Score: $score'),
                        ]))
                  ]),
                  pw.Divider(),
                  pw.Text('Preguntas - Bodega',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Bullet(
                      text:
                          'Bodega en orden: ${data['bodega']?['orden'] == true ? 'Sí' : 'No'}'),
                  pw.Bullet(
                      text:
                          'Mercancía tirada: ${data['bodega']?['mercanciaTirada'] == true ? 'Sí' : 'No'}'),
                  pw.Bullet(
                      text:
                          'Devolución MKP: ${data['bodega']?['devolucionMkp'] == true ? 'Sí' : 'No'}'),
                  pw.Bullet(
                      text:
                          'Suministro exceso: ${data['bodega']?['suministroExceso'] == true ? 'Sí' : 'No'}'),
                  pw.Bullet(
                      text:
                          'Contenedores rezagados: ${data['bodega']?['contenedoresRezagados'] == true ? 'Sí' : 'No'}'),
                  pw.SizedBox(height: 8),
                  pw.Text('Preguntas - Piso',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Bullet(
                      text:
                          'Orden en Terminal: ${data['piso']?['ordenTerminal'] == true ? 'Sí' : 'No'}'),
                  pw.Bullet(
                      text:
                          'Mercancía de otras secciones: ${data['piso']?['mercanciaOtras'] == true ? 'Sí' : 'No'}'),
                  pw.Bullet(
                      text:
                          'Objetos personales: ${data['piso']?['objetosPersonales'] == true ? 'Sí' : 'No'}'),
                  pw.Bullet(
                      text:
                          'Orden en lugar de Jefe: ${data['piso']?['ordenLugarJefe'] == true ? 'Sí' : 'No'}'),
                  pw.SizedBox(height: 12),
                  if (notes.toString().isNotEmpty)
                    pw.Column(children: [
                      pw.Text('Notas:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(notes.toString())
                    ]),
                  pw.SizedBox(height: 12),
                  if (bodegaBytes.isNotEmpty)
                    pw.Column(children: [
                      pw.Text('Fotos Bodega:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Wrap(
                          children: bodegaBytes
                              .map((bytes) => pw.Container(
                                  margin: const pw.EdgeInsets.all(4),
                                  child: pw.Image(pw.MemoryImage(bytes),
                                      width: 120,
                                      height: 120,
                                      fit: pw.BoxFit.cover)))
                              .toList())
                    ]),
                  pw.SizedBox(height: 12),
                  if (pisoBytes.isNotEmpty)
                    pw.Column(children: [
                      pw.Text('Fotos Piso:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Wrap(
                          children: pisoBytes
                              .map((bytes) => pw.Container(
                                  margin: const pw.EdgeInsets.all(4),
                                  child: pw.Image(pw.MemoryImage(bytes),
                                      width: 120,
                                      height: 120,
                                      fit: pw.BoxFit.cover)))
                              .toList())
                    ]),
                ]),
          );
        }));

    try {
      final bytes = await pdf.save();
      await Printing.sharePdf(
          bytes: bytes, filename: 'caminata_seccion_$seccion.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error exportando PDF: $e')));
    }
  }

  void _showHistoricoListPage() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.black,
            title: const Text('Histórico Caminatas',
                style: TextStyle(color: Colors.white))),
        body: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('caminatas')
              .orderBy('createdAt', descending: true)
              .limit(200)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No hay caminatas registradas'));
            }
            final docs = snapshot.data!.docs;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final seccion = data['seccion'] ?? '';
                final score = data['score'] ?? '';
                String dateStr = '';
                if (data['date'] is Timestamp) {
                  dateStr =
                      (data['date'] as Timestamp).toDate().toLocal().toString();
                } else if (data['createdAt'] is Timestamp) {
                  dateStr = (data['createdAt'] as Timestamp)
                      .toDate()
                      .toLocal()
                      .toString();
                }

                // thumbnail candidate
                Widget thumb = const SizedBox.shrink();
                try {
                  List<dynamic> bphotos = [];
                  List<dynamic> pphotos = [];
                  const boxName = 'caminata_thumbs';
                  try {
                    if (Hive.isBoxOpen(boxName)) {
                      final box = Hive.box(boxName);
                      final key = 'caminata_${doc.id}';
                      if (box.containsKey(key)) {
                        final raw = box.get(key);
                        if (raw != null) {
                          try {
                            final Map<String, dynamic> thumbs =
                                Map<String, dynamic>.from(jsonDecode(raw));
                            bphotos = (thumbs['bodega'] as List<dynamic>?)
                                    ?.toList() ??
                                [];
                            pphotos =
                                (thumbs['piso'] as List<dynamic>?)?.toList() ??
                                    [];
                          } catch (_) {}
                        }
                      }
                    }
                  } catch (_) {}

                  if (bphotos.isEmpty) {
                    bphotos = (data['bodega']?['photos'] as List<dynamic>?)
                            ?.toList() ??
                        [];
                  }
                  if (pphotos.isEmpty) {
                    pphotos =
                        (data['piso']?['photos'] as List<dynamic>?)?.toList() ??
                            [];
                  }
                  final cand = (bphotos.isNotEmpty)
                      ? bphotos.first
                      : (pphotos.isNotEmpty ? pphotos.first : null);
                  if (cand != null) {
                    if (cand is String) {
                      if (cand.startsWith('http')) {
                        thumb = ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(cand,
                                width: 80, height: 80, fit: BoxFit.cover));
                      } else {
                        final bytes = base64Decode(cand);
                        thumb = ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(bytes,
                                width: 80, height: 80, fit: BoxFit.cover));
                      }
                    } else if (cand is Uint8List) {
                      thumb = ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(cand,
                              width: 80, height: 80, fit: BoxFit.cover));
                    }
                  }
                } catch (_) {}

                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: thumb,
                    title: Text('Sección: $seccion'),
                    subtitle: Text('Fecha: $dateStr\nScore: $score'),
                    isThreeLine: true,
                    onTap: () => _showCaminataDialog(doc.id),
                  ),
                );
              },
            );
          },
        ),
      );
    }));
  }

  Future<void> _showCaminataDialog(String docId) async {
    showDialog(
        context: context,
        builder: (ctx) {
          return FutureBuilder<Map<String, dynamic>?>(
              future: _getCaminataData(docId),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return AlertDialog(
                      content: SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator())));
                }
                final data = snap.data;
                if (data == null) {
                  return AlertDialog(
                      content: const Text('No se encontró la caminata'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cerrar'))
                      ]);
                }

                final seccion = data['seccion'] ?? '';
                final notes = data['notes'] ?? '';
                final score = data['score'] ?? '';
                final tsVal = data['date'];
                String dateStr = '';
                if (tsVal is Timestamp)
                  dateStr = tsVal.toDate().toLocal().toString();
                else if (data['createdAt'] is Timestamp)
                  dateStr = (data['createdAt'] as Timestamp)
                      .toDate()
                      .toLocal()
                      .toString();

                Widget _photosWrap(List<dynamic> list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: list.map((s) {
                      if (s is Uint8List) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(s,
                              width: 100, height: 100, fit: BoxFit.cover),
                        );
                      }
                      if (s is String) {
                        try {
                          final bytes = base64Decode(s);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(bytes,
                                width: 100, height: 100, fit: BoxFit.cover),
                          );
                        } catch (_) {
                          return const SizedBox.shrink();
                        }
                      }
                      return const SizedBox.shrink();
                    }).toList(),
                  );
                }

                return AlertDialog(
                  content: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child:
                                  Stack(alignment: Alignment.center, children: [
                                CircularProgressIndicator(
                                    value: (score is num) ? (score / 100) : 0,
                                    strokeWidth: 8,
                                    color: Colors.blue,
                                    backgroundColor:
                                        Colors.blue.withOpacity(0.2)),
                                Text('${score.toString()}%',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('Sección: $seccion',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text('Fecha: $dateStr')
                                ])),
                          ]),
                          const SizedBox(height: 12),
                          if (notes.toString().isNotEmpty) ...[
                            const Text('Notas:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(notes.toString()),
                            const SizedBox(height: 8),
                          ],
                          if ((data['bodega']?['photos'] ?? []).isNotEmpty) ...[
                            const Text('Fotos Bodega:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _photosWrap(data['bodega']?['photos'] ?? []),
                            const SizedBox(height: 8),
                          ],
                          if ((data['piso']?['photos'] ?? []).isNotEmpty) ...[
                            const Text('Fotos Piso:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _photosWrap(data['piso']?['photos'] ?? []),
                          ],
                        ]),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _exportCaminataPdf(data, docId);
                        },
                        child: const Text('Exportar PDF')),
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cerrar'))
                  ],
                );
              });
        });
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
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    if (isMobile) {
                      // Mobile: Historico arriba, jefaturas abajo (scrollable)
                      return Column(children: [
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white),
                              onPressed: _showHistoricoListPage,
                              child: const Text('Historico'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(8.0),
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
                                    onPressed: () async {
                                      final docId = await Navigator.of(context)
                                          .push(MaterialPageRoute(
                                              builder: (_) =>
                                                  RegistroCaminataForm(
                                                      usuario: widget.usuario,
                                                      jefe: jefe,
                                                      date: _selectedDate)));
                                      if (docId != null && docId is String) {
                                        _openHistoricForId(docId);
                                      }
                                    },
                                    child: const Text('Inicio de caminata'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ]);
                    }

                    // Tablet / Desktop: two cards side-by-side
                    return Row(children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          elevation: 2,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8.0),
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
                                  onPressed: () async {
                                    final docId = await Navigator.of(context)
                                        .push(MaterialPageRoute(
                                            builder: (_) =>
                                                RegistroCaminataForm(
                                                    usuario: widget.usuario,
                                                    jefe: jefe,
                                                    date: _selectedDate)));
                                    if (docId != null && docId is String) {
                                      _openHistoricForId(docId);
                                    }
                                  },
                                  child: const Text('Inicio de caminata'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white),
                                    onPressed: _showHistoricoListPage,
                                    child: const Text('Historico'),
                                  ),
                                ]),
                          ),
                        ),
                      ),
                    ]);
                  }),
          ),
        ]),
      ),
    );
  }
}
