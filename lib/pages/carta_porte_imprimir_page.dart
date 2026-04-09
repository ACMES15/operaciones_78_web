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
                const Text('CARTA PORTE',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(4),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Número de control:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(carta['numero_control']?.toString() ?? '-'),
                      ),
                    ]),
                    TableRow(children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Fecha:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(carta['fecha']?.toString() ?? '-'),
                      ),
                    ]),
                    TableRow(children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Destino:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(carta['destino']?.toString() ?? '-'),
                      ),
                    ]),
                    TableRow(children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Chofer:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(carta['chofer']?.toString() ?? '-'),
                      ),
                    ]),
                    TableRow(children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('RFC:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(carta['rfc']?.toString() ?? '-'),
                      ),
                    ]),
                    TableRow(children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Unidad:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(carta['unidad']?.toString() ?? '-'),
                      ),
                    ]),
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
                    columnWidths: const {},
                    children: [
                      TableRow(
                        decoration:
                            const BoxDecoration(color: Color(0xFFE8F5E9)),
                        children: filas.first.keys
                            .map((col) => Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(col,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                      ),
                      ...filas.map((fila) => TableRow(
                            children: fila.keys
                                .map((col) => Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(fila[col]?.toString() ?? ''),
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
