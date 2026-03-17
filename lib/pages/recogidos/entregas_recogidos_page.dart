import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../utils/firebase_cache_utils.dart';

class EntregasRecogidosPage extends StatefulWidget {
  final List<Map<String, dynamic>> entregasRecientes;

  const EntregasRecogidosPage({Key? key, required this.entregasRecientes})
      : super(key: key);

  @override
  State<EntregasRecogidosPage> createState() => _EntregasRecogidosPageState();
}

class _EntregasRecogidosPageState extends State<EntregasRecogidosPage> {
  late TextEditingController _lpController;
  late List<Map<String, dynamic>> _resultados;
  Set<int> _seleccionados = {};
  String _jefaturaSeleccionada = '';
  List<Map<String, dynamic>> _historialFirmadas = [];
  Set<String> get _lpsFirmadas => _historialFirmadas
      .map((e) => e['LP']?.toString())
      .whereType<String>()
      .toSet();

  Future<void> _agregarAlHistorial(
      List<Map<String, dynamic>> nuevasFirmadas) async {
    setState(() {
      _historialFirmadas.addAll(nuevasFirmadas);
    });
    await guardarDatosFirestoreYCache(
      'historial_entregas',
      'recogidos_firmadas',
      {'items': _historialFirmadas},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final jefaturas = _resultados
        .map((e) => (e['JEFATURA'] ?? '').toString())
        .where((j) => j.isNotEmpty)
        .toSet()
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: const Text('Entregas Recogidos',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar (forzar Firestore)',
            onPressed: () async {
              await invalidateCache('entregas', 'recogidos');
              final datos = await leerDatosConCache('entregas', 'recogidos');
              if (datos != null && datos['items'] != null) {
                setState(() {
                  _resultados = List<Map<String, dynamic>>.from(datos['items']);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Datos recargados desde Firestore.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No se pudieron recargar los datos.')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 24, vertical: isMobile ? 8 : 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lpController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar o escanear LP',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) {
                      setState(() {});
                    },
                    onTap: () => _lpController.selection = TextSelection(
                        baseOffset: 0, extentOffset: _lpController.text.length),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _jefaturaSeleccionada.isEmpty
                      ? null
                      : _jefaturaSeleccionada,
                  hint: const Text('Jefatura'),
                  isExpanded: false,
                  items: [
                    const DropdownMenuItem<String>(
                        value: '', child: Text('Todas')),
                    ...jefaturas
                        .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                        .toList(),
                  ],
                  onChanged: (v) =>
                      setState(() => _jefaturaSeleccionada = v ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _resultadosFiltrados(isMobile).isEmpty
                  ? const Center(
                      child: Text('No hay entregas para mostrar.',
                          style: TextStyle(fontSize: 18, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _resultadosFiltrados(isMobile).length,
                      itemBuilder: (context, index) {
                        final entrega = _resultadosFiltrados(isMobile)[index];
                        final seleccionado = _seleccionados.contains(index);
                        final esFaltante =
                            (entrega['BOX']?.toString().toUpperCase() ==
                                'FALTANTE');
                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                              vertical: 7, horizontal: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: esFaltante
                                  ? Colors.red.shade300
                                  : const Color(0xFF2D6A4F),
                              width: esFaltante ? 2.2 : 1.2,
                            ),
                          ),
                          color: esFaltante ? Colors.red[50] : Colors.white,
                          child: CheckboxListTile(
                            value: seleccionado,
                            onChanged: (checked) {
                              final lp = entrega['LP']?.toString();
                              if (_lpsFirmadas.contains(lp)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Este LP ya fue firmado y no puede seleccionarse.')),
                                );
                                return;
                              }
                              setState(() {
                                if (checked == true) {
                                  _seleccionados.add(index);
                                } else {
                                  _seleccionados.remove(index);
                                }
                              });
                            },
                            title: isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text((entrega['LP'] ?? '-').toString(),
                                          style: const TextStyle(
                                              color: Color(0xFF2D6A4F),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Text(
                                          'DESCRIPCION: ${entrega['DESCRIPCION'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'CANTIDAD: ${entrega['CANTIDAD'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'SECCION: ${entrega['SECCION'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF495057))),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        constraints: const BoxConstraints(
                                            minWidth: 60,
                                            maxWidth: 120,
                                            minHeight: 40,
                                            maxHeight: 50),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2D6A4F),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                              (entrega['LP'] ?? '-').toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              )),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'DESCRIPCION: ${entrega['DESCRIPCION'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF495057))),
                                            Text(
                                                'CANTIDAD: ${entrega['CANTIDAD'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF495057))),
                                            Text(
                                                'SECCION: ${entrega['SECCION'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF495057))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            subtitle: Text(
                              'Jefatura: ${entrega['JEFATURA'] ?? '-'}',
                              style: TextStyle(
                                  fontSize: isMobile ? 13 : 16,
                                  color: Color(0xFF495057)),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 16,
                                vertical: isMobile ? 2 : 8),
                          ),
                        );
                      },
                    ),
            ),
            if (_seleccionados.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_document),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 244, 247, 245),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  label: const Text('Firmar seleccionados',
                      style: TextStyle(fontSize: 18)),
                  onPressed: () async {
                    // Validar que ningún LP seleccionado ya esté firmado
                    final lpsSeleccionadas = _seleccionados
                        .map((idx) => _resultadosFiltrados(isMobile)[idx]['LP']
                            ?.toString())
                        .toSet();
                    final lpsYaFirmadas =
                        lpsSeleccionadas.intersection(_lpsFirmadas);
                    if (lpsYaFirmadas.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Al menos un LP seleccionado ya fue firmado. Actualiza la lista.')),
                      );
                      setState(() {
                        _seleccionados.removeWhere((idx) => _lpsFirmadas
                            .contains(_resultadosFiltrados(isMobile)[idx]['LP']
                                ?.toString()));
                      });
                      return;
                    }
                    final nombreController = TextEditingController();
                    final signatureController = SignatureController(
                      penStrokeWidth: 3,
                      penColor: Colors.black,
                      exportBackgroundColor: Colors.white,
                    );
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: Text('Firmar entregas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D6A4F),
                                fontSize: isMobile ? 18 : 22)),
                        content: SizedBox(
                          width: isMobile ? double.infinity : 400,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: nombreController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre de quien recibe',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text('Firma:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D6A4F))),
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Color(0xFF2D6A4F)),
                                  ),
                                  width: double.infinity,
                                  height: isMobile ? 100 : 140,
                                  child: Signature(
                                    controller: signatureController,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        signatureController.clear(),
                                    icon: const Icon(
                                        Icons.cleaning_services_outlined),
                                    label: const Text('Limpiar firma'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              final firmaBytes =
                                  await signatureController.toPngBytes();
                              List<Map<String, dynamic>> firmadas = [];
                              setState(() {
                                for (var idx in _seleccionados) {
                                  final entrega =
                                      _resultadosFiltrados(isMobile)[idx];
                                  final registro = {
                                    ...entrega,
                                    'nombreRecibe': nombreController.text,
                                    'firma': firmaBytes != null
                                        ? base64Encode(firmaBytes)
                                        : null,
                                    'fechaFirma':
                                        DateTime.now().toIso8601String(),
                                  };
                                  firmadas.add(registro);
                                }
                                _seleccionados.clear();
                              });
                              await _agregarAlHistorial(firmadas);
                              // Refrescar lista de entregas no firmadas
                              final lpsFirmadas = _lpsFirmadas;
                              setState(() {
                                _resultados = widget.entregasRecientes
                                    .where((e) => !lpsFirmadas
                                        .contains(e['LP']?.toString()))
                                    .toList();
                              });
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Guardar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ],
                      ),
                    );
                    signatureController.dispose();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _resultadosFiltrados(bool isMobile) {
    final lpsFirmadas = _lpsFirmadas;
    return _resultados
        .where((e) => !lpsFirmadas.contains(e['LP']?.toString()))
        .where((e) =>
            _lpController.text.isEmpty ||
            (e['LP']?.toString().toLowerCase() ?? '')
                .contains(_lpController.text.toLowerCase()) ||
            (e['DESCRIPCION']?.toString().toLowerCase() ?? '')
                .contains(_lpController.text.toLowerCase()))
        .where((e) =>
            _jefaturaSeleccionada.isEmpty ||
            (e['JEFATURA']?.toString() ?? '') == _jefaturaSeleccionada)
        .toList();
  }
}
