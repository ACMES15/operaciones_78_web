import 'package:flutter/material.dart';

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
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(0),
      child: DataTable(
        columnSpacing: 2,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        headingRowHeight: 34,
        columns: List.generate(columns.length, (colIdx) {
          return DataColumn(
            label: Container(
              alignment: Alignment.center,
              width: colWidth,
              decoration: BoxDecoration(
                border: colIdx < columns.length - 1
                    ? const Border(
                        right: BorderSide(color: Color(0xFFE0E0E0), width: 1))
                    : null,
              ),
              child: Text(columns[colIdx],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        }),
        rows: List.generate(controllers.length, (rowIdx) {
          final rowCtrls = controllers[rowIdx];
          return DataRow(
            cells: List.generate(columns.length, (colIdx) {
              return DataCell(Container(
                alignment: Alignment.center,
                width: colWidth,
                decoration: BoxDecoration(
                  border: colIdx < columns.length - 1
                      ? const Border(
                          right: BorderSide(color: Color(0xFFE0E0E0), width: 1))
                      : null,
                ),
                child: TextField(
                  controller: rowCtrls[colIdx],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 6, horizontal: 4)),
                  style: const TextStyle(fontSize: 13),
                ),
              ));
            }),
          );
        }),
      ),
    );
  }
}
