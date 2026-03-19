import 'package:flutter/material.dart';
import 'entregas_cyc_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DevCycPage extends StatefulWidget {
  final String usuario;
  const DevCycPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<DevCycPage> createState() => _DevCycPageState();
}

class _DevCycPageState extends State<DevCycPage> {
  final List<String> _headers = [
    'NUMERO DE PEDIDO',
    'LP',
    'SKU',
    'DESCRIPCION',
    'SECCION',
    'BODEGA',
    'JEFATURA',
  ];
  final List<List<TextEditingController>> _rows = [];

  void _addRow() {
    setState(() {
      final ctrls =
          List.generate(_headers.length, (_) => TextEditingController());
      _rows.add(ctrls);
    });
  }

  void _verEntregasCyc() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntregasCycPage(usuario: widget.usuario),
      ),
    );
  }

  // Aquí puedes agregar lógica de guardado, importación, etc., similar a EntregasCDR pero adaptada a los headers

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev CyC'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addRow,
                  child: const Text('Agregar fila'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _verEntregasCyc,
                  child: const Text('Ver Entregas CyC'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _headers.length * 140,
                  child: Column(
                    children: [
                      Container(
                        color: const Color(0xFFE9ECEF),
                        child: Row(
                          children: List.generate(_headers.length, (i) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  _headers[i],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, rowIdx) {
                            return Row(
                              children:
                                  List.generate(_headers.length, (colIdx) {
                                return Expanded(
                                  child: TextField(
                                    controller: _rows[rowIdx][colIdx],
                                    decoration: const InputDecoration(
                                        border: InputBorder.none),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
