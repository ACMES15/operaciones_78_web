import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'carta_porte_imprimir_page.dart';

class CartaPorteEdicionPage extends StatefulWidget {
  final Map<String, dynamic> carta;
  final String docId;
  const CartaPorteEdicionPage(
      {Key? key, required this.carta, required this.docId})
      : super(key: key);

  @override
  @override
  State<CartaPorteEdicionPage> createState() => _CartaPorteEdicionPageState();
}

class _CartaPorteEdicionPageState extends State<CartaPorteEdicionPage> {
  late TextEditingController choferController;
  late TextEditingController destinoController;
  late TextEditingController fechaController;
  late TextEditingController numeroControlController;
  late TextEditingController rfcController;
  late TextEditingController unidadController;
  late TextEditingController licenciaController;
  List<Map<String, dynamic>> filas = [];
  List<Map<String, dynamic>> choferes = [];
  String? choferSeleccionado;

  @override
  void initState() {
    super.initState();
    choferController =
        TextEditingController(text: widget.carta['chofer'] ?? '');
    destinoController =
        TextEditingController(text: widget.carta['destino'] ?? '');
    fechaController = TextEditingController(text: widget.carta['fecha'] ?? '');
    numeroControlController =
        TextEditingController(text: widget.carta['numero_control'] ?? '');
    rfcController = TextEditingController(text: widget.carta['rfc'] ?? '');
    unidadController =
        TextEditingController(text: widget.carta['unidad'] ?? '');
    licenciaController =
        TextEditingController(text: widget.carta['licencia'] ?? '');
    final rawFilas = widget.carta['filas'];
    if (rawFilas is List) {
      filas = rawFilas.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    choferSeleccionado = widget.carta['chofer'];
    _cargarChoferes();
  }

  Future<void> _cargarChoferes() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('choferes').get();
    setState(() {
      choferes = snapshot.docs.map((d) {
        final data = d.data();
        return {
          'nombre': data['nombre'] ?? '',
          'rfc': data['rfc'] ?? '',
          'licencia': data['licencia'] ?? '',
        };
      }).toList();
    });
  }

  @override
  void dispose() {
    choferController.dispose();
    destinoController.dispose();
    fechaController.dispose();
    numeroControlController.dispose();
    rfcController.dispose();
    unidadController.dispose();
    licenciaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final data = {
      'chofer': choferSeleccionado ?? '',
      'destino': destinoController.text,
      'fecha': fechaController.text,
      'numero_control': numeroControlController.text,
      'rfc': rfcController.text,
      'unidad': unidadController.text,
      'licencia': licenciaController.text,
      'filas': filas,
    };
    await FirebaseFirestore.instance
        .collection('cartas_porte')
        .doc(widget.docId)
        .update(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carta porte actualizada')),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: const Icon(Icons.local_shipping, color: Color(0xFF2D6A4F)),
        title: const Text(
          'Editar Carta Porte',
          style: TextStyle(
            color: Color(0xFF2D6A4F),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFF2D6A4F)),
            tooltip: 'Guardar',
            onPressed: _guardar,
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF2D6A4F)),
            tooltip: 'Imprimir',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CartaPorteImprimirPage(
                    carta: {
                      ...widget.carta,
                      'chofer': choferSeleccionado ?? '',
                      'destino': destinoController.text,
                      'fecha': fechaController.text,
                      'numero_control': numeroControlController.text,
                      'rfc': rfcController.text,
                      'unidad': unidadController.text,
                      'filas': filas,
                    },
                  ),
                ),
              );
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: choferSeleccionado,
              decoration: const InputDecoration(labelText: 'Chofer'),
              items: choferes.map((c) {
                return DropdownMenuItem<String>(
                  value: c['nombre'],
                  child: Text(c['nombre'] ?? ''),
                );
              }).toList(),
              onChanged: (nuevo) {
                setState(() {
                  choferSeleccionado = nuevo;
                  final chofer = choferes.firstWhere(
                    (c) => c['nombre'] == nuevo,
                    orElse: () => {'rfc': '', 'licencia': ''},
                  );
                  rfcController.text = chofer['rfc'] ?? '';
                  licenciaController.text = chofer['licencia'] ?? '';
                });
              },
            ),
            TextField(
              controller: destinoController,
              decoration: const InputDecoration(labelText: 'Destino'),
            ),
            TextField(
              controller: fechaController,
              decoration: const InputDecoration(labelText: 'Fecha'),
              enabled: false,
            ),
            TextField(
              controller: numeroControlController,
              decoration: const InputDecoration(labelText: 'Número de control'),
              enabled: false,
            ),
            TextField(
              controller: rfcController,
              decoration: const InputDecoration(labelText: 'RFC'),
              enabled: false,
            ),
            TextField(
              controller: licenciaController,
              decoration: const InputDecoration(labelText: 'Licencia'),
              enabled: false,
            ),
            TextField(
              controller: unidadController,
              decoration: const InputDecoration(labelText: 'Unidad'),
            ),
            const SizedBox(height: 24),
            const Text('Filas:', style: TextStyle(fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filas.length,
              itemBuilder: (context, idx) {
                final fila = filas[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: fila.entries
                                .map((e) => Text('${e.key}: ${e.value}'))
                                .toList(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar fila',
                          onPressed: () async {
                            final confirmar = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar fila'),
                                content: const Text(
                                    '¿Seguro que quieres eliminar este registro?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmar == true) {
                              setState(() {
                                filas.removeAt(idx);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar fila'),
                onPressed: () async {
                  // Navegar a la misma página de edición de carta porte, pero en modo agregar fila
                  final nuevaFila =
                      await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => CartaPorteAgregarFilaPage(
                        carta: widget.carta,
                      ),
                    ),
                  );
                  if (nuevaFila != null) {
                    setState(() {
                      filas.add(nuevaFila);
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Página para agregar una nueva fila reutilizando la lógica y vista de carta porte original
class CartaPorteAgregarFilaPage extends StatefulWidget {
  final Map<String, dynamic> carta;
  const CartaPorteAgregarFilaPage({Key? key, required this.carta})
      : super(key: key);

  @override
  State<CartaPorteAgregarFilaPage> createState() =>
      _CartaPorteAgregarFilaPageState();
}

class _CartaPorteAgregarFilaPageState extends State<CartaPorteAgregarFilaPage> {
  late List<Map<String, dynamic>> filas;
  late List<TextEditingController> filaControllers;
  late List<String> columns;

  @override
  void initState() {
    super.initState();
    // Copiar columnas y preparar controladores para una nueva fila
    final ejemplo = (widget.carta['filas'] as List?)?.isNotEmpty == true
        ? Map<String, dynamic>.from((widget.carta['filas'] as List).first)
        : <String, dynamic>{};
    columns = ejemplo.keys.toList();
    filaControllers = columns.map((k) => TextEditingController()).toList();
  }

  @override
  void dispose() {
    for (final c in filaControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autocompletarPorEscaneo(int idx) async {
    // Aquí puedes reutilizar la lógica de _autocompletarFilaPorEscaneo de carta_porte_table.dart
    // Por simplicidad, solo se deja el campo editable
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Fila (completa)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < columns.length; i++)
              TextField(
                controller: filaControllers[i],
                decoration: InputDecoration(labelText: columns[i]),
                onChanged: columns[i].toUpperCase().contains('ESCANEO')
                    ? (_) => _autocompletarPorEscaneo(i)
                    : null,
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final fila = <String, dynamic>{};
                    for (int i = 0; i < columns.length; i++) {
                      fila[columns[i]] = filaControllers[i].text;
                    }
                    Navigator.of(context).pop(fila);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
