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
  Set<String> get _lpsFirmadas => _historialFirmadas
      .map((e) => e['LP']?.toString())
      .whereType<String>()
      .toSet();
  List<Map<String, dynamic>> _historialFirmadas = [];

  @override
  void initState() {
    super.initState();
    _lpController = TextEditingController();
    _resultados = widget.entregasRecientes;
    _cargarHistorialFirmadas();
  }

  Future<void> _cargarHistorialFirmadas() async {
    final datos =
        await leerDatosConCache('historial_entregas', 'recogidos_firmadas');
    if (datos != null && datos['items'] != null) {
      final List<dynamic> decoded = datos['items'];
      setState(() {
        _historialFirmadas = decoded
            .cast<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        // Filtrar resultados para excluir LP ya firmados
        final lpsFirmadas = _lpsFirmadas;
        _resultados = widget.entregasRecientes
            .where((e) => !lpsFirmadas.contains(e['LP']?.toString()))
            .toList();
        _seleccionados.removeWhere((idx) {
          if (idx >= _resultados.length) return true;
          final lp = _resultados[idx]['LP']?.toString();
          return lpsFirmadas.contains(lp);
        });
      });
    }
  }

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
    final jefaturas = widget.entregasRecientes
        .map((e) => (e['JEFATURA'] ?? '').toString())
        .where((j) => j.isNotEmpty)
        .toSet()
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Scaffold(
          backgroundColor: const Color(0xFFF4F9F6),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2D6A4F),
            elevation: 0,
            title: Text('Entregas Recogidos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 20 : 28,
                  color: Colors.white,
                )),
            centerTitle: true,
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 24, vertical: isMobile ? 8 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isMobile
                    ? Column(
                        children: [
                          TextField(
                            controller: _lpController,
                            decoration: InputDecoration(
                              hintText: 'Buscar LP o descripción',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (v) {
                              setState(() {
                                final lpsFirmadas = _lpsFirmadas;
                                _resultados =
                                    widget.entregasRecientes.where((e) {
                                  final lp =
                                      (e['LP'] ?? '').toString().toLowerCase();
                                  final desc = (e['DESCRIPCION'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final lpRaw = (e['LP'] ?? '').toString();
                                  return (lp.contains(v.toLowerCase()) ||
                                          desc.contains(v.toLowerCase())) &&
                                      !lpsFirmadas.contains(lpRaw);
                                }).toList();
                                _seleccionados.removeWhere((idx) {
                                  if (idx >= _resultados.length) return true;
                                  final lp = _resultados[idx]['LP']?.toString();
                                  return lpsFirmadas.contains(lp);
                                });
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            value: _jefaturaSeleccionada.isEmpty
                                ? null
                                : _jefaturaSeleccionada,
                            hint: const Text('Jefatura'),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String>(
                                  value: '', child: Text('Todas')),
                              ...jefaturas
                                  .map((j) => DropdownMenuItem(
                                      value: j, child: Text(j)))
                                  .toList(),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _jefaturaSeleccionada = v ?? '';
                                final lpsFirmadas = _lpsFirmadas;
                                _resultados =
                                    widget.entregasRecientes.where((e) {
                                  final j = (e['JEFATURA'] ?? '').toString();
                                  final matchesJ = _jefaturaSeleccionada.isEmpty
                                      ? true
                                      : j == _jefaturaSeleccionada;
                                  final lpRaw = (e['LP'] ?? '').toString();
                                  return matchesJ &&
                                      !lpsFirmadas.contains(lpRaw);
                                }).toList();
                                _seleccionados.removeWhere((idx) {
                                  if (idx >= _resultados.length) return true;
                                  final lp = _resultados[idx]['LP']?.toString();
                                  return lpsFirmadas.contains(lp);
                                });
                              });
                            },
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _lpController,
                              decoration: InputDecoration(
                                hintText: 'Buscar LP o descripción',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (v) {
                                setState(() {
                                  final lpsFirmadas = _lpsFirmadas;
                                  _resultados =
                                      widget.entregasRecientes.where((e) {
                                    final lp = (e['LP'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final desc = (e['DESCRIPCION'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final lpRaw = (e['LP'] ?? '').toString();
                                    return (lp.contains(v.toLowerCase()) ||
                                            desc.contains(v.toLowerCase())) &&
                                        !lpsFirmadas.contains(lpRaw);
                                  }).toList();
                                  _seleccionados.removeWhere((idx) {
                                    if (idx >= _resultados.length) return true;
                                    final lp =
                                        _resultados[idx]['LP']?.toString();
                                    return lpsFirmadas.contains(lp);
                                  });
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _jefaturaSeleccionada.isEmpty
                                ? null
                                : _jefaturaSeleccionada,
                            hint: const Text('Jefatura'),
                            items: [
                              const DropdownMenuItem<String>(
                                  value: '', child: Text('Todas')),
                              ...jefaturas
                                  .map((j) => DropdownMenuItem(
                                      value: j, child: Text(j)))
                                  .toList(),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _jefaturaSeleccionada = v ?? '';
                                final lpsFirmadas = _lpsFirmadas;
                                _resultados =
                                    widget.entregasRecientes.where((e) {
                                  final j = (e['JEFATURA'] ?? '').toString();
                                  final matchesJ = _jefaturaSeleccionada.isEmpty
                                      ? true
                                      : j == _jefaturaSeleccionada;
                                  final lpRaw = (e['LP'] ?? '').toString();
                                  return matchesJ &&
                                      !lpsFirmadas.contains(lpRaw);
                                }).toList();
                                _seleccionados.removeWhere((idx) {
                                  if (idx >= _resultados.length) return true;
                                  final lp = _resultados[idx]['LP']?.toString();
                                  return lpsFirmadas.contains(lp);
                                });
                              });
                            },
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _resultados.length,
                    itemBuilder: (context, index) {
                      final entrega = _resultados[index];
                      return Container(
                        margin: EdgeInsets.symmetric(
                            vertical: isMobile ? 4 : 8,
                            horizontal: isMobile ? 0 : 0),
                        child: Card(
                          elevation: isMobile ? 2 : 6,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(isMobile ? 8 : 16)),
                          color: Colors.white,
                          child: CheckboxListTile(
                            value: _seleccionados.contains(index),
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
                                          'DESCRIPCION: \\${entrega['DESCRIPCION'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'CANTIDAD: \\${entrega['CANTIDAD'] ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF495057))),
                                      Text(
                                          'SECCION: \\${entrega['SECCION'] ?? '-'}',
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
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'DESCRIPCION: \\${entrega['DESCRIPCION'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF495057))),
                                            Text(
                                                'CANTIDAD: \\${entrega['CANTIDAD'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF495057))),
                                            Text(
                                                'SECCION: \\${entrega['SECCION'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF495057))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            subtitle: Text(
                              'Jefatura: \\${entrega['JEFATURA'] ?? '-'}',
                              style: TextStyle(
                                  fontSize: isMobile ? 13 : 16,
                                  color: Color(0xFF495057)),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 16,
                                vertical: isMobile ? 2 : 8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_seleccionados.isNotEmpty)
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 32,
                            vertical: isMobile ? 8 : 12),
                      ),
                      child: Text('Firmar',
                          style: TextStyle(
                              fontSize: isMobile ? 16 : 20,
                              color: Colors.white)),
                      onPressed: () async {
                        // Validar que ningún LP seleccionado ya esté firmado
                        final lpsSeleccionadas = _seleccionados
                            .map((idx) => _resultados[idx]['LP']?.toString())
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
                                .contains(_resultados[idx]['LP']?.toString()));
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
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Color(0xFF2D6A4F)),
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
                                      final entrega = _resultados[idx];
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
      },
    );
  }
}
