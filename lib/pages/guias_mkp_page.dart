import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sincronizar_devoluciones_mkp.dart';
import '../utils/firebase_cache_utils.dart';

class GuiasMkpPage extends StatefulWidget {
  const GuiasMkpPage({Key? key}) : super(key: key);

  @override
  State<GuiasMkpPage> createState() => _GuiasMkpPageState();
}

class _GuiasMkpPageState extends State<GuiasMkpPage> {
  // Controladores para cada celda editable
  final Map<String, TextEditingController> _devolucionControllers = {};
  final Map<String, TextEditingController> _guiaControllers = {};
  final Map<String, FocusNode> _guiaFocusNodes = {};
  Timer? _notificacionDebounce;

  // Genera una clave única para cada fila
  String _rowKey(Map<String, dynamic> reg) =>
      '${reg['devolucion'] ?? ''}_${reg['fecha'] ?? ''}';

  @override
  void dispose() {
    _notificacionDebounce?.cancel();
    _busquedaController.dispose();
    for (final c in _devolucionControllers.values) {
      c.dispose();
    }
    for (final c in _guiaControllers.values) {
      c.dispose();
    }
    for (final f in _guiaFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool _sincronizando = false;
  Future<void> _sincronizarDevoluciones(
      BuildContext context, List<Map<String, dynamic>> registros) async {
    setState(() => _sincronizando = true);
    try {
      final count = await sincronizarDevolucionesMKP();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(count > 0
                ? 'Se agregaron $count devoluciones nuevas.'
                : 'No hay devoluciones nuevas para agregar.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al sincronizar: $e')),
      );
    } finally {
      setState(() => _sincronizando = false);
    }
  }

