import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
// import 'package:docx_template/docx_template.dart';

class WordExporter {
  static Future<void> exportCaratula(
      Map<String, String> data, String fileName) async {
    // Generar contenido como texto plano (Word abrirá el archivo aunque sea .docx)
    // Generar HTML para mejor formato en Word
    final buffer = StringBuffer();
    buffer.writeln('<html><head><meta charset="UTF-8"></head><body>');
    buffer.writeln(
        '<table style="width:100%; font-size:22px; border-spacing:32px 16px; page-break-inside:avoid;">');
    // Título principal centrado
    buffer.writeln(
        '<tr><td colspan="3" style="padding:32px 0 0 0; text-align:center; font-size:38px; font-weight:bold;">ENVIOS GALERIAS 78</td></tr>');
    // Destino grande centrado con leyenda
    final destino = data['DESTINO'] ?? '';
    buffer.writeln('<tr>');
    buffer.writeln(
        '<td style="text-align:right; font-size:28px; font-weight:bold; color:#333; padding-right:12px; width:30%;">Destino:</td>');
    buffer.writeln(
        '<td style="text-align:center; font-size:48px; font-weight:bold; color:#1a237e; width:40%;">$destino</td>');
    buffer.writeln('<td style="width:30%;"></td>');
    buffer.writeln('</tr>');
    // Leyenda Origen debajo del destino
    buffer.writeln(
        '<tr><td colspan="3" style="text-align:center; font-size:20px; color:#444; padding-bottom:32px;">Origen: LIV GALERIAS 0078</td></tr>');
    // Datos
    data.forEach((key, value) {
      if (key == 'DESTINO') return; // Ya se muestra arriba
      buffer.writeln('<tr>');
      buffer.writeln(
          '<td style="padding:16px 32px; text-align:left; font-weight:bold; white-space:nowrap;">$key</td>');
      buffer.writeln(
          '<td colspan="2" style="padding:16px 32px; text-align:right; white-space:nowrap;">$value</td>');
      buffer.writeln('</tr>');
    });
    buffer.writeln('</table>');
    buffer.writeln('</body></html>');
    // Usar utf8 para que Word reconozca el HTML correctamente

    final bytes =
        Uint8List.fromList(const Utf8Encoder().convert(buffer.toString()));
    final blob = html.Blob([bytes], 'application/msword');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
