import 'carta_porte_edicion_completa_dialog.dart';
import 'carta_porte_edicion_completa_page.dart';
import 'package:flutter/material.dart';
import '../utils/exportar_excel.dart';
import '../utils/firebase_cache_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialCartaPortePage extends StatefulWidget {
  const HistorialCartaPortePage({Key? key}) : super(key: key);

  @override
  State<HistorialCartaPortePage> createState() =>
      _HistorialCartaPortePageState();
}

class _HistorialCartaPortePageState extends State<HistorialCartaPortePage> {
  // Filtros (no usado)
  List<Map<String, dynamic>> _filtrado = [];
  List<String> _camposDinamicos = [];
  final TextEditingController _busquedaController = TextEditingController();
  // Exportar historial a Excel
  Future<void> _exportarHistorialExcel() async {
    if (_historial.isEmpty) return;
    // Importar utilitario
    // ignore: unused_import

    await exportarExcel(
        cartas: _historial, fileName: 'historial_cartas_porte.xlsx');
  }

  List<Map<String, dynamic>> _historial = [];
  bool _loading = true;
  bool _esAdmin = true; // Cambia esto según tu lógica de permisos

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _busquedaController.addListener(_aplicarFiltros);
  }

  Future<void> _cargarHistorial() async {
    setState(() => _loading = true);
    await CartaPorteHistorialManager.loadHistorial();
    setState(() {
      _historial =
          List<Map<String, dynamic>>.from(CartaPorteHistorialManager.historial);
      // Detectar todos los campos presentes en las cartas
      final campos = <String>{};
      for (final carta in _historial) {
        campos.addAll(carta.keys.map((k) => k.toString()));
      }
      _camposDinamicos = campos.toList();
      _aplicarFiltros();
      _loading = false;
    });
  }

  void _aplicarFiltros() {
    setState(() {
      final busqueda = _busquedaController.text.trim().toLowerCase();
      if (busqueda.isEmpty) {
        _filtrado = List<Map<String, dynamic>>.from(_historial);
      } else {
        _filtrado = _historial.where((carta) {
          for (final campo in _camposDinamicos) {
            final valor = (carta[campo]?.toString() ?? '').toLowerCase();
            if (valor.contains(busqueda)) return true;
          }
          return false;
        }).toList();
      }
    });
  }

  bool _isCompleta(Map<String, dynamic> carta) {
    final campos = ['DESTINO', 'CHOFER', 'UNIDAD', 'RFC', 'CONCENTRADO'];
    for (final campo in campos) {
      if ((carta[campo]?.toString().trim() ?? '').isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _editarCarta(int idx) {
    final carta = _historial[idx];
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (context) => CartaPorteEdicionCompletaPage(
          carta: carta,
          onGuardar: (nuevaCarta) async {
            await CartaPorteHistorialManager.updateCarta(idx, nuevaCarta);
            await CartaPorteHistorialManager.loadHistorial();
            // Notificar que hubo cambios
            Navigator.of(context).pop(true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Carta porte actualizada.'),
                  backgroundColor: Colors.green),
            );
          },
          onImprimir: () {
            Navigator.of(context).pop(true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Función de impresión no implementada.'),
                  backgroundColor: Colors.blue),
            );
          },
        ),
      ),
    )
        .then((actualizar) async {
      if (actualizar == true) {
        await CartaPorteHistorialManager.loadHistorial();
        setState(() {
          _historial = List<Map<String, dynamic>>.from(
              CartaPorteHistorialManager.historial);
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando historial...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    final incompletas = _filtrado.where((c) => !_isCompleta(c)).toList();
    final completas = _filtrado.where((c) => _isCompleta(c)).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        toolbarHeight: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar historial a Excel',
            onPressed: _historial.isEmpty ? null : _exportarHistorialExcel,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.assignment,
                    color: Color(0xFF2D6A4F), size: 32),
                const SizedBox(width: 10),
                const Text(
                  'Historial Carta Porte',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    color: Color(0xFF2D6A4F),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 350,
                  child: TextField(
                    controller: _busquedaController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Buscar en todos los campos',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (incompletas.isNotEmpty)
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Atención! Hay cartas porte con datos incompletos:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Cartas completas primero
          ...completas.map((carta) {
            final idx = _historial.indexOf(carta);
            return Card(
              color: const Color(0xFFF5F6FA), // Blanco grisáceo
              child: ListTile(
                title: Row(
                  children: [
                    Text('Destino: ${carta['DESTINO'] ?? '-'}'),
                    if ((carta['NUMERO_CONTROL'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB7E4C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFF2D6A4F)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.confirmation_number,
                                  size: 14, color: Color(0xFF2D6A4F)),
                              const SizedBox(width: 4),
                              Text(
                                carta['NUMERO_CONTROL'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D6A4F),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chofer: ${carta['CHOFER'] ?? '-'}'),
                    Text('Unidad: ${carta['UNIDAD'] ?? '-'}'),
                    Text('RFC: ${carta['RFC'] ?? '-'}'),
                    Text('Concentrado: ${carta['CONCENTRADO'] ?? '-'}'),
                    if (carta['FECHA'] != null)
                      Text('Fecha: ${carta['FECHA']}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editarCarta(idx),
                    ),
                    if (_esAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Eliminar',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Eliminar carta porte'),
                              content: const Text(
                                  '¿Estás seguro de eliminar esta hoja de carta porte? Esta acción no se puede deshacer.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            setState(() {
                              _historial.removeAt(idx);
                            });
                            // Guardar en Firestore y cache con logs visuales
                            try {
                              await guardarDatosFirestoreYCache(
                                'historial_carta_porte',
                                'datos',
                                {'datos': _historial},
                              );
                              print(
                                  'Guardado exitoso en Firestore: historial_carta_porte/datos');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Hoja eliminada y guardada en Firebase.'),
                                    backgroundColor: Colors.green),
                              );
                            } catch (e) {
                              print(
                                  'Error guardando historial actualizado en Firestore: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Error guardando en Firebase: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
          // Cartas incompletas después, en naranja
          ...incompletas.map((carta) {
            final idx = _historial.indexOf(carta);
            return Card(
              color: Colors.orange.shade100,
              child: ListTile(
                title: Row(
                  children: [
                    Text('Destino: ${carta['DESTINO'] ?? '-'}'),
                    if ((carta['NUMERO_CONTROL'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.confirmation_number,
                                  size: 14, color: Colors.deepOrange),
                              const SizedBox(width: 4),
                              Text(
                                carta['NUMERO_CONTROL'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chofer: ${carta['CHOFER'] ?? '-'}'),
                    Text('Unidad: ${carta['UNIDAD'] ?? '-'}'),
                    Text('RFC: ${carta['RFC'] ?? '-'}'),
                    Text('Concentrado: ${carta['CONCENTRADO'] ?? '-'}'),
                    if (carta['FECHA'] != null)
                      Text('Fecha: ${carta['FECHA']}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editarCarta(idx),
                    ),
                    if (_esAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Eliminar',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Eliminar carta porte'),
                              content: const Text(
                                  '¿Estás seguro de eliminar esta hoja de carta porte? Esta acción no se puede deshacer.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            setState(() {
                              _historial.removeAt(idx);
                            });
                            // Guardar en Firestore y cache
                            try {
                              await guardarDatosFirestoreYCache(
                                'historial_carta_porte',
                                'datos',
                                {'datos': _historial},
                              );
                            } catch (e) {
                              print(
                                  'Error guardando historial actualizado: $e');
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Hoja eliminada.'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
