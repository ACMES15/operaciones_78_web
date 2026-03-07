import 'package:flutter/material.dart';
import 'dart:html' as html;

class CartaPortePrinter {
  static void printCartaPorte({
    required String chofer,
    required String unidad,
    required String destino,
    required String rfc,
    required String fecha,
    required List<String> columns,
    required List<List<String>> table,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<html><head><title>Carta Porte</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; margin: 40px; }');
    buffer.writeln('h1 { color: #2D6A4F; text-align: center; }');
    buffer.writeln(
        'table { border-collapse: collapse; width: 100%; margin-top: 24px; }');
    buffer.writeln(
        'th, td { border: 1px solid #888; padding: 6px 10px; font-size: 14px; }');
    buffer.writeln('th { background: #B7E4C7; color: #2D6A4F; }');
    buffer.writeln('.datos { margin: 18px 0; font-size: 16px; }');
    buffer.writeln(
        '.firma { margin-top: 48px; text-align: center; font-size: 16px; }');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<h1>Liv. Galerias 0078</h1>');
    buffer.writeln('<div class="datos">');
    buffer.writeln('<b>Fecha:</b> $fecha<br>');
    buffer.writeln('<b>Chofer:</b> $chofer<br>');
    buffer.writeln('<b>RFC:</b> $rfc<br>');
    buffer.writeln('<b>Unidad:</b> $unidad<br>');
    buffer.writeln('<b>Destino:</b> $destino<br>');
    buffer.writeln('</div>');
    buffer.writeln('<table>');
    buffer.writeln('<tr>');
    for (final col in columns) {
      buffer.writeln('<th>${col.replaceAll("\n", " ")}</th>');
    }
    buffer.writeln('</tr>');
    for (final row in table) {
      buffer.writeln('<tr>');
      for (final cell in row) {
        buffer.writeln('<td>${cell.replaceAll("\n", " ")}</td>');
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</table>');
    buffer.writeln('<div class="firma">');
    buffer.writeln('<br><br><b>Nombre del Chofer:</b> $chofer<br>');
    buffer.writeln(
        '<div style="margin: 24px 0 8px 0; border-bottom: 1px solid #222; width: 300px; margin-left: auto; margin-right: auto;"></div>');
    buffer.writeln('<span>Firma</span>');
    buffer.writeln('</div>');
    buffer.writeln('</body></html>');
    final win = html.window.open('', 'Carta Porte') as html.Window;
    win.document!.documentElement!.setInnerHtml(buffer.toString(),
        treeSanitizer: html.NodeTreeSanitizer.trusted);
    win.print();
  }
}
