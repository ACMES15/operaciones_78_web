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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Número de control: \\${carta['numero_control'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Fecha: \\${carta['fecha'] ?? '-'}'),
              Text('Destino: \\${carta['destino'] ?? '-'}'),
              Text('Chofer: \\${carta['chofer'] ?? '-'}'),
              Text('RFC: \\${carta['rfc'] ?? '-'}'),
              Text('Unidad: \\${carta['unidad'] ?? '-'}'),
              const SizedBox(height: 16),
              const Text('Filas:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...filas.map((fila) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: fila.entries
                            .map((e) => Text('${e.key}: ${e.value}'))
                            .toList(),
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
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
    );
  }
}
