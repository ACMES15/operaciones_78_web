import 'package:flutter/material.dart';
import 'hoja_de_ruta_extra_page.dart';
import '../home_page.dart';
import 'hoja_de_ruta_enviadas_page.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../utils/word_exporter.dart';
import '../utils/firebase_cache_utils.dart';
import '../utils/sheet_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Top-level function for PDF generation to be used with compute
Future<Uint8List> generatePdfBytes(Map<String, dynamic> params) async {
  final headers = List<String>.from(params['headers'] as List);
  final data = List<List<String>>.from(params['data'] as List);
  final origen = params['origen'] as String? ?? '';
  final fecha = params['fecha'] as String? ?? '';
  final caja = params['caja'] as String? ?? '';
  final tipo = params['tipo'] as String? ?? '';
  final numeroControl = params['numeroControl'] as String? ?? '';

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text('Hoja de Ruta',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(
              child: pw.Text('Origen: $origen',
                  style: pw.TextStyle(fontSize: 12))),
          pw.SizedBox(width: 16),
          pw.Text('N° Caja: $caja', style: pw.TextStyle(fontSize: 12)),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(
              child:
                  pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 12))),
          pw.SizedBox(width: 16),
          pw.Text('Tipo: $tipo', style: pw.TextStyle(fontSize: 12)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text('N° de control: $numeroControl',
            style: pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          child: pw.Table.fromTextArray(
            headers: headers,
            data: data,
            cellAlignment: pw.Alignment.center,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 10),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

class HojaDeRutaPage extends StatefulWidget {
  const HojaDeRutaPage({super.key});

  @override
  State<HojaDeRutaPage> createState() => _HojaDeRutaPageState();
}

class _HojaDeRutaPageState extends State<HojaDeRutaPage> {
  final List<String> _columns = const [
    'Docto',
    'No. Manifiesto o Remisión',
    'No. Documento',
    'No. Pedido',
    'No. Bultos',
    'No. Alm.',
    'Nombre Alm. destino',
    'No. Contenedor (HU)',
    'No. Proveedor',
    'Nombre de Proveedor',
    'SELLOS',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_outlined,
                    color: Color(0xFF2D6A4F), size: 32),
                const SizedBox(width: 10),
                const Text(
                  'Hoja de Ruta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.store),
                  label: Text('Tiendas y Proveedores',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 48),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final homeState =
                        context.findAncestorWidgetOfExactType<HomePage>();
                    final usuario = homeState?.usuario ?? '';
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HojaDeRutaExtraPage(usuario: usuario),
                      ),
                    );
                  },
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.send),
                  label: Text('Hojas de ruta enviadas',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 48),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HojaDeRutaEnviadasPage(),
                      ),
                    );
                  },
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Nueva hoja de ruta',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 48),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showHojaRutaDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ...resto del contenido...
          ],
        ),
      ),
    );
  }

  List<List<TextEditingController>> _controllers = [];
  final TextEditingController _cajaController = TextEditingController();
  String _fechaEnvio = '';
  String _origen = 'Liv. Galerias GDL 78';
  // campo antiguo no usado
  // int _numeroControl = 1;
  String? _numeroControlActual;
  final List<String> _opciones = [
    'Transf.',
    'Devoluc.',
    'Rem / Valija',
    'Zona especial'
  ];
  int? _opcionSeleccionada;

  // Nuevo: impresora seleccionada (si el usuario la elige)
  Printer? _selectedPrinter;

  // Índices útiles
  int get _idxNoAlm => _columns.indexOf('No. Alm.');
  int get _idxNombreAlm => _columns.indexOf('Nombre Alm. destino');
  int get _idxNoProveedor => _columns.indexOf('No. Proveedor');
  int get _idxNombreProveedor => _columns.indexOf('Nombre de Proveedor');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaEnvio =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Cargar cachés de tiendas/proveedores para autocompletar nombres
    HojaDeRutaExtraPage.loadTiendasProveedoresCache();
    HojaDeRutaExtraPage.loadSentHojaRutasCache();

    // Inicializar 5 filas
    _controllers = List.generate(
      5,
      (_) => List.generate(_columns.length, (_) => TextEditingController()),
    );
    for (int i = 0; i < _controllers.length; i++) {
      _attachListenersForRow(i);
    }
  }

  @override
  void dispose() {
    for (var row in _controllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    _cajaController.dispose();
    super.dispose();
  }

  // Añadir filas y adjuntar listeners
  void _addDataRow([int count = 1]) {
    setState(() {
      for (int i = 0; i < count; i++) {
        _controllers.add(
            List.generate(_columns.length, (_) => TextEditingController()));
        _attachListenersForRow(_controllers.length - 1);
      }
    });
  }

  void _attachListenersForRow(int rowIdx) {
    if (rowIdx < 0 || rowIdx >= _controllers.length) return;

    final noAlmCtrl = _controllers[rowIdx][_idxNoAlm];
    final nombreAlmCtrl = _controllers[rowIdx][_idxNombreAlm];
    noAlmCtrl.addListener(() {
      final input = noAlmCtrl.text.trim();
      if (input.isEmpty) return;
      final inputLower = input.toLowerCase();
      List<String>? match;
      for (final r in HojaDeRutaExtraPage.tiendasCache) {
        if (r.isEmpty) continue;
        final key = r[0].toString().trim();
        final name = r.length > 1 ? r[1].toString().trim() : '';
        if (key == input || key == input.replaceFirst(RegExp(r"^0+"), '')) {
          match = [key, name];
          break;
        }
        // allow searching by name fragment
        if (name.toLowerCase().contains(inputLower)) {
          match = [key, name];
          break;
        }
      }
      if (match != null && match.length > 1) {
        if (nombreAlmCtrl.text != match[1]) nombreAlmCtrl.text = match[1];
      }
    });

    final noProvCtrl = _controllers[rowIdx][_idxNoProveedor];
    final nombreProvCtrl = _controllers[rowIdx][_idxNombreProveedor];
    noProvCtrl.addListener(() {
      final input = noProvCtrl.text.trim();
      if (input.isEmpty) return;
      final inputLower = input.toLowerCase();
      List<String>? match;
      for (final r in HojaDeRutaExtraPage.proveedoresCache) {
        if (r.isEmpty) continue;
        final key = r[0].toString().trim();
        final name = r.length > 1 ? r[1].toString().trim() : '';
        if (key == input || key == input.replaceFirst(RegExp(r"^0+"), '')) {
          match = [key, name];
          break;
        }
        if (name.toLowerCase().contains(inputLower)) {
          match = [key, name];
          break;
        }
      }
      if (match != null && match.length > 1) {
        if (nombreProvCtrl.text != match[1]) nombreProvCtrl.text = match[1];
      }
    });
  }

  // Nuevo: seleccionar impresora (abre selector de impresoras)
  Future<void> _pickPrinter() async {
    try {
      final Printer? printer = await Printing.pickPrinter(context: context);
      setState(() {
        _selectedPrinter = printer;
      });
      if (printer != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impresora seleccionada: ${printer.name}')));
      }
    } catch (e) {
      if (kDebugMode) print('Error pickPrinter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo seleccionar impresora: $e')));
    }
  }

  // Modificado: impresión usando compute y enviando a impresora seleccionada (si existe)
  Future<void> _printCaratulaHojaRuta() async {
    // Obtener datos principales
    final origen = _origen;
    final destino = _controllers.isNotEmpty &&
            _idxNombreAlm >= 0 &&
            _controllers[0].length > _idxNombreAlm
        ? _controllers[0][_idxNombreAlm].text.trim()
        : '';
    final tipo =
        _opcionSeleccionada != null ? _opciones[_opcionSeleccionada!] : '';
    final numeroControl = _numeroControlActual ?? '';
    final fechaEnvio = _fechaEnvio;
    final caja = _cajaController.text.trim();

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 16),
              pw.Text('Hoja de Ruta',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 18),
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('ORIGEN:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(origen,
                          style: pw.TextStyle(
                              fontSize: 16, color: PdfColors.green800)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('DESTINO:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(destino,
                          style: pw.TextStyle(
                              fontSize: 16, color: PdfColors.blue800)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('Tipo de hoja:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(tipo,
                          style: pw.TextStyle(
                              fontSize: tipo == 'Zona especial' ? 22 : 16,
                              color: tipo == 'Zona especial'
                                  ? PdfColors.red800
                                  : PdfColors.black)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('N° de control:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(numeroControl,
                          style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('Fecha de Envío:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(fechaEnvio,
                          style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text('N° de Caja:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(caja, style: pw.TextStyle(fontSize: 16)),
                    ),
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _printHojaRuta({Map<String, dynamic>? sheet}) async {
    final headers = _columns;
    final data = (sheet == null)
        ? _controllers
            .map((row) => row.map((c) => c.text.trim()).toList())
            .toList()
        : List<List<String>>.from(sheet['rows'] as List);
    final origen = sheet == null ? _origen : (sheet['origen'] ?? '');
    final fecha = sheet == null ? _fechaEnvio : (sheet['fecha'] ?? '');

    final params = <String, dynamic>{
      'headers': headers,
      'data': data,
      'origen': origen,
      'fecha': fecha,
      'caja':
          sheet == null ? _cajaController.text.trim() : (sheet['caja'] ?? ''),
      'tipo': sheet == null
          ? (_opcionSeleccionada != null ? _opciones[_opcionSeleccionada!] : '')
          : (sheet['tipo'] ?? ''),
      'numeroControl': sheet == null
          ? (_numeroControlActual ?? '')
          : (sheet['numeroControl'] ?? ''),
    };

    // Mostrar diálogo de progreso
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      // Generar bytes en isolate (usar función top-level)
      final Uint8List pdfBytes = await compute(generatePdfBytes, params);
      Navigator.of(context).pop(); // cerrar progreso

      if (_selectedPrinter != null) {
        // impresión directa a impresora seleccionada
        await Printing.directPrintPdf(
            printer: _selectedPrinter!,
            onLayout: (PdfPageFormat format) async => pdfBytes);
      } else {
        // abrir diálogo nativo (usuario selecciona impresora)
        await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes);
      }
    } catch (e, st) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al imprimir: $e')));
      if (kDebugMode) print('Error _printHojaRuta: $e\n$st');
    }
  }

  Future<void> _guardarHojaRuta() async {
    final rowsAsMap = _controllers
        .map((r) => {
              for (int i = 0; i < _columns.length; i++)
                _columns[i]: r[i].text.trim(),
            })
        .where((m) => m.values.any((v) => v.isNotEmpty))
        .toList();
    // Obtener usuario firmado desde HomePage
    final homeState = context.findAncestorWidgetOfExactType<HomePage>();
    final usuario = homeState?.usuario ?? '';
    final sheet = <String, dynamic>{
      'origen': _origen,
      'fecha': _fechaEnvio,
      'numeroControl': _numeroControlActual ?? '',
      'tipo':
          _opcionSeleccionada != null ? _opciones[_opcionSeleccionada!] : '',
      'caja': _cajaController.text.trim(),
      'headers': _columns,
      'rows': rowsAsMap,
      'createdAt': DateTime.now().toIso8601String(),
      'usuario': usuario,
    };
    // Validar antes de guardar
    final vr = validateSheet(sheet);
    if (!vr.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${vr.errors.join('; ')}')));
      return;
    }

    HojaDeRutaExtraPage.sentHojaRutas.add(sheet);
    // Guardar en Firebase y actualizar cache (legacy)
    await guardarDatosFirestoreYCache('hoja_ruta', 'sentHojaRutas',
        {'items': HojaDeRutaExtraPage.sentHojaRutas});

    // NUEVO: Guardar hoja individual como documento en hoja_ruta
    // Usamos numeroControl como ID único (si no existe, generamos uno seguro)
    String docId = (sheet['numeroControl'] ??
            DateTime.now().millisecondsSinceEpoch.toString())
        .toString();
    // Serializar todos los valores a tipos compatibles con Firestore
    final Map<String, dynamic> serializableSheet = {};
    sheet.forEach((key, value) {
      if (value is DateTime) {
        serializableSheet[key] = value.toIso8601String();
      } else if (value is List) {
        serializableSheet[key] = value
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : e.toString())
            .toList();
      } else if (value is Map) {
        serializableSheet[key] = Map<String, dynamic>.from(value);
      } else {
        serializableSheet[key] = value?.toString() ?? '';
      }
    });
    await FirebaseFirestore.instance
        .collection('hoja_ruta')
        .doc(docId)
        .set(serializableSheet);

    // Generar Word con los datos principales
    final destino = _controllers.isNotEmpty
        ? _controllers[0][_idxNombreAlm].text.trim()
        : '';
    final wordData = <String, String>{
      'ORIGEN': _origen,
      'N° DE CAJA': _cajaController.text.trim(),
      'FECHA': _fechaEnvio,
      'N° DE CONTROL': _numeroControlActual ?? '',
      'TIPO DE HOJA':
          _opcionSeleccionada != null ? _opciones[_opcionSeleccionada!] : '',
      'DESTINO': destino,
    };
    WordExporter.exportCaratula(
        wordData, 'Hoja_de_Ruta_${_numeroControlActual ?? ''}.docx');

    // Limpiar todos los campos y dejar lista la hoja para nuevos datos
    setState(() {
      _cajaController.clear();
      _opcionSeleccionada = null;
      _numeroControlActual = null;
      // Limpiar todas las filas
      for (var row in _controllers) {
        for (var c in row) {
          c.clear();
        }
      }
      // Si quieres resetear a 5 filas vacías siempre, descomenta:
      // _controllers = List.generate(5, (_) => List.generate(_columns.length, (_) => TextEditingController()));
      // for (int i = 0; i < _controllers.length; i++) {
      //   _attachListenersForRow(i);
      // }
    });
  }

  Future<void> guardarTablaHojaRuta() async {
    final sheet = <String, dynamic>{
      'origen': _origen,
      'fecha': _fechaEnvio,
      'numeroControl': _numeroControlActual ?? '',
      'tipo':
          _opcionSeleccionada != null ? _opciones[_opcionSeleccionada!] : '',
      'caja': _cajaController.text.trim(),
      'headers': _columns,
      'rows': _controllers
          .map((r) => r.map((c) => c.text.trim()).toList())
          .toList(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    await guardarDatosFirestoreYCache('hojas_ruta',
        sheet['numeroControl'] ?? DateTime.now().toIso8601String(), sheet);
  }

  Future<Map<String, dynamic>?> leerTablaHojaRuta(String numeroControl) async {
    return await leerDatosConCache('hojas_ruta', numeroControl);
  }

  // Muestra diálogo con la tabla
  Future<void> _showHojaRutaDialog(BuildContext context) async {
    // Antes de mostrar el diálogo, asegurarnos de tener la última lista de hojas enviadas
    try {
      // Recargar cachés y sent hojas para asegurarnos de usar datos recientes
      await HojaDeRutaExtraPage.loadTiendasProveedoresCache();
      await HojaDeRutaExtraPage.loadSentHojaRutasCache();
    } catch (_) {}

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          Future<bool> _confirmarSalir() async {
            final tieneDatos = _controllers
                    .any((row) => row.any((c) => c.text.trim().isNotEmpty)) ||
                _cajaController.text.trim().isNotEmpty ||
                _numeroControlActual != null ||
                _opcionSeleccionada != null;
            if (!tieneDatos) return true;
            final res = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('¿Seguro que quieres salir?'),
                content: const Text('Se perderán los datos no guardados.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            );
            return res == true;
          }

          final double maxWidth = MediaQuery.of(context).size.width * 0.95;
          double colWidth = ((maxWidth - 48) / _columns.length).clamp(70, 120);
          final double minTableWidth = _columns.length * colWidth;

          // Calcular el siguiente número de control disponible
          String getNextNumeroControl() {
            final List<String> usados = HojaDeRutaExtraPage.sentHojaRutas
                .map((s) => (s['numeroControl'] ?? '').toString())
                .where((n) => n.startsWith('0078-'))
                .toList();
            int maxNum = 0;
            for (final n in usados) {
              final numStr = n.replaceFirst('0078-', '');
              final num = int.tryParse(numStr);
              if (num != null && num > maxNum) maxNum = num;
            }
            return '0078-${(maxNum + 1).toString().padLeft(3, '0')}';
          }

          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.95),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cerrar',
                            onPressed: () async {
                              FocusScope.of(context).unfocus();
                              final salir = await _confirmarSalir();
                              if (salir) Navigator.of(context).pop();
                            })),
                    // Cabecera: ORIGEN / Tipo de hoja
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ORIGEN',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(_origen,
                                      style: const TextStyle(fontSize: 15)),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    const Text('No. de Caja:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                        width: 80,
                                        child: TextField(
                                            controller: _cajaController,
                                            decoration: const InputDecoration(
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 8)))),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Text('Fecha de Envío:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text(_fechaEnvio)
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Text('Núm. de control:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    if (_numeroControlActual != null)
                                      Text(_numeroControlActual!,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        setModalState(() {
                                          _numeroControlActual =
                                              getNextNumeroControl();
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF2D6A4F),
                                          foregroundColor: Colors.white),
                                      child: const Text(
                                          'Generar número de control'),
                                    )
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tipo de hoja:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                      spacing: 8,
                                      children:
                                          List.generate(_opciones.length, (i) {
                                        final selected =
                                            _opcionSeleccionada == i;
                                        return ChoiceChip(
                                          label: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(_opciones[i]),
                                                if (selected)
                                                  const Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 4),
                                                      child: Icon(Icons.check,
                                                          size: 18,
                                                          color: Colors.green))
                                              ]),
                                          selected: selected,
                                          selectedColor: Colors.green.shade50,
                                          onSelected: (_) => setModalState(
                                              () => _opcionSeleccionada = i),
                                          backgroundColor: Colors.grey.shade200,
                                          labelStyle: TextStyle(
                                              color: selected
                                                  ? Colors.green.shade900
                                                  : Colors.black87),
                                        );
                                      })),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Botones: impresora seleccionada + seleccionar, imprimir, guardar, agregar fila
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Mostrar impresora seleccionada
                            if (_selectedPrinter != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Row(children: [
                                  Icon(Icons.print, size: 16),
                                  SizedBox(width: 6),
                                  Text(_selectedPrinter?.name ?? 'Sin nombre')
                                ]),
                              )
                            else
                              const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Text('Impresora: por defecto')),
                            TextButton.icon(
                                icon: const Icon(Icons.search),
                                label: const Text('Seleccionar impresora'),
                                onPressed: () async {
                                  await _pickPrinter();
                                  setModalState(() {});
                                }),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.print),
                                label: const Text('Imprimir caratula'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white),
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  await _printCaratulaHojaRuta();
                                }),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.print),
                                label: const Text('Imprimir'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white),
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  await _printHojaRuta();
                                }),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: const Text('Guardar hoja de ruta'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0B6623),
                                    foregroundColor: Colors.white),
                                onPressed: () async {
                                  // 1. Guardar datos en variable local
                                  final rowsAsMap = _controllers
                                      .map((r) => {
                                            for (int i = 0;
                                                i < _columns.length;
                                                i++)
                                              _columns[i]: r[i].text.trim(),
                                          })
                                      .where((m) =>
                                          m.values.any((v) => v.isNotEmpty))
                                      .toList();
                                  final homeState =
                                      context.findAncestorWidgetOfExactType<
                                          HomePage>();
                                  final usuario = homeState?.usuario ?? '';
                                  final sheet = <String, dynamic>{
                                    'origen': _origen,
                                    'fecha': _fechaEnvio,
                                    'numeroControl': _numeroControlActual ?? '',
                                    'tipo': _opcionSeleccionada != null
                                        ? _opciones[_opcionSeleccionada!]
                                        : '',
                                    'caja': _cajaController.text.trim(),
                                    'headers': _columns,
                                    'rows': rowsAsMap,
                                    'createdAt':
                                        DateTime.now().toIso8601String(),
                                    'usuario': usuario,
                                  };
                                  // 2. Validar y guardar en Firestore
                                  final vr = validateSheet(sheet);
                                  if (!vr.ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error al guardar: \\${vr.errors.join('; ')}')));
                                    return;
                                  }
                                  HojaDeRutaExtraPage.sentHojaRutas.add(sheet);
                                  await guardarDatosFirestoreYCache(
                                      'hoja_ruta', 'sentHojaRutas', {
                                    'items': HojaDeRutaExtraPage.sentHojaRutas
                                  });
                                  String docId = (sheet['numeroControl'] ??
                                          DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString())
                                      .toString();
                                  final Map<String, dynamic> serializableSheet =
                                      {};
                                  sheet.forEach((key, value) {
                                    if (value is DateTime) {
                                      serializableSheet[key] =
                                          value.toIso8601String();
                                    } else if (value is List) {
                                      serializableSheet[key] = value
                                          .map((e) => e is Map
                                              ? Map<String, dynamic>.from(e)
                                              : e.toString())
                                          .toList();
                                    } else if (value is Map) {
                                      serializableSheet[key] =
                                          Map<String, dynamic>.from(value);
                                    } else {
                                      serializableSheet[key] =
                                          value?.toString() ?? '';
                                    }
                                  });
                                  await FirebaseFirestore.instance
                                      .collection('hoja_ruta')
                                      .doc(docId)
                                      .set(serializableSheet);
                                  // 3. Imprimir usando la variable local
                                  await _printHojaRuta(sheet: sheet);
                                  // 4. Limpiar campos después de imprimir
                                  setState(() {
                                    _cajaController.clear();
                                    _opcionSeleccionada = null;
                                    _numeroControlActual = null;
                                    for (var row in _controllers) {
                                      for (var c in row) {
                                        c.clear();
                                      }
                                    }
                                  });
                                }),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar fila'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D6A4F),
                                    foregroundColor: Colors.white),
                                onPressed: () {
                                  _addDataRow();
                                  if (_controllers.length < 5)
                                    _addDataRow(5 - _controllers.length);
                                  setModalState(() {});
                                }),
                          ]),
                    ),
                    const SizedBox(height: 4),
                    // Tabla
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minWidth: minTableWidth),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Card(
                                elevation: 1,
                                margin: const EdgeInsets.all(0),
                                child: DataTable(
                                  columnSpacing: 2,
                                  dataRowMinHeight: 28,
                                  dataRowMaxHeight: 32,
                                  headingRowHeight: 34,
                                  columns:
                                      List.generate(_columns.length, (colIdx) {
                                    return DataColumn(
                                      label: Container(
                                        alignment: Alignment.center,
                                        width: colWidth,
                                        decoration: BoxDecoration(
                                          border: colIdx < _columns.length - 1
                                              ? const Border(
                                                  right: BorderSide(
                                                      color: Color(0xFFE0E0E0),
                                                      width: 1))
                                              : null,
                                        ),
                                        child: Text(_columns[colIdx],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                    );
                                  }),
                                  rows: List.generate(_controllers.length,
                                      (rowIdx) {
                                    final rowCtrls = _controllers[rowIdx];
                                    return DataRow(
                                        cells: List.generate(_columns.length,
                                            (colIdx) {
                                      return DataCell(Container(
                                        alignment: Alignment.center,
                                        width: colWidth,
                                        decoration: BoxDecoration(
                                          border: colIdx < _columns.length - 1
                                              ? const Border(
                                                  right: BorderSide(
                                                      color: Color(0xFFE0E0E0),
                                                      width: 1))
                                              : null,
                                        ),
                                        child: TextField(
                                          controller: rowCtrls[colIdx],
                                          textAlign: TextAlign.center,
                                          decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 4)),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ));
                                    }));
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
