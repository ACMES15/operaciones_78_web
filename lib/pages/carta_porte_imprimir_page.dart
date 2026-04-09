import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'carta_porte_pdf_util.dart';

class CartaPorteImprimirPage extends StatelessWidget {
  final Map<String, dynamic> carta;
  const CartaPorteImprimirPage({Key? key, required this.carta})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filas = (carta['filas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final firmaController = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D6A4F)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Imprimir Carta Porte',
          style: TextStyle(
            color: Color.fromARGB(255, 64, 143, 111),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Liv. Galerias 0078',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D6A4F))),
                const SizedBox(height: 16),
                // Datos principales alineados en una sola línea
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text('Fecha: ${carta['fecha'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Chofer: ${carta['chofer'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('RFC: ${carta['rfc'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Licencia: ${carta['licencia'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Unidad: ${carta['unidad'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Destino: ${carta['destino'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Número de control
                Row(
                  children: [
                    const Text('No. Control:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(carta['numero_control']?.toString() ?? '-'),
                  ],
                ),
                const SizedBox(height: 20),
                if (filas.isNotEmpty)
                  Table(
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: Color(0xFFBDBDBD), width: 0.5),
                      outside: BorderSide.none,
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: {
                      for (int i = 0; i < filas.first.keys.length; i++)
                        i: const FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration:
                            const BoxDecoration(color: Color(0xFFE8F5E9)),
                        children: filas.first.keys
                            .map((col) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2, vertical: 1),
                                  child: Text(
                                    col.replaceAll('\n', ' '),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                      ),
                      ...filas.map((fila) => TableRow(
                            children: filas.first.keys
                                .map((col) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2, vertical: 1),
                                      child: Text(
                                        (fila[col]?.toString() ?? '')
                                            .replaceAll('\n', ' '),
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                          )),
                    ],
                  ),
                const SizedBox(height: 32),
                const Divider(),
                const Text('Firma:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: firmaController,
                  decoration: const InputDecoration(hintText: 'Nombre y firma'),
                ),
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 244, 246, 245),
                    ),
                    onPressed: () async {
                      final pdf = await buildCartaPortePdf(carta,
                          firma: firmaController.text);
                      await Printing.layoutPdf(
                        onLayout: (PdfPageFormat format) async => pdf.save(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
