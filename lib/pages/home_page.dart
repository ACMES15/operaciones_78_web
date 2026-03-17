import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/user_control_page.dart';
import '../pages/hoja_de_ruta_page.dart';
import '../pages/hoja_de_xd_page.dart';
import '../pages/hoja_de_xd_historial_page.dart';
// import '../pages/carta_porte_page.dart';
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
  late final Stream<List<Map<String, dynamic>>> _notificacionesStream =
      FirebaseFirestore.instance
          .collection('notificaciones')
          .where('para', isEqualTo: widget.tipoUsuario)
          .where('leida', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList());

  // Mapeo de nombre de página a ícono y tooltip
  final Map<String, IconData> _pageIcons = const {
    'Bienvenida': Icons.home,
    'Control de usuarios': Icons.admin_panel_settings,
    'Hoja de ruta': Icons.alt_route,
    'Hoja de XD': Icons.description,
    'Historial Hoja de XD': Icons.history,
    'Carta Porte': Icons.local_shipping,
    'Historial Carta Porte': Icons.history,
    'Plantilla Ejecutiva': Icons.assignment_turned_in,
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
    'DevCan': DevCanPage(usuario: widget.usuario),
    'Historial Entregas DevCan': HistorialEntregasDevCanPage(
        historial: const [], tipoUsuarioActual: widget.tipoUsuario),
    'Recogidos': RecogidosPage(usuario: widget.usuario),
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
    final permitidas = widget.paginasPermitidas.toSet();
    final paginasOrdenadas = ordenFijo
        .where((p) => permitidas.contains(p) || p == 'Bienvenida')
        .toList();
    final extras = permitidas.difference(ordenFijo.toSet()).toList();
    _paginas = [...paginasOrdenadas, ...extras];
    // Cargar notificaciones pendientes al iniciar
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
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _notificacionesStream,
              builder: (context, snapshot) {
                final notificaciones = snapshot.data ?? [];
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications,
                          color: Colors.white, size: 28),
                      tooltip: 'Notificaciones',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(Icons.notifications_active,
                                      color: Color(0xFF2D6A4F)),
                                  const SizedBox(width: 8),
                                  const Text('Notificaciones'),
                                  const Spacer(),
                                  if (notificaciones.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        notificaciones.length.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              content: SizedBox(
                                width: 400,
                                child: notificaciones.isEmpty
                                    ? const Text(
                                        'No hay notificaciones nuevas.')
                                    : ListView(
                                        shrinkWrap: true,
                                        children:
                                            notificaciones.map<Widget>((notif) {
                                          final mensaje =
                                              notif['mensaje'] ?? '';
                                          final fecha = notif['fecha'] != null
                                              ? (notif['fecha'] is String
                                                  ? notif['fecha']
                                                  : (notif['fecha'] is DateTime
                                                      ? (notif['fecha']
                                                              as DateTime)
                                                          .toString()
                                                          .substring(0, 16)
                                                      : (notif['fecha']
                                                              as dynamic)
                                                          .toDate()
                                                          .toString()
                                                          .substring(0, 16)))
                                              : '';
                                          final tipo = notif['tipo'] ?? '';
                                          final detalle =
                                              notif['detalle'] ?? '';
                                          final isReseteo = tipo
                                                  .toLowerCase()
                                                  .contains('reseteo') ||
                                              mensaje
                                                  .toLowerCase()
                                                  .contains('reseteo');
                                          return Card(
                                            color: Colors.white,
                                            elevation: 3,
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 7, horizontal: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: const BorderSide(
                                                  color: Color(0xFF2D6A4F),
                                                  width: 1.2),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0,
                                                      horizontal: 4.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.notifications,
                                                          color: Color(
                                                              0xFF2D6A4F)),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          mensaje,
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  if (detalle.isNotEmpty)
                                                    Text('Detalle: $detalle',
                                                        style: const TextStyle(
                                                            fontSize: 14)),
                                                  Text('Tipo: $tipo',
                                                      style: const TextStyle(
                                                          fontSize: 13)),
                                                  Text('Fecha: $fecha',
                                                      style: const TextStyle(
                                                          fontSize: 13)),
                                                  const SizedBox(height: 8),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: isReseteo
                                                        ? ElevatedButton.icon(
                                                            icon: const Icon(
                                                                Icons
                                                                    .restart_alt,
                                                                size: 18),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.blue
                                                                      .shade700,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          6),
                                                              textStyle:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                            ),
                                                            label: const Text(
                                                                'Atender reseteo'),
                                                            onPressed:
                                                                () async {
                                                              await FirebaseFirestore
                                                                  .instance
                                                                  .collection(
                                                                      'notificaciones')
                                                                  .doc(notif[
                                                                      'id'])
                                                                  .update({
                                                                'leida': true
                                                              });
                                                            },
                                                          )
                                                        : ElevatedButton.icon(
                                                            icon: const Icon(
                                                                Icons
                                                                    .check_circle,
                                                                size: 18),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.green
                                                                      .shade700,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          6),
                                                              textStyle:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                            ),
                                                            label: const Text(
                                                                'Atendido'),
                                                            onPressed:
                                                                () async {
                                                              await FirebaseFirestore
                                                                  .instance
                                                                  .collection(
                                                                      'notificaciones')
                                                                  .doc(notif[
                                                                      'id'])
                                                                  .update({
                                                                'leida': true
                                                              });
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    if (notificaciones.isNotEmpty)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            notificaciones.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
// ...el StreamBuilder de notificaciones ya cierra correctamente aquí...
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () => widget.onLogout(),
          ),
        ],
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
