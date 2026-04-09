import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HojaDeRutaTable extends StatelessWidget {
  final List<String> columns;
  final List<List<TextEditingController>> controllers;
  final double colWidth;

  const HojaDeRutaTable({
    super.key,
    required this.columns,
    required this.controllers,
    required this.colWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Usar Flex para distribuir columnas proporcionalmente
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 32, // Espaciado amplio
          dataRowMinHeight: 32,
          dataRowMaxHeight: 38,
          headingRowHeight: 38,
          columns: List.generate(columns.length, (colIdx) {
            return DataColumn(
              label: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minWidth: 120),
                child: Text(
                  columns[colIdx],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            );
          }),
          rows: List.generate(controllers.length, (rowIdx) {
            final rowCtrls = controllers[rowIdx];
            return DataRow(
              cells: List.generate(columns.length, (colIdx) {
                return DataCell(Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minWidth: 120),
                  child: TextField(
                    controller: rowCtrls[colIdx],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 8)),
                    style: const TextStyle(fontSize: 14),
                  ),
                ));
              }),
            );
          }),
        ),
      ),
    );
  }
}
