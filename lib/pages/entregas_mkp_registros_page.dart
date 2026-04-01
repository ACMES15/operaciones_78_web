import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import '../utils/firebase_cache_utils.dart';

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
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
    _busquedaController.addListener(_filtrar);
  }

  Future<void> _cargarRegistros() async {
    setState(() => _cargando = true);
    final cache = await leerDatosConCache('entregas', 'mkp');
    List<Map<String, dynamic>> registros = [];
    if (cache != null && cache['items'] is List) {
      registros = List<Map<String, dynamic>>.from(
        (cache['items'] as List).whereType<Map<String, dynamic>>(),
      );
    }
    setState(() {
      _registros = registros;
      _filtrados = registros;
      _cargando = false;
    });
  }

  void _filtrar() {
    final filtro = _busquedaController.text.trim().toLowerCase();
    if (filtro.isEmpty) {
      setState(() => _filtrados = _registros);
      return;
    }
    setState(() {
      _filtrados = _registros.where((reg) {
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
      }).toList();
    });
  }

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
                            final reg = _filtrados[_filtrados.length - 1 - idx];
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
