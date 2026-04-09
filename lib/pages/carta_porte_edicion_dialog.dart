import 'package:flutter/material.dart';

class CartaPorteEdicionDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final destinoCtrl = TextEditingController(text: carta['DESTINO'] ?? '');
    final choferCtrl = TextEditingController(text: carta['CHOFER'] ?? '');
    final unidadCtrl = TextEditingController(text: carta['UNIDAD'] ?? '');
    final rfcCtrl = TextEditingController(text: carta['RFC'] ?? '');
    final licenciaCtrl = TextEditingController(text: carta['LICENCIA'] ?? '');
    final concentradoCtrl =
        TextEditingController(text: carta['CONCENTRADO'] ?? '');
    final numeroControl = carta['NUMERO_CONTROL'] ?? '';
    final fecha = carta['FECHA'] ?? '';

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Editar Carta Porte',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const Spacer(),
                if (numeroControl != null &&
                    numeroControl.toString().isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          numeroControl,
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
                    enabled: editable,
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
                    enabled: editable,
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
                    enabled: editable,
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
                    enabled: editable,
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
                    enabled: editable,
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
                    enabled: editable,
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
                if (editable)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final nuevaCarta = {
                        ...carta,
                        'DESTINO': destinoCtrl.text.trim(),
                        'CHOFER': choferCtrl.text.trim(),
                        'LICENCIA': licenciaCtrl.text.trim(),
                        'UNIDAD': unidadCtrl.text.trim(),
                        'RFC': rfcCtrl.text.trim(),
                        'CONCENTRADO': concentradoCtrl.text.trim(),
                      };
                      if (onGuardar != null) onGuardar!(nuevaCarta);
                    },
                  ),
                if (!editable)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onImprimir,
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
    );
  }
}
