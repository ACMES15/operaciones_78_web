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
    // No permitir guardar si ya se guardó
    if (isSaved) return;
    final skus = skuColumns.where((col) => col.isNotEmpty).toList();
    if (skus.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('hoja_ruta_skus')
        .doc(widget.numeroControl)
        .set({'skus': skus});
    setState(() {
      isSaved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SKUs guardados correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar SKUs a Hoja de Ruta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('N° de control:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(widget.numeroControl,
                    style: const TextStyle(color: Colors.green)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar columna SKU',
                  onPressed: isSaved ? null : _addColumn,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(skuColumns.length, (colIdx) {
                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Text('SKU',
                                style: TextStyle(fontWeight: FontWeight.bold)),
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
                                    color: selectedCells
                                            .contains(_CellPos(rowIdx, colIdx))
                                        ? Colors.lightGreenAccent
                                            .withOpacity(0.4)
                                        : null,
                                    child: TextField(
                                      controller: isCell
                                          ? TextEditingController(text: value)
                                          : TextEditingController(),
                                      enabled: !isSaved && !isCell,
                                      maxLines: 1,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText:
                                            isCell ? '' : 'Pega SKUs aquí',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 4, horizontal: 6),
                                      ),
                                      onTap: () {
                                        if (!isSaved && !isCell) {
                                          // Pega tabla completa desde Excel
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
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  onPressed: isSaved ? null : _guardarSkus,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar selección'),
                  onPressed: selectedCells.isEmpty ? null : _handleCopy,
                ),
              ],
            ),
            if (isSaved)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No se pueden modificar ni borrar los SKUs guardados. Solo puedes copiar o agregar más columnas.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
