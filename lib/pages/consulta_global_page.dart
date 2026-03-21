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
      // 1. entregas_cdr (colección)
      final cdrQuery = await FirebaseFirestore.instance
          .collection('entregas_cdr')
          .limit(50)
          .get();
      for (final doc in cdrQuery.docs) {
        final data = doc.data();
        if (data.values.any(
            (v) => v != null && v.toString().toLowerCase().contains(query))) {
          resultados.add(_ResultadoConsulta(
            origen: 'Entregas CDR',
            data: data,
          ));
        }
      }
      // 2. historial_entregas > cdr_firmadas
      final cdrFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('cdr_firmadas')
          .get();
      final cdrFirmadasItems = cdrFirmadasDoc.data()?['items'] as List?;
      if (cdrFirmadasItems != null) {
        for (final item in cdrFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'CDR Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 3. historial_entregas > cyc_firmadas
      final cycFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('cyc_firmadas')
          .get();
      final cycFirmadasItems = cycFirmadasDoc.data()?['items'] as List?;
      if (cycFirmadasItems != null) {
        for (final item in cycFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'CyC Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 4. historial_entregas > dev_mbodas_firmadas
      final devMbodasFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('dev_mbodas_firmadas')
          .get();
      final devMbodasFirmadasItems =
          devMbodasFirmadasDoc.data()?['items'] as List?;
      if (devMbodasFirmadasItems != null) {
        for (final item in devMbodasFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Dev Mbodas Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 5. historial_entregas > dev_xd_firmadas
      final devXdFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('dev_xd_firmadas')
          .get();
      final devXdFirmadasItems = devXdFirmadasDoc.data()?['items'] as List?;
      if (devXdFirmadasItems != null) {
        for (final item in devXdFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Dev XD Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 6. historial_entregas > devcan_firmadas
      final devcanFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('devcan_firmadas')
          .get();
      final devcanFirmadasItems = devcanFirmadasDoc.data()?['items'] as List?;
      if (devcanFirmadasItems != null) {
        for (final item in devcanFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'DevCan Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 7. historial_entregas > mbodas_firmadas
      final mbodasFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('mbodas_firmadas')
          .get();
      final mbodasFirmadasItems = mbodasFirmadasDoc.data()?['items'] as List?;
      if (mbodasFirmadasItems != null) {
        for (final item in mbodasFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Mbodas Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 8. historial_entregas > recogidos_firmadas
      final recogidosFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('recogidos_firmadas')
          .get();
      final recogidosFirmadasItems =
          recogidosFirmadasDoc.data()?['items'] as List?;
      if (recogidosFirmadasItems != null) {
        for (final item in recogidosFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Recogidos Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 9. historial_entregas > transferencias_retornos_firmadas
      final tfretFirmadasDoc = await FirebaseFirestore.instance
          .collection('historial_entregas')
          .doc('transferencias_retornos_firmadas')
          .get();
      final tfretFirmadasItems = tfretFirmadasDoc.data()?['items'] as List?;
      if (tfretFirmadasItems != null) {
        for (final item in tfretFirmadasItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            resultados.add(_ResultadoConsulta(
              origen: 'Transferencias y Retornos Firmadas',
              data: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      // 10. hoja_ruta (colección)
      final hojaRutaDocs = await FirebaseFirestore.instance
          .collection('hoja_ruta')
          .limit(50)
          .get();
      for (final doc in hojaRutaDocs.docs) {
        final data = doc.data();
        if (data.values.any(
            (v) => v != null && v.toString().toLowerCase().contains(query))) {
          resultados.add(_ResultadoConsulta(
            origen: 'Hoja de Ruta',
            data: data,
          ));
        }
      }
      // 11. paqueteria_externa (colección)
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
