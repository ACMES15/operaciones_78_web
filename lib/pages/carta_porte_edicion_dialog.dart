import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartaPorteEdicionDialog extends StatefulWidget {
  final Map<String, dynamic> carta;
  final bool editable;
  final void Function(Map<String, dynamic>)? onGuardar;
  final VoidCallback? onImprimir;

  const CartaPorteEdicionDialog({
    super.key,
    required this.carta,
    required this.editable,
    this.onGuardar,
    this.onImprimir,
  });

  @override
  State<CartaPorteEdicionDialog> createState() =>
      _CartaPorteEdicionDialogState();
}

class _CartaPorteEdicionDialogState extends State<CartaPorteEdicionDialog> {
  late TextEditingController destinoCtrl;
  late TextEditingController choferCtrl;
  late TextEditingController unidadCtrl;
  late TextEditingController rfcCtrl;
  late TextEditingController licenciaCtrl;
  late TextEditingController concentradoCtrl;
  String? numeroControl;
  String? fecha;
  List<Map<String, dynamic>> choferes = [];
  bool cargandoChoferes = false;
  bool guardandoChofer = false;

  @override
  void initState() {
    super.initState();
    destinoCtrl = TextEditingController(text: widget.carta['DESTINO'] ?? '');
    choferCtrl = TextEditingController(text: widget.carta['CHOFER'] ?? '');
    unidadCtrl = TextEditingController(text: widget.carta['UNIDAD'] ?? '');
    rfcCtrl = TextEditingController(text: widget.carta['RFC'] ?? '');
    licenciaCtrl = TextEditingController(text: widget.carta['LICENCIA'] ?? '');
    concentradoCtrl =
        TextEditingController(text: widget.carta['CONCENTRADO'] ?? '');
    numeroControl = widget.carta['NUMERO_CONTROL'] ?? '';
    fecha = widget.carta['FECHA'] ?? '';
    _cargarChoferes();
  }

  Future<void> _cargarChoferes() async {
    setState(() => cargandoChoferes = true);
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
      cargandoChoferes = false;
    });
  }

  Future<void> _agregarChofer() async {
    final nombre = choferCtrl.text.trim();
    final rfc = rfcCtrl.text.trim();
    final licencia = licenciaCtrl.text.trim();
    if (nombre.isEmpty || licencia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y licencia son obligatorios')),
      );
      return;
    }
    setState(() => guardandoChofer = true);
    await FirebaseFirestore.instance.collection('choferes').add({
      'nombre': nombre,
      'rfc': rfc,
      'licencia': licencia,
    });
    choferCtrl.clear();
    rfcCtrl.clear();
    licenciaCtrl.clear();
    setState(() => guardandoChofer = false);
    await _cargarChoferes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chofer agregado correctamente')),
    );
  }

  @override
  void dispose() {
    destinoCtrl.dispose();
    choferCtrl.dispose();
    unidadCtrl.dispose();
    rfcCtrl.dispose();
    licenciaCtrl.dispose();
    concentradoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                cargandoChoferes
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Choferes registrados:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          choferes.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('No hay choferes registrados.'),
                                )
                              : Column(
                                  children: choferes
                                      .map((c) => ListTile(
                                            dense: true,
                                            leading: const Icon(Icons.person,
                                                color: Color(0xFF2D6A4F)),
                                            title: Text(c['nombre'] ?? ''),
                                            subtitle: Text(
                                                'RFC: ${c['rfc'] ?? ''} | Licencia: ${c['licencia'] ?? ''}'),
                                          ))
                                      .toList(),
                                ),
                        ],
                      ),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: choferCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del chofer',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: licenciaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Licencia',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: rfcCtrl,
                        decoration: const InputDecoration(
                          labelText: 'RFC',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: guardandoChofer
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.person_add),
                      label: const Text('Agregar chofer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                      ),
                      onPressed: guardandoChofer ? null : _agregarChofer,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Editar Carta Porte',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                    const Spacer(),
                    if (numeroControl != null &&
                        numeroControl.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB7E4C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF2D6A4F)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.confirmation_number,
                                size: 18, color: Color(0xFF2D6A4F)),
                            const SizedBox(width: 6),
                            Text(
                              numeroControl ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D6A4F),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('DESTINO:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: destinoCtrl,
                        enabled: widget.editable,
                        decoration: const InputDecoration(
                          hintText: 'Destino',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('CHOFER:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: choferCtrl,
                        enabled: widget.editable,
                        decoration: const InputDecoration(
                          hintText: 'Chofer',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('LICENCIA:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: licenciaCtrl,
                        enabled: widget.editable,
                        decoration: const InputDecoration(
                          hintText: 'Licencia',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('UNIDAD:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: unidadCtrl,
                        enabled: widget.editable,
                        decoration: const InputDecoration(
                          hintText: 'Unidad',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('RFC:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: rfcCtrl,
                        enabled: widget.editable,
                        decoration: const InputDecoration(
                          hintText: 'RFC',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('CONCENTRADO:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: concentradoCtrl,
                        enabled: widget.editable,
                        decoration: const InputDecoration(
                          hintText: 'Concentrado',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.editable)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2D6A4F),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final nuevaCarta = {
                            ...widget.carta,
                            'DESTINO': destinoCtrl.text.trim(),
                            'CHOFER': choferCtrl.text.trim(),
                            'LICENCIA': licenciaCtrl.text.trim(),
                            'UNIDAD': unidadCtrl.text.trim(),
                            'RFC': rfcCtrl.text.trim(),
                            'CONCENTRADO': concentradoCtrl.text.trim(),
                          };
                          if (widget.onGuardar != null)
                            widget.onGuardar!(nuevaCarta);
                        },
                      ),
                    if (!widget.editable)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Imprimir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2D6A4F),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: widget.onImprimir,
                      ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
