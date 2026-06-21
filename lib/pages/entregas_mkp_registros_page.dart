import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EntregasMkpRegistrosPage extends StatefulWidget {
  const EntregasMkpRegistrosPage({Key? key}) : super(key: key);

  @override
  State<EntregasMkpRegistrosPage> createState() =>
      _EntregasMkpRegistrosPageState();
}

class _EntregasMkpRegistrosPageState extends State<EntregasMkpRegistrosPage> {
  List<Map<String, dynamic>> _registros = [];
  List<Map<String, dynamic>> _filtrados = [];
  bool _cargando = true;
  String? _mesSeleccionado;
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
    _busquedaController.addListener(_filtrar);
  }

  List<Map<String, dynamic>> _extraerRegistros(Map<String, dynamic> data) {
    if (data['items'] is! List) return [];
    return List<Map<String, dynamic>>.from(
      (data['items'] as List).whereType<Map<String, dynamic>>(),
    );
  }

  String _keyMesActual() {
    final ahora = DateTime.now();
    return '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';
  }

  String? _obtenerKeyMesRegistro(Map<String, dynamic> reg) {
    final rawFecha = reg['fecha']?.toString();
    if (rawFecha == null || rawFecha.isEmpty) return null;
    final fecha = DateTime.tryParse(rawFecha);
    if (fecha == null) return null;
    return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';
  }

  List<String> _mesesDisponiblesOrdenados() {
    final meses = _registros
        .map(_obtenerKeyMesRegistro)
        .whereType<String>()
        .toSet()
        .toList();
    meses.sort((a, b) => b.compareTo(a)); // Descendente
    return meses;
  }

  List<String> _mesesParaSelector() {
    final meses = _mesesDisponiblesOrdenados();
    final actual = _keyMesActual();
    if (!meses.contains(actual)) {
      meses.insert(0, actual);
    }
    if (_mesSeleccionado != null &&
        _mesSeleccionado != 'all' &&
        !meses.contains(_mesSeleccionado)) {
      meses.insert(0, _mesSeleccionado!);
    }
    return meses;
  }

  String _etiquetaMes(String key) {
    final partes = key.split('-');
    if (partes.length != 2) return key;
    final year = int.tryParse(partes[0]);
    final month = int.tryParse(partes[1]);
    if (year == null || month == null || month < 1 || month > 12) return key;
    const nombres = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${nombres[month - 1]} $year';
  }

  Future<void> _cargarRegistros() async {
    setState(() => _cargando = true);

    final prefs = await SharedPreferences.getInstance();
    // v2 = lista fusionada (array antiguo + subcolección nueva)
    const cacheKey = 'entregas_mkp_v2';

    // 1) Mostrar caché primero para abrir la pantalla rápido.
    final cacheData = prefs.getString(cacheKey);
    if (cacheData != null) {
      try {
        final list = jsonDecode(cacheData) as List;
        final cacheRegistros = list.whereType<Map<String, dynamic>>().toList();
        if (mounted && cacheRegistros.isNotEmpty) {
          setState(() {
            _registros = cacheRegistros;
            _cargando = false;
          });
          _aplicarFiltros();
        }
      } catch (_) {
        // Ignora caché corrupto y continúa con red.
      }
    }

    // 2) Leer en paralelo: doc antiguo (array) + subcolección nueva.
    try {
      final docFuture = FirebaseFirestore.instance
          .collection('entregas')
          .doc('mkp')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));

      final subFuture = FirebaseFirestore.instance
          .collection('entregas')
          .doc('mkp')
          .collection('items')
          .orderBy('fecha', descending: true)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));

      final results = await Future.wait<dynamic>([docFuture, subFuture]);

      final docSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final subSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

      // Items del doc antiguo (array legado)
      final oldItems = docSnap.exists
          ? _extraerRegistros(docSnap.data() ?? {})
          : <Map<String, dynamic>>[];

      // Items de la subcolección nueva
      final newItems =
          subSnap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();

      // Fusionar sin duplicados (clave: fecha + empleado)
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final item in [...newItems, ...oldItems]) {
        final key = '${item['fecha']}_${item['empleado']}';
        if (seen.add(key)) merged.add(item);
      }
      // Ordenar más reciente primero
      merged.sort((a, b) => (b['fecha'] ?? '')
          .toString()
          .compareTo((a['fecha'] ?? '').toString()));

      await prefs.setString(cacheKey, jsonEncode(merged));

      if (!mounted) return;
      setState(() {
        _registros = merged;
        _cargando = false;
      });
      _aplicarFiltros();
    } catch (_) {
      if (!mounted) return;
      if (_registros.isEmpty) setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    final filtro = _busquedaController.text.trim().toLowerCase();
    final actual = _keyMesActual();
    final meses = _mesesDisponiblesOrdenados();

    // Default: mostrar un solo mes (mes actual; si no existe, el último disponible).
    _mesSeleccionado ??= meses.contains(actual)
        ? actual
        : (meses.isNotEmpty ? meses.first : actual);

    Iterable<Map<String, dynamic>> base = _registros;
    if (_mesSeleccionado != 'all') {
      base =
          base.where((reg) => _obtenerKeyMesRegistro(reg) == _mesSeleccionado);
    }

    if (filtro.isNotEmpty) {
      base = base.where((reg) {
        return (reg['empleado'] ?? '')
                .toString()
                .toLowerCase()
                .contains(filtro) ||
            (reg['devolucion_mkp'] ?? '')
                .toString()
                .toLowerCase()
                .contains(filtro) ||
            (reg['usuario'] ?? '').toString().toLowerCase().contains(filtro) ||
            ((reg['skus'] as List?)?.join(', ') ?? '')
                .toLowerCase()
                .contains(filtro);
      });
    }

    setState(() {
      _filtrados = base.toList();
    });
  }

  void _filtrar() => _aplicarFiltros();

  Future<void> _exportarAExcel() async {
    if (_filtrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }
    final excel = Excel.createExcel();
    final sheet = excel['Entregas MKP'];
    final headers = [
      'Empleado',
      'Devolución MKP',
      'SKU(s)',
      'Cantidad',
      'Usuario',
      'Fecha'
    ];
    sheet.appendRow(headers);
    for (final reg in _filtrados) {
      sheet.appendRow([
        reg['empleado'] ?? '',
        reg['devolucion_mkp'] ?? '',
        (reg['skus'] as List?)?.join(', ') ?? '',
        reg['cantidad']?.toString() ?? '',
        reg['usuario'] ?? '',
        reg['fecha'] ?? '',
      ]);
    }
    final bytes = excel.encode()!;
    final blob = html.Blob([Uint8List.fromList(bytes)],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'entregas_mkp.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: const [
            Icon(Icons.shopping_cart_checkout,
                color: Color(0xFF2D6A4F), size: 30),
            SizedBox(width: 10),
            Text(
              'Registros Entregas MKP',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF2D6A4F)),
            tooltip: 'Exportar a Excel',
            onPressed: _exportarAExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2D6A4F)),
            tooltip: 'Forzar recarga',
            onPressed: _cargarRegistros,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _mesSeleccionado ?? _keyMesActual(),
              decoration: const InputDecoration(
                labelText: 'Mes a mostrar',
                border: OutlineInputBorder(),
              ),
              items: [
                ..._mesesParaSelector().map(
                  (key) => DropdownMenuItem<String>(
                    value: key,
                    child: Text(_etiquetaMes(key)),
                  ),
                ),
                const DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('Histórico completo'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _mesSeleccionado = value);
                _aplicarFiltros();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _busquedaController,
              decoration: const InputDecoration(
                labelText: 'Buscar por empleado, devolución, usuario o SKU',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _filtrados.isEmpty
                      ? const Center(child: Text('No hay registros.'))
                      : ListView.builder(
                          itemCount: _filtrados.length,
                          itemBuilder: (context, idx) {
                            final reg = _filtrados[idx];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(
                                    'Empleado: ${reg['empleado'] ?? '-'} | Devolución: ${reg['devolucion_mkp'] ?? '-'}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'SKU(s): ${(reg['skus'] as List?)?.join(', ') ?? '-'}'),
                                    Text('Cantidad: ${reg['cantidad'] ?? '-'}'),
                                    Text('Usuario: ${reg['usuario'] ?? '-'}'),
                                    Text(
                                        'Fecha: ${reg['fecha'] != null ? reg['fecha'].toString().substring(0, 19).replaceFirst('T', ' ') : '-'}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
