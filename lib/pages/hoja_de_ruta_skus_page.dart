import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Clase para identificar una celda seleccionada (fila, columna)
class _CellPos {
  final int row;
  final int col;
  const _CellPos(this.row, this.col);
  @override
  bool operator ==(Object other) =>
      other is _CellPos && other.row == row && other.col == col;
  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class HojaDeRutaSkusPage extends StatefulWidget {
  final String numeroControl;
  const HojaDeRutaSkusPage({Key? key, required this.numeroControl})
      : super(key: key);

  @override
  State<HojaDeRutaSkusPage> createState() => _HojaDeRutaSkusPageState();
}

class _HojaDeRutaSkusPageState extends State<HojaDeRutaSkusPage> {
  // Cada columna es una lista de SKUs
  List<List<String>> skuColumns = [<String>[]];
  bool isSaved = false;

  // Controladores para pegar desde Excel
  List<TextEditingController> columnControllers = [TextEditingController()];

  // Selección de celdas (fila, columna)
  Set<_CellPos> selectedCells = {};
  _CellPos? lastSelectedCell;

  void _handleCellTap(int row, int col, bool shift) {
    final pos = _CellPos(row, col);
    setState(() {
      if (shift && lastSelectedCell != null) {
        // Selección rectangular
        final r0 = lastSelectedCell!.row;
        final c0 = lastSelectedCell!.col;
        final r1 = row;
        final c1 = col;
        final rMin = r0 < r1 ? r0 : r1;
        final rMax = r0 > r1 ? r0 : r1;
        final cMin = c0 < c1 ? c0 : c1;
        final cMax = c0 > c1 ? c0 : c1;
        selectedCells.clear();
        for (int r = rMin; r <= rMax; r++) {
          for (int c = cMin; c <= cMax; c++) {
            selectedCells.add(_CellPos(r, c));
          }
        }
      } else {
        selectedCells = {pos};
        lastSelectedCell = pos;
      }
    });
  }

