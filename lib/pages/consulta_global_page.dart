import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class ConsultaGlobalPage extends StatefulWidget {
  const ConsultaGlobalPage({Key? key}) : super(key: key);

  @override
  State<ConsultaGlobalPage> createState() => _ConsultaGlobalPageState();
}

class _ResultadoConsulta {
  final String origen;
  final Map<String, dynamic> data;
  final List<String> matches;
  _ResultadoConsulta(
      {required this.origen, required this.data, required this.matches});

  Map<String, dynamic> toJson() => {
        'origen': origen,
        'data': data,
        'matches': matches,
      };
  static _ResultadoConsulta fromJson(Map<String, dynamic> json) =>
      _ResultadoConsulta(
        origen: json['origen'] ?? '',
        data: Map<String, dynamic>.from(json['data'] ?? {}),
        matches:
            (json['matches'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class _ConsultaGlobalPageState extends State<ConsultaGlobalPage> {
  final TextEditingController _controller = TextEditingController();
  bool _buscando = false;
  String _query = '';
  List<_ResultadoConsulta> _resultados = [];
  String? _error;
  bool _vistaEjecutivaExpandida = false;

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
      List<String> _findMatches(Map<String, dynamic> data, String q) {
        final List<String> m = [];
        data.forEach((k, v) {
          if (v != null && v.toString().toLowerCase().contains(q)) m.add(k);
        });
        return m;
      }

      // 1. entregas_cdr (colección)
      final cdrQuery = await FirebaseFirestore.instance
          .collection('entregas_cdr')
          .limit(50)
          .get();
      for (final doc in cdrQuery.docs) {
        final data = doc.data();
        final matches = _findMatches(Map<String, dynamic>.from(data), query);
        if (matches.isNotEmpty) {
          resultados.add(_ResultadoConsulta(
            origen: 'Entregas CDR',
            data: Map<String, dynamic>.from(data),
            matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'CDR Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'CyC Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'Dev Mbodas Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'Dev XD Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'DevCan Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'Mbodas Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'Recogidos Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'Transferencias y Retornos Firmadas',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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
        final matches = _findMatches(Map<String, dynamic>.from(data), query);
        if (matches.isNotEmpty) {
          resultados.add(_ResultadoConsulta(
            origen: 'Hoja de Ruta',
            data: Map<String, dynamic>.from(data),
            matches: matches,
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
        final matches = _findMatches(Map<String, dynamic>.from(data), query);
        if (matches.isNotEmpty) {
          resultados.add(_ResultadoConsulta(
            origen: 'Paquetería Externa',
            data: Map<String, dynamic>.from(data),
            matches: matches,
          ));
        }
      }

      // 12. guias_cyc (historial de guías CYC)
      final guiasCycDocs = await FirebaseFirestore.instance
          .collection('guias_cyc')
          .limit(100)
          .get();
      for (final doc in guiasCycDocs.docs) {
        final data = doc.data();
        final matches = _findMatches(Map<String, dynamic>.from(data), query);
        if (matches.isNotEmpty) {
          resultados.add(_ResultadoConsulta(
            origen: 'Historial Guias CYC',
            data: Map<String, dynamic>.from(data),
            matches: matches,
          ));
        }
      }

      // 13. registros entregas MKP (reporte_mkp_no_entregado)
      final mkpDoc = await FirebaseFirestore.instance
          .collection('reporte_mkp_no_entregado')
          .doc('pendientes')
          .get();
      final mkpItems = (mkpDoc.data()?['items'] ?? []) as List?;
      if (mkpItems != null) {
        for (final item in mkpItems) {
          if (item is Map &&
              item.values.any((v) =>
                  v != null && v.toString().toLowerCase().contains(query))) {
            final matches =
                _findMatches(Map<String, dynamic>.from(item), query);
            resultados.add(_ResultadoConsulta(
              origen: 'Registros Entregas MKP',
              data: Map<String, dynamic>.from(item),
              matches: matches,
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

  Widget _buildGroupCard(String origen, List<_ResultadoConsulta> items) {
    final count = items.length;
    final subtitle =
        count == 1 ? '1 coincidencia encontrada' : '$count coincidencias';
    final preview = items.isNotEmpty ? _resumen(items.first.data) : '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(origen,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(preview, style: const TextStyle(color: Colors.black))
            ]
          ],
        ),
        trailing: Icon(Icons.keyboard_arrow_right, color: Colors.green),
        onTap: () => _mostrarGrupoDetalle(origen, items),
      ),
    );
  }

  void _mostrarGrupoDetalle(String origen, List<_ResultadoConsulta> items) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Detalle: $origen',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close))
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (c, i) {
                    final it = items[i];
                    return ListTile(
                      title: Text('Item ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_resumen(it.data)),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.green),
                      onTap: () {
                        Navigator.pop(ctx);
                        _mostrarDetalleEjecutivo(it, null);
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: items.length,
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'))
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleEjecutivo(_ResultadoConsulta r, String? campo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.origen,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        if (campo != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(campo,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black54)),
                                const SizedBox(height: 6),
                                Text(r.data[campo]?.toString() ?? '-',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close))
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: r.data.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(e.key,
                                  style:
                                      const TextStyle(color: Colors.black54))),
                          const SizedBox(width: 12),
                          Expanded(
                              flex: 2,
                              child: Text(e.value?.toString() ?? '-',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final content = campo != null
                          ? '${campo}: ${r.data[campo]}'
                          : r.data.entries
                              .map((e) => '${e.key}: ${e.value}')
                              .join('\n');
                      Clipboard.setData(ClipboardData(text: content));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Detalle copiado')));
                    },
                    child: const Text('Copiar'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Consulta Global'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8)
                      ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: TextField(
                      controller: _controller,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Buscar en todos los historiales',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _buscar(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Buscar',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_buscando && _resultados.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Executive metrics row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMetricCard('Total resultados',
                              _resultados.length.toString(), Colors.green),
                          const SizedBox(width: 12),
                          _buildMetricCard(
                              'Fuentes',
                              _resultados
                                  .map((r) => r.origen)
                                  .toSet()
                                  .length
                                  .toString(),
                              Colors.green),
                          const SizedBox(width: 12),
                          _buildMetricCard(
                              'Resultados top',
                              (_resultados.length > 10
                                      ? 10
                                      : _resultados.length)
                                  .toString(),
                              Colors.green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Condensed grouped list with toggle (one card per origen)
                    Expanded(
                      child: Builder(builder: (context) {
                        final grouped = <String, List<_ResultadoConsulta>>{};
                        for (final r in _resultados) {
                          grouped.putIfAbsent(r.origen, () => []).add(r);
                        }
                        final groups = grouped.entries.toList();
                        return _vistaEjecutivaExpandida
                            ? ListView.builder(
                                itemCount: groups.length,
                                itemBuilder: (context, i) {
                                  final entry = groups[i];
                                  return _buildGroupCard(
                                      entry.key, entry.value);
                                },
                              )
                            : ListView.separated(
                                itemCount:
                                    (groups.length > 8) ? 8 : groups.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final entry = groups[i];
                                  return _buildGroupCard(
                                      entry.key, entry.value);
                                },
                              );
                      }),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() =>
                              _vistaEjecutivaExpandida =
                                  !_vistaEjecutivaExpandida),
                          child: Text(_vistaEjecutivaExpandida
                              ? 'Ver menos'
                              : 'Ver todo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (!_buscando && _resultados.isEmpty && _query.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    const Text('No se encontraron resultados.'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        // sugerencia rápida: copiar la query al portapapeles o abrir una ayuda
                        await Clipboard.setData(ClipboardData(text: _query));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Búsqueda copiada al portapapeles')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar búsqueda'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String titulo, String valor, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text(valor,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
        ],
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
}
