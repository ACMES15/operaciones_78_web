import 'carta_porte_edicion_completa_page.dart';
import 'carta_porte_table.dart' as table_historial;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/exportar_excel.dart';
import '../utils/firebase_cache_utils.dart';

class HistorialCartaPortePage extends StatefulWidget {
  const HistorialCartaPortePage({Key? key}) : super(key: key);

  @override
  State<HistorialCartaPortePage> createState() =>
      _HistorialCartaPortePageState();
}

class _HistorialCartaPortePageState extends State<HistorialCartaPortePage> {
  // Filtros (no usado)
  final TextEditingController _busquedaController = TextEditingController();
  bool _esAdmin = true; // Cambia esto según tu lógica de permisos

  bool _isCompleta(Map<String, dynamic> carta) {
    final campos = ['DESTINO', 'CHOFER', 'UNIDAD', 'RFC', 'CONCENTRADO'];
    for (final campo in campos) {
      if ((carta[campo]?.toString().trim() ?? '').isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _editarCarta(Map<String, dynamic> carta) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CartaPorteEdicionCompletaPage(
          carta: carta,
          onGuardar: (nuevaCarta) async {
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
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('cartas_porte').snapshots(),
      builder: (context, snapshotCartas) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hoja_ruta')
              .doc('sentHojaRutas')
              .snapshots(),
          builder: (context, snapshotHojaRuta) {
            // Si ambos streams están esperando, mostrar cargando
            if (snapshotCartas.connectionState == ConnectionState.waiting ||
                snapshotHojaRuta.connectionState == ConnectionState.waiting) {
              // Si ambos streams están vacíos, mostrar historial vacío
              final docs = snapshotCartas.data?.docs ?? [];
              final dataHojaRuta = snapshotHojaRuta.data?.data();
              final hojaRutaVacia = dataHojaRuta == null ||
                  dataHojaRuta['items'] == null ||
                  (dataHojaRuta['items'] as List).isEmpty;
              if (docs.isEmpty && hojaRutaVacia) {
                return Container(
                  color: Colors.white,
                  child: const Center(
                    child: Text('Aún no hay historial',
                        style: TextStyle(fontSize: 20, color: Colors.grey)),
                  ),
                );
              }
              // Si hay datos, mostrar cargando normal
              return Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando historial...',
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            }
            if (snapshotCartas.hasError || snapshotHojaRuta.hasError) {
              return Center(
                  child: Text('Error cargando historial de carta porte'));
            }
            // Cartas porte
            final docs = snapshotCartas.data?.docs ?? [];
            final cartasPorte = docs.map((doc) => doc.data()).toList();
            // Hojas de ruta enviadas
            List<Map<String, dynamic>> hojasRuta = [];
            final dataHojaRuta = snapshotHojaRuta.data?.data();
            if (dataHojaRuta != null && dataHojaRuta['items'] != null) {
              hojasRuta = List<Map<String, dynamic>>.from(
                (dataHojaRuta['items'] as List)
                    .map((e) => Map<String, dynamic>.from(e)),
              );
            }
            // Fusionar ambos historiales
            final historial = [...cartasPorte, ...hojasRuta];
            // Detectar todos los campos presentes en las cartas
            final campos = <String>{};
            for (final carta in historial) {
              campos.addAll(carta.keys.map((k) => k.toString()));
            }
            final camposDinamicos = campos.toList();
            // Filtrado local
            final busqueda = _busquedaController.text.trim().toLowerCase();
            List<Map<String, dynamic>> filtrado;
            if (busqueda.isEmpty) {
              filtrado = List<Map<String, dynamic>>.from(historial);
            } else {
              filtrado = historial.where((carta) {
                for (final campo in camposDinamicos) {
                  final valor = (carta[campo]?.toString() ?? '').toLowerCase();
                  if (valor.contains(busqueda)) return true;
                }
                return false;
              }).toList();
            }
            // Solo mostrar cartas porte completas (con datos obligatorios y al menos una fila de tabla)
            bool _esCartaCompleta(Map<String, dynamic> carta) {
              final campos = [
                'DESTINO',
                'CHOFER',
                'UNIDAD',
                'RFC',
                'CONCENTRADO'
              ];
              for (final campo in campos) {
                if ((carta[campo]?.toString().trim() ?? '').isEmpty) {
                  return false;
                }
              }
              final tabla = carta['TABLE'];
              if (tabla == null || tabla is! List || tabla.isEmpty)
                return false;
              // Al menos una fila con datos
              final tieneFila = tabla.any((row) {
                if (row is Map) {
                  return row.values
                      .any((v) => v != null && v.toString().trim().isNotEmpty);
                }
                return false;
              });
              return tieneFila;
            }

            final completas = filtrado.where(_esCartaCompleta).toList();
            final incompletas =
                filtrado.where((c) => !_esCartaCompleta(c)).toList();
            // Función para exportar Excel con historial actual
            Future<void> exportarHistorialExcel() async {
              if (historial.isEmpty) return;
              await exportarExcel(
                  cartas: historial, fileName: 'historial_cartas_porte.xlsx');
            }

            return Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFF2D6A4F),
                elevation: 0,
                toolbarHeight: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: 'Exportar historial a Excel',
                    onPressed:
                        historial.isEmpty ? null : exportarHistorialExcel,
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
                  if (historial.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Aún no hay historial',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (incompletas.isNotEmpty)
                      Container(
                        color: Colors.amber.shade100,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.all(8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning,
                                color: Colors.orange, size: 18),
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
                      bool verDetalles = false;
                      return StatefulBuilder(
                        builder: (context, setStateCard) {
                          return Card(
                            color: const Color(0xFFF5F6FA),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Row(
                                    children: [
                                      Text(
                                          'Destino: ${carta['DESTINO'] ?? '-'}'),
                                      if ((carta['NUMERO_CONTROL'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB7E4C7),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Color(0xFF2D6A4F)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                    Icons.confirmation_number,
                                                    size: 14,
                                                    color: Color(0xFF2D6A4F)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  carta['NUMERO_CONTROL'],
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Chofer: ${carta['CHOFER'] ?? '-'}'),
                                      Text('Unidad: ${carta['UNIDAD'] ?? '-'}'),
                                      Text('RFC: ${carta['RFC'] ?? '-'}'),
                                      Text(
                                          'Concentrado: ${carta['CONCENTRADO'] ?? '-'}'),
                                      if (carta['FECHA'] != null)
                                        Text('Fecha: ${carta['FECHA']}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () => _editarCarta(carta),
                                      ),
                                      if (_esAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          tooltip: 'Eliminar',
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Eliminar carta porte'),
                                                content: const Text(
                                                    '¿Estás seguro de eliminar esta hoja de carta porte? Esta acción no se puede deshacer.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(false),
                                                    child:
                                                        const Text('Cancelar'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(true),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                Colors.red),
                                                    child:
                                                        const Text('Eliminar'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              final idx =
                                                  historial.indexOf(carta);
                                              if (idx != -1) {
                                                setState(() {
                                                  historial.removeAt(idx);
                                                });
                                                try {
                                                  await guardarDatosFirestoreYCache(
                                                    'historial_carta_porte',
                                                    'datos',
                                                    {'datos': historial},
                                                  );
                                                  print(
                                                      'Guardado exitoso en Firestore: historial_carta_porte/datos');
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Hoja eliminada y guardada en Firebase.'),
                                                        backgroundColor:
                                                            Colors.green),
                                                  );
                                                } catch (e) {
                                                  print(
                                                      'Error guardando historial actualizado en Firestore: $e');
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                        content: Text(
                                                            'Error guardando en Firebase: $e'),
                                                        backgroundColor:
                                                            Colors.red),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                        ),
                                      IconButton(
                                        icon: Icon(
                                            verDetalles
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.teal),
                                        tooltip: verDetalles
                                            ? 'Ocultar detalles'
                                            : 'Ver detalles',
                                        onPressed: () => setStateCard(
                                            () => verDetalles = !verDetalles),
                                      ),
                                    ],
                                  ),
                                ),
                                if (verDetalles &&
                                    carta['TABLE'] != null &&
                                    carta['TABLE'] is List &&
                                    (carta['TABLE'] as List).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: (carta['TABLE'][0]
                                                as Map<String, dynamic>)
                                            .keys
                                            .map((k) =>
                                                DataColumn(label: Text(k)))
                                            .toList(),
                                        rows: (carta['TABLE'] as List)
                                            .map<DataRow>((row) => DataRow(
                                                  cells: (row as Map<String,
                                                          dynamic>)
                                                      .values
                                                      .map((v) => DataCell(Text(
                                                          v?.toString() ?? '')))
                                                      .toList(),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                    // Cartas incompletas después, en naranja
                    ...incompletas.map((carta) {
                      return Card(
                        color: Colors.orange.shade100,
                        child: ListTile(
                          title: Row(
                            children: [
                              Text('Destino: ${carta['DESTINO'] ?? '-'}'),
                              if ((carta['NUMERO_CONTROL'] ?? '')
                                  .toString()
                                  .isNotEmpty)
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
                              Text(
                                  'Concentrado: ${carta['CONCENTRADO'] ?? '-'}'),
                              if (carta['FECHA'] != null)
                                Text('Fecha: ${carta['FECHA']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editarCarta(carta),
                              ),
                              if (_esAdmin)
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title:
                                            const Text('Eliminar carta porte'),
                                        content: const Text(
                                            '¿Estás seguro de eliminar esta hoja de carta porte? Esta acción no se puede deshacer.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
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
                                      final idx = historial.indexOf(carta);
                                      if (idx != -1) {
                                        setState(() {
                                          historial.removeAt(idx);
                                        });
                                        // Guardar en Firestore y cache
                                        try {
                                          await guardarDatosFirestoreYCache(
                                            'historial_carta_porte',
                                            'datos',
                                            {'datos': historial},
                                          );
                                        } catch (e) {
                                          print(
                                              'Error guardando historial actualizado: $e');
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Hoja eliminada.'),
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
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }
}