  void _handleCopy() {
    if (selectedCells.isEmpty) return;
    final cells = selectedCells.toList()
      ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    final minRow = cells.first.row;
    final maxRow = cells.last.row;
    final minCol = cells.first.col;
    final maxCol = cells.last.col;
    final buffer = StringBuffer();
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        if (c > minCol) buffer.write('\t');
        final colList = c < skuColumns.length ? skuColumns[c] : <String>[];
        final value = r < colList.length ? colList[r] : '';
        buffer.write(value);
      }
      if (r < maxRow) buffer.write('\n');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  void _handlePasteTable(int startRow, int startCol) async {
    final data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null || data.text!.isEmpty) return;
    final rows =
        data.text!.split(RegExp(r'\r?\n')).where((r) => r.isNotEmpty).toList();
    final parsed = rows.map((r) => r.split(RegExp(r'\t'))).toList();
    // Expandir columnas si es necesario
    final neededCols = startCol + parsed[0].length - skuColumns.length;
    if (neededCols > 0) {
      for (int i = 0; i < neededCols; i++) {
        skuColumns.add(<String>[]);
        columnControllers.add(TextEditingController());
      }
    }
    // Expandir filas en cada columna si es necesario
    for (int c = 0; c < parsed[0].length; c++) {
      final col = startCol + c;
      final colList = skuColumns[col];
      final neededRows = startRow + parsed.length - colList.length;
      if (neededRows > 0) {
        colList.addAll(List.filled(neededRows, ''));
      }
    }
    // Pegar los datos
    for (int i = 0; i < parsed.length; i++) {
      for (int j = 0; j < parsed[i].length; j++) {
        final r = startRow + i;
        final c = startCol + j;
        skuColumns[c][r] = parsed[i][j];
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (var ctrl in columnControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addColumn() {
    setState(() {
      skuColumns.add(<String>[]);
      columnControllers.add(TextEditingController());
    });
  }

  void _handlePaste(int colIdx) async {
    final data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null || data.text!.isEmpty) return;
    final rows =
        data.text!.split(RegExp(r'\r?\n')).where((r) => r.isNotEmpty).toList();
    setState(() {
      skuColumns[colIdx] = rows;
      columnControllers[colIdx].text = rows.join('\n');
    });
  }

  Future<void> _guardarSkus() async {
    // Permitir guardar solo SKUs nuevos (no duplicados en Firestore)
    final nuevosSkus = skuColumns.where((col) => col.isNotEmpty).toList();
    if (nuevosSkus.isEmpty) return;

    // Leer los SKUs ya guardados en Firestore
    final docRef = FirebaseFirestore.instance
        .collection('hoja_ruta_skus')
        .doc(widget.numeroControl);
    final docSnap = await docRef.get();
    List<List<dynamic>> skusGuardados = [];
    if (docSnap.exists &&
        docSnap.data() != null &&
        docSnap.data()!['skus'] != null) {
      skusGuardados = List<List<dynamic>>.from(docSnap.data()!['skus'] as List);
    }

    // Aplanar para comparar
    final setGuardados =
        skusGuardados.expand((col) => col.map((e) => e.toString())).toSet();
    final nuevosUnicos = nuevosSkus
        .map((col) => col.where((sku) => !setGuardados.contains(sku)).toList())
        .where((col) => col.isNotEmpty)
        .toList();

    if (nuevosUnicos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay SKUs nuevos para guardar.')),
      );
      return;
    }

    // Combinar los SKUs guardados con los nuevos
    final todos = <List<String>>[];
    for (int i = 0; i < skusGuardados.length; i++) {
      todos.add(List<String>.from(skusGuardados[i].map((e) => e.toString())));
    }
    for (int i = 0; i < nuevosUnicos.length; i++) {
      if (i < todos.length) {
        todos[i].addAll(nuevosUnicos[i]);
      } else {
        todos.add(List<String>.from(nuevosUnicos[i]));
      }
    }

    await docRef.set({'skus': todos});
    setState(() {
      isSaved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SKUs nuevos guardados correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        title: const Text('Agregar SKUs a Hoja de Ruta',
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.5,
            )),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Row(
                  children: [
                    const Text('N° de control:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(widget.numeroControl,
                        style: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const Spacer(),
                    Tooltip(
                      message: 'Agregar columna SKU',
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Columna'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(120, 40),
                        ),
                        onPressed: isSaved ? null : _addColumn,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(skuColumns.length, (colIdx) {
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.only(right: 20, bottom: 8),
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: const Text('SKU',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.deepPurple)),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: skuColumns[colIdx].length + 1,
                                itemBuilder: (context, rowIdx) {
                                  final isCell =
                                      rowIdx < skuColumns[colIdx].length;
                                  final value =
                                      isCell ? skuColumns[colIdx][rowIdx] : '';
                                  return GestureDetector(
                                    onTap: () {
                                      if (!isSaved) {
                                        _handleCellTap(rowIdx, colIdx, false);
                                      }
                                    },
                                    onLongPress: () {
                                      if (!isSaved) {
                                        _handleCellTap(rowIdx, colIdx, true);
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: selectedCells.contains(
                                                _CellPos(rowIdx, colIdx))
                                            ? Colors.deepPurple
                                                .withOpacity(0.12)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: TextField(
                                        controller: isCell
                                            ? TextEditingController(text: value)
                                            : TextEditingController(),
                                        enabled: !isSaved && !isCell,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText:
                                              isCell ? '' : 'Pega SKUs aquí',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 6, horizontal: 10),
                                        ),
                                        onTap: () {
                                          if (!isSaved && !isCell) {
                                            _handlePasteTable(rowIdx, colIdx);
                                          }
                                        },
                                        onChanged: (val) {
                                          if (!isSaved && !isCell) {
                                            if (val.isNotEmpty) {
                                              skuColumns[colIdx].add(val);
                                              setState(() {});
                                            }
                                          }
                                        },
                                        readOnly: isSaved || isCell,
                                        onSubmitted: (_) {},
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(120, 44),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: isSaved ? null : _guardarSkus,
                ),
                const SizedBox(width: 18),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar selección'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(120, 44),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: selectedCells.isEmpty ? null : _handleCopy,
                ),
              ],
            ),
            if (isSaved)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'No se pueden modificar ni borrar los SKUs guardados. Solo puedes copiar o agregar más columnas.',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
