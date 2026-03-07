// Agrega esto a tu pubspec.yaml:
//
// dependencies:
//   pluto_grid: ^7.0.0
//
// Luego ejecuta: flutter pub get
//
// Este archivo es un ejemplo de cómo usar PlutoGrid para una tabla tipo Excel editable y rápida.

import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

class HojaDeRutaPlutoPage extends StatefulWidget {
  const HojaDeRutaPlutoPage({super.key});

  @override
  State<HojaDeRutaPlutoPage> createState() => _HojaDeRutaPlutoPageState();
}

class _HojaDeRutaPlutoPageState extends State<HojaDeRutaPlutoPage> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;
  late PlutoGridStateManager stateManager;

  @override
  void initState() {
    super.initState();
    columns = [
      PlutoColumn(
          title: 'Centro', field: 'centro', type: PlutoColumnType.text()),
      PlutoColumn(
          title: 'Documento', field: 'documento', type: PlutoColumnType.text()),
      PlutoColumn(
          title: 'Pedido', field: 'pedido', type: PlutoColumnType.text()),
      PlutoColumn(
          title: 'Destino', field: 'destino', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Tipo', field: 'tipo', type: PlutoColumnType.text()),
      PlutoColumn(
          title: 'Sellos', field: 'sellos', type: PlutoColumnType.text()),
      PlutoColumn(
          title: 'Contenedor',
          field: 'contenedor',
          type: PlutoColumnType.text()),
      PlutoColumn(
          title: 'Proveedor', field: 'proveedor', type: PlutoColumnType.text()),
    ];
    rows = List.generate(
        5,
        (i) => PlutoRow(cells: {
              'centro': PlutoCell(value: ''),
              'documento': PlutoCell(value: ''),
              'pedido': PlutoCell(value: ''),
              'destino': PlutoCell(value: ''),
              'tipo': PlutoCell(value: ''),
              'sellos': PlutoCell(value: ''),
              'contenedor': PlutoCell(value: ''),
              'proveedor': PlutoCell(value: ''),
            }));
  }

  void _agregarFila() {
    setState(() {
      rows.add(PlutoRow(cells: {
        'centro': PlutoCell(value: ''),
        'documento': PlutoCell(value: ''),
        'pedido': PlutoCell(value: ''),
        'destino': PlutoCell(value: ''),
        'tipo': PlutoCell(value: ''),
        'sellos': PlutoCell(value: ''),
        'contenedor': PlutoCell(value: ''),
        'proveedor': PlutoCell(value: ''),
      }));
      stateManager.notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoja de Ruta (PlutoGrid)'),
        backgroundColor: const Color.fromARGB(184, 69, 70, 69),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar fila'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                ),
                onPressed: _agregarFila,
              ),
              const SizedBox(width: 16),
            ],
          ),
          Expanded(
            child: PlutoGrid(
              columns: columns,
              rows: rows,
              onLoaded: (event) => stateManager = event.stateManager,
              configuration: PlutoGridConfiguration(
                style: PlutoGridStyleConfig(
                  gridBorderColor: Colors.grey.shade300,
                  activatedColor: const Color(0xFF2D6A4F).withOpacity(0.15),
                  cellTextStyle: const TextStyle(fontSize: 15),
                ),
              ),
              onChanged: (PlutoGridOnChangedEvent event) {},
            ),
          ),
        ],
      ),
    );
  }
}
