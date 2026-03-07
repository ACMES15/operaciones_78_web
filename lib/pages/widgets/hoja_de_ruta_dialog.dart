import 'package:flutter/material.dart';
import '../hoja_de_ruta_page.dart';

class HojaDeRutaDialog extends StatelessWidget {
  final List<String> columns;
  final List<List<TextEditingController>> controllers;
  final TextEditingController cajaController;
  final String fechaEnvio;
  final String origen;
  final String? numeroControlActual;
  final int numeroControl;
  final List<String> opciones;
  final int? opcionSeleccionada;
  final Function() onGenerarNumeroControl;
  final Function() onGuardar;
  final Function() onAgregarFila;
  final Function() onImprimir;
  final Function() onPickPrinter;
  final dynamic selectedPrinter;

  const HojaDeRutaDialog({
    super.key,
    required this.columns,
    required this.controllers,
    required this.cajaController,
    required this.fechaEnvio,
    required this.origen,
    required this.numeroControlActual,
    required this.numeroControl,
    required this.opciones,
    required this.opcionSeleccionada,
    required this.onGenerarNumeroControl,
    required this.onGuardar,
    required this.onAgregarFila,
    required this.onImprimir,
    required this.onPickPrinter,
    required this.selectedPrinter,
  });

  @override
  Widget build(BuildContext context) {
    // ... Copiar el contenido del diálogo desde hoja_de_ruta_page.dart y reemplazar referencias por los parámetros
    return const Placeholder(); // Reemplazar por el widget real
  }
}