  // Notifica a admins si hay devoluciones sin guía con más de 24h
  Future<void> _notificarDevolucionesSinGuia(
      List<Map<String, dynamic>> registros) async {
    final ahora = DateTime.now();
    // Buscar devoluciones sin guía y con fecha > 24h
    final sinGuia24h = registros.where((r) {
      if ((r['devolucion'] ?? '').toString().isEmpty ||
          (r['guia'] ?? '').toString().isNotEmpty) return false;
      final fechaStr = r['fecha'] ?? '';
      if (fechaStr.isEmpty) return false;
      DateTime? fecha;
      try {
        fecha = DateTime.parse(fechaStr);
      } catch (_) {
        return false;
      }
      return ahora.difference(fecha).inHours >= 24;
    }).toList();
    if (sinGuia24h.isEmpty) return;

    final admins = ['ADMIN OMNICANAL', 'ADMIN ENVIOS'];
    final mensaje =
        'Se tienen Devoluciones sin tratar un total de: ${sinGuia24h.length}';
    final detalle =
        'Devoluciones sin guía con más de 24h: ${sinGuia24h.map((r) => r['devolucion']).join(', ')}';
    final fecha = ahora.toIso8601String();

    // Leer notificaciones existentes (para compatibilidad con notificaciones_page)
    final doc = await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc('password')
        .get();
    List items = [];
    if (doc.exists && doc.data() != null) {
      items = (doc.data()!['items'] ?? []) as List;
    }
    // Revisar si ya se envió una notificación igual en las últimas 24h
    final yaEnviada = items.any((n) {
      if (n is! Map) return false;
      if (n['mensaje'] != mensaje) return false;
      if (n['fecha'] == null) return false;
      try {
        final f = DateTime.parse(n['fecha']);
        return ahora.difference(f).inHours < 24;
      } catch (_) {
        return false;
      }
    });
    if (yaEnviada) return;

    // Agregar notificación para cada admin en el array (para notificaciones_page)
    for (final admin in admins) {
      items.add({
        'mensaje': mensaje,
        'detalle': detalle,
        'fecha': fecha,
        'usuario': admin,
        'atendido': false,
      });
    }
    await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc('password')
        .set({'items': items});

    // Agregar notificación para cada admin como documento individual (para campana principal)
    for (final admin in admins) {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'detalle': detalle,
        'fecha': fecha,
        'para': admin,
        'leida': false,
        'tipo': 'devolucion_sin_guia',
      });
    }
  }

  void _exportarAExcel(List<Map<String, dynamic>> registros) async {
    if (registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Guías MKP'];
    final headers = [
      'Devolución',
      'Guía',
      'Fecha',
    ];
    sheet.appendRow(headers);
    for (final reg in registros) {
      sheet.appendRow([
        reg['devolucion'] ?? '',
        reg['guia'] ?? '',
        reg['fecha'] ?? '',
      ]);
    }
    final bytes = excelFile.encode()!;
    final blob = html.Blob([Uint8List.fromList(bytes)],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'guias_mkp.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  final TextEditingController _busquedaController = TextEditingController();
  String _filtro = '';
  String? _mesSeleccionado;
  bool _mostrarSinGuiaSiempre = true;
  String _ultimaHuellaNotificada = '';
  bool _editando = true;
  bool _guardando = false;
  static const int _limiteHistorico = 400;
  static const int _limiteMes = 250;
  static const int _limitePendientes = 200;

  CollectionReference<Map<String, dynamic>> get _itemsRef =>
      FirebaseFirestore.instance
          .collection('guias')
          .doc('mkp')
          .collection('items');

  String _docIdRegistro(Map<String, dynamic> reg) {
    final docId = (reg['_docId'] ?? '').toString();
    if (docId.isNotEmpty) return docId;
    return '${reg['devolucion'] ?? ''}_${reg['fecha'] ?? ''}';
  }

  Map<String, String> _rangoMes(String key) {
    final partes = key.split('-');
    final year = int.tryParse(partes.first);
    final month = partes.length > 1 ? int.tryParse(partes[1]) : null;
    if (year == null || month == null || month < 1 || month > 12) {
      final actual = DateTime.now();
      final inicio = DateTime(actual.year, actual.month);
      final fin = DateTime(actual.year, actual.month + 1);
      return {
        'inicio': inicio.toIso8601String(),
        'fin': fin.toIso8601String(),
      };
    }
    final inicio = DateTime(year, month);
    final fin = month == 12 ? DateTime(year + 1, 1) : DateTime(year, month + 1);
    return {
      'inicio': inicio.toIso8601String(),
      'fin': fin.toIso8601String(),
    };
  }

  List<Map<String, dynamic>> _mapSnapshot(
      QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['_docId'] = d.id;
      return data;
    }).toList();
  }

  List<Map<String, dynamic>> _mergeRegistros(
    List<Map<String, dynamic>> principales,
    List<Map<String, dynamic>> secundarios,
  ) {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final item in [...principales, ...secundarios]) {
      final key = _docIdRegistro(item);
      if (seen.add(key)) merged.add(item);
    }
    merged.sort((a, b) =>
        (b['fecha'] ?? '').toString().compareTo((a['fecha'] ?? '').toString()));
    return merged;
  }

  Stream<List<Map<String, dynamic>>> _streamConsultaActual() {
    final mes = _mesSeleccionado ?? _keyMesActual();
    if (mes == 'all') {
      return _itemsRef
          .orderBy('fecha', descending: true)
          .limit(_limiteHistorico)
          .snapshots()
          .map((snap) {
        final registros = _mapSnapshot(snap);
        _programarNotificacionSiCambio(
            List<Map<String, dynamic>>.from(registros));
        return registros;
      });
    }

    final rango = _rangoMes(mes);
    final mesStream = _itemsRef
        .where('fecha', isGreaterThanOrEqualTo: rango['inicio'])
        .where('fecha', isLessThan: rango['fin'])
        .orderBy('fecha', descending: true)
        .limit(_limiteMes)
        .snapshots();

    if (!_mostrarSinGuiaSiempre) {
      return mesStream.map((snap) {
        final registros = _mapSnapshot(snap);
        _programarNotificacionSiCambio(
            List<Map<String, dynamic>>.from(registros));
        return registros;
      });
    }

    final pendientesStream = _itemsRef
        .where('guia', isEqualTo: '')
        .limit(_limitePendientes)
        .snapshots();

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subMes;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subPendientes;
    List<Map<String, dynamic>> ultimosMes = [];
    List<Map<String, dynamic>> ultimosPendientes = [];

    void emitir() {
      final merged = _mergeRegistros(ultimosMes, ultimosPendientes);
      _programarNotificacionSiCambio(List<Map<String, dynamic>>.from(merged));
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        subMes = mesStream.listen((snap) {
          ultimosMes = _mapSnapshot(snap);
          emitir();
        }, onError: controller.addError);
        subPendientes = pendientesStream.listen((snap) {
          ultimosPendientes = _mapSnapshot(snap);
          emitir();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await subMes?.cancel();
        await subPendientes?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  void initState() {
    _mesSeleccionado = _keyMesActual();
    _busquedaController.addListener(() {
      setState(() {
        _filtro = _busquedaController.text.trim().toLowerCase();
      });
    });
    super.initState();
  }

  String _keyMesActual() {
    final ahora = DateTime.now();
    return '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';
  }

  List<String> _mesesParaSelector() {
    final ahora = DateTime.now();
    final meses = <String>[];
    for (var i = 0; i < 12; i++) {
      final fecha = DateTime(ahora.year, ahora.month - i);
      meses.add('${fecha.year}-${fecha.month.toString().padLeft(2, '0')}');
    }
    if (_mesSeleccionado != null &&
        _mesSeleccionado != 'all' &&
        !meses.contains(_mesSeleccionado)) {
      meses.insert(0, _mesSeleccionado!);
    }
    return meses;
  }

  String _etiquetaMes(String key) {
    final partes = key.split('-');
    if (partes.length != 2) return key;
    final y = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (y == null || m == null || m < 1 || m > 12) return key;
    const nombres = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${nombres[m - 1]} $y';
  }

  List<Map<String, dynamic>> _filtrarRegistros(
      List<Map<String, dynamic>> registros) {
    Iterable<Map<String, dynamic>> lista = registros;

    if (_filtro.isNotEmpty) {
      lista = lista.where((r) {
        final dev = (r['devolucion'] ?? '').toString().toLowerCase();
        final devMkp = (r['devolucion_mkp'] ?? '').toString().toLowerCase();
        final guia = (r['guia'] ?? '').toString().toLowerCase();
        final fecha = (r['fecha'] ?? '').toString().toLowerCase();
        return dev.contains(_filtro) ||
            devMkp.contains(_filtro) ||
            guia.contains(_filtro) ||
            fecha.contains(_filtro);
      });
    }

    return lista.toList();
  }

  List<Map<String, dynamic>> _registrosVisibles(
      List<Map<String, dynamic>> registrosFiltrados) {
    if (_filtro.isNotEmpty) return registrosFiltrados;

    final pendientes = registrosFiltrados
        .where((r) =>
            (r['devolucion'] ?? '').toString().isNotEmpty &&
            (r['guia'] ?? '').toString().trim().isEmpty)
        .take(15)
        .toList();

    final usados = pendientes
        .map((r) => '${r['devolucion'] ?? ''}_${r['fecha'] ?? ''}')
        .toSet();

    final recientes = registrosFiltrados
        .where(
            (r) => usados.add('${r['devolucion'] ?? ''}_${r['fecha'] ?? ''}'))
        .take(20)
        .toList();

    return [...pendientes, ...recientes];
  }

  String _formatearFecha(dynamic valor) {
    final texto = (valor ?? '').toString();
    if (texto.isEmpty) return 'Sin fecha';
    if (texto.length >= 19) {
      return texto.replaceFirst('T', ' ').substring(0, 19);
    }
    return texto.replaceFirst('T', ' ');
  }

  Widget _buildMetricCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            foregroundColor: color,
            child: Icon(icono),
          ),
          const SizedBox(height: 14),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDevolucion(
      List<Map<String, dynamic>> registros, Map<String, dynamic> reg) {
    final key = _rowKey(reg);
    if (!_devolucionControllers.containsKey(key)) {
      _devolucionControllers[key] =
          TextEditingController(text: reg['devolucion'] ?? '');
    } else {
      final ctrl = _devolucionControllers[key]!;
      if (ctrl.text != (reg['devolucion'] ?? '')) {
        ctrl.text = reg['devolucion'] ?? '';
      }
    }

    return TextField(
      controller: _devolucionControllers[key],
      decoration: InputDecoration(
        labelText: 'Devolución',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onEditingComplete: () {
        _actualizarCampoPorClave(
          registros,
          reg,
          'devolucion',
          _devolucionControllers[key]?.text ?? '',
        );
        FocusScope.of(context).unfocus();
      },
    );
  }

  Widget _buildEditableGuia(
      List<Map<String, dynamic>> registros, Map<String, dynamic> reg) {
    final key = _rowKey(reg);
    if (!_guiaControllers.containsKey(key)) {
      _guiaControllers[key] = TextEditingController(text: reg['guia'] ?? '');
    } else {
      final ctrl = _guiaControllers[key]!;
      if (ctrl.text != (reg['guia'] ?? '')) {
        ctrl.text = reg['guia'] ?? '';
      }
    }
    if (!_guiaFocusNodes.containsKey(key)) {
      _guiaFocusNodes[key] = FocusNode();
    }

    final ctrl = _guiaControllers[key]!;

    return TextField(
      controller: ctrl,
      focusNode: _guiaFocusNodes[key],
      decoration: InputDecoration(
        labelText: 'Guía',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onEditingComplete: () {
        _actualizarCampoPorClave(registros, reg, 'guia', ctrl.text);
        FocusScope.of(context).unfocus();
      },
    );
  }

  Widget _buildRegistroCard(
      List<Map<String, dynamic>> registros, Map<String, dynamic> reg) {
    final bloqueado = reg['bloqueado'] == true;
    final guia = (reg['guia'] ?? '').toString().trim();
    final pendiente = guia.isEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (reg['devolucion'] ?? '').toString().isEmpty
                      ? 'Nueva devolución'
                      : 'Devolución ${reg['devolucion']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pendiente
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pendiente ? 'Pendiente' : 'Con guía',
                  style: TextStyle(
                    color: pendiente
                        ? const Color(0xFF92400E)
                        : const Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatearFecha(reg['fecha']),
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: bloqueado
                    ? SelectableText(
                        (reg['devolucion'] ?? '').toString(),
                        style: const TextStyle(fontSize: 16),
                      )
                    : _buildEditableDevolucion(registros, reg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: bloqueado
                    ? SelectableText(
                        (reg['guia'] ?? '').toString(),
                        style: const TextStyle(fontSize: 16),
                      )
                    : _buildEditableGuia(registros, reg),
              ),
              if (bloqueado) ...[
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await _itemsRef.add({
                      'devolucion': reg['devolucion'],
                      'guia': '',
                      'fecha': DateTime.now().toIso8601String(),
                      'bloqueado': false,
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Movimiento'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _programarNotificacionSiCambio(List<Map<String, dynamic>> registros) {
    final huella = registros
        .map((r) =>
            '${r['devolucion'] ?? ''}|${r['guia'] ?? ''}|${r['fecha'] ?? ''}')
        .join('||');
    if (huella == _ultimaHuellaNotificada) return;
    _ultimaHuellaNotificada = huella;
    _notificacionDebounce?.cancel();
    _notificacionDebounce = Timer(const Duration(milliseconds: 700), () {
      _notificarDevolucionesSinGuia(registros);
    });
  }

  void _agregarFila(List<Map<String, dynamic>> registros) async {
    final ahora = DateTime.now().toIso8601String();
    await _itemsRef.add({
      'devolucion': '',
      'guia': '',
      'fecha': ahora,
      'bloqueado': false,
    });
  }

  Future<void> _sincronizarDocLegadoDesdeSubcoleccion() async {
    final snap = await _itemsRef.get();
    final items = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data.remove('_docId');
      return data;
    }).toList()
      ..sort((a, b) => (b['fecha'] ?? '')
          .toString()
          .compareTo((a['fecha'] ?? '').toString()));
    await guardarDatosFirestoreYCache('guias', 'mkp', {'items': items});
  }

  Future<void> _guardar(List<Map<String, dynamic>> registros) async {
    setState(() => _guardando = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final reg in registros) {
        final docId = _docIdRegistro(reg);
        final completo = (reg['devolucion'] ?? '').toString().isNotEmpty &&
            (reg['guia'] ?? '').toString().isNotEmpty &&
            (reg['fecha'] ?? '').toString().isNotEmpty;
        final item = Map<String, dynamic>.from(reg)
          ..remove('_docId')
          ..['bloqueado'] = completo;
        batch.set(_itemsRef.doc(docId), item, SetOptions(merge: true));
      }
      await batch.commit();
      await _sincronizarDocLegadoDesdeSubcoleccion();

      setState(() {
        _guardando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registros guardados.'),
          backgroundColor: Color(0xFF2D6A4F),
        ),
      );
    } catch (e) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _actualizarCampoPorClave(List<Map<String, dynamic>> registros,
      Map<String, dynamic> reg, String campo, String valor) async {
    final docId = _docIdRegistro(reg);
    final actualizado = Map<String, dynamic>.from(reg)..[campo] = valor;
    if (campo == 'guia' && valor.trim().isNotEmpty) {
      actualizado['fecha'] = DateTime.now().toIso8601String();
    }
    final completo = (actualizado['devolucion'] ?? '').toString().isNotEmpty &&
        (actualizado['guia'] ?? '').toString().isNotEmpty &&
        (actualizado['fecha'] ?? '').toString().isNotEmpty;
    actualizado['bloqueado'] = completo;
    actualizado.remove('_docId');
    await _itemsRef.doc(docId).set(actualizado, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _streamConsultaActual(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final registros = snapshot.data ?? [];
        final registrosFiltrados = _filtrarRegistros(registros);
        final registrosVisibles = _registrosVisibles(registrosFiltrados);
        final mesesSelector = _mesesParaSelector();
        final int devolucionesSinGuia = registros
            .where((r) =>
                (r['devolucion'] ?? '').toString().isNotEmpty &&
                (r['guia'] ?? '').toString().isEmpty)
            .length;
        final int devolucionesConGuia = registros
            .where((r) => (r['guia'] ?? '').toString().trim().isNotEmpty)
            .length;
        final int urgentes = registros.where((r) {
          if ((r['devolucion'] ?? '').toString().isEmpty ||
              (r['guia'] ?? '').toString().isNotEmpty) {
            return false;
          }
          final fecha = DateTime.tryParse((r['fecha'] ?? '').toString());
          if (fecha == null) return false;
          return DateTime.now().difference(fecha).inHours >= 24;
        }).length;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    const Icon(Icons.assignment,
                        color: Color(0xFF2D6A4F), size: 30),
                    if (devolucionesSinGuia > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            devolucionesSinGuia.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                const Text('Registro de Guías MKP'),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 2,
            iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
            titleTextStyle: const TextStyle(
              color: Color(0xFF2D6A4F),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF2D6A4F)),
                tooltip: 'Exportar a Excel',
                onPressed: () => _exportarAExcel(registrosFiltrados),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 360,
                              child: TextField(
                                controller: _busquedaController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Buscar por devolución, guía o fecha...',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 250,
                              child: DropdownButtonFormField<String>(
                                value: _mesSeleccionado ?? _keyMesActual(),
                                decoration: InputDecoration(
                                  labelText: 'Mes',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: [
                                  ...mesesSelector.map(
                                    (key) => DropdownMenuItem<String>(
                                      value: key,
                                      child: Text(_etiquetaMes(key)),
                                    ),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'all',
                                    child: Text('Histórico completo'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _mesSeleccionado = value);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: CheckboxListTile(
                                value: _mostrarSinGuiaSiempre,
                                onChanged: (v) => setState(
                                    () => _mostrarSinGuiaSiempre = v ?? true),
                                title: const Text('Incluir pendientes'),
                                tileColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _agregarFila(registros),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar fila'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _editando && !_guardando
                                  ? () => _guardar(registros)
                                  : null,
                              icon: _guardando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Guardar'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: _sincronizando
                                  ? null
                                  : () => _sincronizarDevoluciones(
                                      context, registros),
                              tooltip: 'Sincronizar devoluciones',
                              icon: _sincronizando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _buildMetricCard(
                              titulo: 'Registros cargados',
                              valor: registros.length.toString(),
                              icono: Icons.inventory_2_outlined,
                              color: const Color(0xFF2563EB),
                            ),
                            _buildMetricCard(
                              titulo: 'Pendientes sin guía',
                              valor: devolucionesSinGuia.toString(),
                              icono: Icons.warning_amber_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                            _buildMetricCard(
                              titulo: 'Registros con guía',
                              valor: devolucionesConGuia.toString(),
                              icono: Icons.check_circle_outline,
                              color: const Color(0xFF16A34A),
                            ),
                            _buildMetricCard(
                              titulo: 'Pendientes > 24h',
                              valor: urgentes.toString(),
                              icono: Icons.schedule,
                              color: const Color(0xFFDC2626),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Text(
                              _filtro.isEmpty
                                  ? 'Vista ejecutiva'
                                  : 'Resultados de búsqueda',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _filtro.isEmpty
                                  ? 'Mostrando ${registrosVisibles.length} registros prioritarios de ${registrosFiltrados.length}'
                                  : '${registrosFiltrados.length} coincidencias encontradas',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: registrosVisibles.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'No hay resultados para los filtros actuales.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: registrosVisibles.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final reg = registrosVisibles[index];
                                    return _buildRegistroCard(registros, reg);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
