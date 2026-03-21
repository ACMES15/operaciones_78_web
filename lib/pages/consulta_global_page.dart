import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ConsultaGlobalPage extends StatefulWidget {
  const ConsultaGlobalPage({Key? key}) : super(key: key);

  @override
  State<ConsultaGlobalPage> createState() => _ConsultaGlobalPageState();
}

class _ResultadoConsulta {
  final String origen;
  final Map<String, dynamic> data;
  _ResultadoConsulta({required this.origen, required this.data});

  Map<String, dynamic> toJson() => {
        'origen': origen,
        'data': data,
      };
  static _ResultadoConsulta fromJson(Map<String, dynamic> json) =>
      _ResultadoConsulta(
        origen: json['origen'] ?? '',
        data: Map<String, dynamic>.from(json['data'] ?? {}),
      );
}

class _ConsultaGlobalPageState extends State<ConsultaGlobalPage> {
  final TextEditingController _controller = TextEditingController();
  bool _buscando = false;
  String _query = '';
  List<_ResultadoConsulta> _resultados = [];
  String? _error;

  Future<void> _buscar() async {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return;
    setState(() {
      _buscando = true;
      _resultados = [];
      _error = null;
      _query = query;
    });
    try {
      final cacheKey = 'consulta_global_cache_$query';
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        // Recuperar del caché
        final List<dynamic> jsonList = jsonDecode(cached);
        final resultados =
            jsonList.map((e) => _ResultadoConsulta.fromJson(e)).toList();
        setState(() {
          _resultados = resultados;
          _buscando = false;
        });
        return;
      }
      // Si no está en caché, consultar Firestore
      final resultados = <_ResultadoConsulta>[];
      // --- Historiales principales ---
      // 1. Hoja de XD
      final xdDocs = await FirebaseFirestore.instance
          .collection('hoja_de_xd_historial')
          .limit(50)
          .get();
      for (final doc in xdDocs.docs) {
        final data = doc.data();
        if ((data['usuario']?.toString().toLowerCase().contains(query) ??
                false) ||
            (data['fileName']?.toString().toLowerCase().contains(query) ??
                false) ||
            (data['datos'] is Map &&
                (data['datos'] as Map)
                    .values
                    .any((v) => v.toString().toLowerCase().contains(query)))) {
          resultados.add(_ResultadoConsulta(
            origen: 'Hoja de XD',
            data: data,
          ));
        }
      }
      // 2. Carta Porte
      final cpDocs = await FirebaseFirestore.instance
          .collection('cartas_porte')
          .limit(50)
          .get();
      for (final doc in cpDocs.docs) {
        final data = doc.data();
        if (data.values.any(
            (v) => v != null && v.toString().toLowerCase().contains(query))) {
          resultados.add(_ResultadoConsulta(
            origen: 'Carta Porte',
            data: data,
          ));
        }
      }
      // 3. DevCan
      final devcanDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('devcan_firmadas')
          .get();
      final devcanItems = devcanDoc.data()?['items'] as List?;
      if (devcanItems != null) {
        for (final item in devcanItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'DevCan',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 4. Dev Mbodas
      final devmbodasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('dev_mbodas_firmadas')
          .get();
      final devmbodasItems = devmbodasDoc.data()?['items'] as List?;
      if (devmbodasItems != null) {
        for (final item in devmbodasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Dev Mbodas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 5. Recogidos
      final recogidosDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('recogidos_firmadas')
          .get();
      final recogidosItems = recogidosDoc.data()?['items'] as List?;
      if (recogidosItems != null) {
        for (final item in recogidosItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Recogidos',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 6. CDR
      final cdrDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('cdr_firmadas')
          .get();
      final cdrItems = cdrDoc.data()?['items'] as List?;
      if (cdrItems != null) {
        for (final item in cdrItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'CDR',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 7. CyC
      final cycDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('cyc_firmadas')
          .get();
      final cycItems = cycDoc.data()?['items'] as List?;
      if (cycItems != null) {
        for (final item in cycItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'CyC',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 8. Paquetería Externa
      final paqDocs = await FirebaseFirestore.instance
          .collection('paqueteria_externa')
          .limit(50)
          .get();
      for (final doc in paqDocs.docs) {
        final data = doc.data();
        if (data.values.any(
            (v) => v != null && v.toString().toLowerCase().contains(query))) {
          resultados.add(_ResultadoConsulta(
            origen: 'Paquetería Externa',
            data: data,
          ));
        }
      }
      // 9. Transferencias y Retornos
      final tfretDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('transferencias_retornos_firmadas')
          .get();
      final tfretItems = tfretDoc.data()?['items'] as List?;
      if (tfretItems != null) {
        for (final item in tfretItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Transferencias y Retornos',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // Guardar en caché
      final jsonList = resultados.map((e) => e.toJson()).toList();
      await prefs.setString(cacheKey, jsonEncode(jsonList));
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al buscar: ' + e.toString();
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta Global'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Buscar en todos los historiales',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_buscando && _resultados.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _resultados.length,
                  itemBuilder: (context, i) {
                    final r = _resultados[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(r.origen,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_resumen(r.data)),
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _mostrarDetalle(r),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!_buscando && _resultados.isEmpty && _query.isNotEmpty)
              const Text('No se encontraron resultados.'),
          ],
        ),
      ),
    );
  }

  String _resumen(Map<String, dynamic> data) {
    // Muestra los primeros campos relevantes
    final buffer = StringBuffer();
    int count = 0;
    data.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty && count < 3) {
        buffer.write('$k: $v  ');
        count++;
      }
    });
    return buffer.toString();
  }

  void _mostrarDetalle(_ResultadoConsulta r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detalle - ${r.origen}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: r.data.entries
                .map((e) => Text('${e.key}: ${e.value}'))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
