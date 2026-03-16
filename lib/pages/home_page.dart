import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/user_control_page.dart';
import '../pages/hoja_de_ruta_page.dart';
import '../pages/hoja_de_xd_page.dart';
import '../pages/hoja_de_xd_historial_page.dart';
import '../pages/carta_porte_page.dart';
import '../pages/carta_porte_table.dart' as real_carta_porte;
import '../pages/historial_carta_porte_page.dart';
import '../pages/plantilla_ejecutiva_page.dart';
import '../pages/devcan_page.dart';
import '../pages/bienvenida_page.dart';
import '../pages/historial_entregas_devcan_page.dart';
import '../pages/recogidos/recogidos_page.dart';
import '../pages/recogidos/historial_entregas_recogidos_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  final String usuario;
  final String tipoUsuario;
  final List<String> paginasPermitidas;
  final VoidCallback onLogout;
  final int notificaciones;
  const HomePage({
    Key? key,
    required this.usuario,
    required this.tipoUsuario,
    required this.paginasPermitidas,
    required this.onLogout,
    this.notificaciones = 0,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Notificaciones
  List<Map<String, dynamic>> _notificaciones = [];

  Future<void> _cargarNotificaciones() async {
    final query = await FirebaseFirestore.instance
        .collection('notificaciones')
        .where('para', isEqualTo: widget.tipoUsuario)
        .where('leida', isEqualTo: false)
        .get();
    setState(() {
      _notificaciones = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Mapeo de nombre de página a ícono y tooltip
  final Map<String, IconData> _pageIcons = const {
    'Bienvenida': Icons.home,
    'Control de usuarios': Icons.admin_panel_settings,
    'Hoja de ruta': Icons.map_outlined,
    'Hoja de XD': Icons.description_outlined,
    'Historial Hoja de XD': Icons.history_edu,
    'Carta Porte': Icons.local_shipping,
    'Historial Carta Porte': Icons.history,
    'Plantilla Ejecutiva': Icons.assignment,
    'DevCan': Icons.bolt,
    'Historial Entregas DevCan': Icons.history_toggle_off,
    'Recogidos': Icons.shopping_bag_outlined,
    'Historial Entregas Recogidos': Icons.list_alt,
  };
  int _selectedIndex = 0;
  bool _menuExpandido = true;
  late List<String> _paginas;

  // Mapeo de nombre de página a Widget real
  late final Map<String, Widget> _pageWidgets = {
    'Bienvenida': BienvenidaPage(
        usuario: widget.usuario, tipoUsuario: widget.tipoUsuario),
    'Control de usuarios': UserControlPageBody(),
    'Hoja de ruta': HojaDeRutaPage(),
    'Hoja de XD': HojaDeXDPage(usuario: widget.usuario),
    'Historial Hoja de XD': HojaDeXDHistorialPage(),
    'Carta Porte': real_carta_porte.CartaPorteTable(), // Widget real con alias
    'Historial Carta Porte': HistorialCartaPortePage(),
    'Plantilla Ejecutiva': PlantillaEjecutivaPage(),
    'DevCan': DevCanPage(),
    'Historial Entregas DevCan': HistorialEntregasDevCanPage(
        historial: const [], tipoUsuarioActual: widget.tipoUsuario),
    'Recogidos': RecogidosPage(),
    'Historial Entregas Recogidos': HistorialEntregasRecogidosPage(
        historial: const [], tipoUsuarioActual: widget.tipoUsuario),
  };

  @override
  void initState() {
    super.initState();
    // Orden fijo solicitado
    final ordenFijo = [
      'Bienvenida',
      'Control de usuarios',
      'Carta Porte',
      'Historial Carta Porte',
      'Hoja de ruta',
      'Hoja de XD',
      'Historial Hoja de XD',
      'DevCan',
      'Historial Entregas DevCan',
      'Recogidos',
      'Historial Entregas Recogidos',
      'Plantilla Ejecutiva',
    ];
    // Siempre mostrar Bienvenida, luego las permitidas en el orden solicitado, luego las extras
    final permitidas = widget.paginasPermitidas.toSet();
    final paginasOrdenadas = ordenFijo
        .where((p) => permitidas.contains(p) || p == 'Bienvenida')
        .toList();
    final extras = permitidas.difference(ordenFijo.toSet()).toList();
    _paginas = [...paginasOrdenadas, ...extras];

    // Debug: Mostrar páginas permitidas y claves del mapa
    print('[DEBUG][HomePage] Páginas permitidas recibidas:');
    for (final p in _paginas) {
      print('  - "$p"');
    }
    print('[DEBUG][HomePage] Claves en _pageWidgets:');
    for (final k in _pageWidgets.keys) {
      print('  - "$k"');
    }
    for (final p in _paginas) {
      if (!_pageWidgets.containsKey(p)) {
        print('[ADVERTENCIA] No hay widget asociado para la página: "$p"');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.account_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Usuario: ${widget.usuario}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 16),
            Text(
              'Tipo: ${widget.tipoUsuario}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 16),
            _FechaHoraWidget(),
            const Spacer(),
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  tooltip: 'Notificaciones',
                  onPressed: () async {
                    await _cargarNotificaciones();
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Notificaciones'),
                          content: SizedBox(
                            width: 400,
                            child: _notificaciones.isEmpty
                                ? const Text('No hay notificaciones nuevas.')
                                : ListView(
                                    shrinkWrap: true,
                                    children: _notificaciones.map((notif) {
                                      final tipo = notif['tipo'] ?? '';
                                      final detalle = notif['detalle'];
                                      return ListTile(
                                        leading: const Icon(Icons.info_outline),
                                        title: Text(notif['mensaje'] ?? ''),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (notif['fecha'] != null)
                                              Text(notif['fecha'].toString()),
                                            if (detalle != null &&
                                                detalle is Map)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Text(
                                                  detalle.entries
                                                      .map((e) =>
                                                          '${e.key}: ${e.value}')
                                                      .join('\n'),
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black87),
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: notif['leida'] == false
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (tipo == 'reset_password')
                                                    TextButton(
                                                      child: const Text(
                                                          'Resetear'),
                                                      onPressed: () async {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                              content: Text(
                                                                  'Funcionalidad de reseteo no implementada.')),
                                                        );
                                                      },
                                                    ),
                                                  if (tipo != 'reset_password')
                                                    TextButton(
                                                      child: const Text(
                                                          'Atendida'),
                                                      onPressed: () async {
                                                        if (notif['id'] !=
                                                            null) {
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'notificaciones')
                                                              .doc(notif['id'])
                                                              .update({
                                                            'leida': true
                                                          });
                                                          Navigator.pop(
                                                              context);
                                                          await _cargarNotificaciones();
                                                        }
                                                      },
                                                    ),
                                                ],
                                              )
                                            : const SizedBox.shrink(),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                if (_notificaciones.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '${_notificaciones.length}',
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
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Cerrar sesión',
              onPressed: widget.onLogout,
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _menuExpandido ? 180 : 60,
            child: Container(
              color: const Color(0xFF2D6A4F),
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                        _menuExpandido ? Icons.arrow_back_ios : Icons.menu,
                        color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _menuExpandido = !_menuExpandido;
                      });
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _paginas.length,
                      itemBuilder: (context, index) {
                        final pageName = _paginas[index];
                        final icon = _pageIcons[pageName] ?? Icons.circle;
                        return Tooltip(
                          message: pageName,
                          child: ListTile(
                            leading: Icon(
                              icon,
                              color: _selectedIndex == index
                                  ? Colors.amber
                                  : Colors.white,
                            ),
                            title: _menuExpandido
                                ? Text(
                                    pageName,
                                    style: TextStyle(
                                      color: _selectedIndex == index
                                          ? Colors.amber
                                          : Colors.white,
                                      fontWeight: _selectedIndex == index
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  )
                                : null,
                            selected: _selectedIndex == index,
                            selectedTileColor: Colors.green.shade700,
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _pageWidgets[_paginas[_selectedIndex]] ??
                const Center(child: Text('Página no encontrada')),
          ),
        ],
      ),
    );
  }
}

class _FechaHoraWidget extends StatefulWidget {
  @override
  State<_FechaHoraWidget> createState() => _FechaHoraWidgetState();
}

class _FechaHoraWidgetState extends State<_FechaHoraWidget> {
  late String _fechaHora;
  late final _timer =
      Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());

  @override
  void initState() {
    super.initState();
    _fechaHora = _formatear(DateTime.now());
    _timer.listen((date) {
      if (mounted) {
        setState(() {
          _fechaHora = _formatear(date);
        });
      }
    });
  }

  String _formatear(DateTime dt) {
    final fecha = DateFormat('dd/MM/yyyy').format(dt);
    final hora = DateFormat('HH:mm:ss').format(dt);
    return '$fecha $hora';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.access_time, color: Colors.white, size: 18),
        const SizedBox(width: 4),
        Text(_fechaHora,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
