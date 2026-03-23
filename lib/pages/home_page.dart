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
import '../pages/dev_mbodas_page.dart';
import '../pages/bienvenida_page.dart';
import '../pages/historial_entregas_devcan_page.dart';
import '../pages/recogidos/recogidos_page.dart';
import '../pages/recogidos/historial_entregas_recogidos_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/entregas_cdr_page.dart';
import '../pages/historial_firmadas_cdr_page.dart';
import '../pages/historial_entregas_dev_mbodas_page.dart';
import '../pages/dev_xd_page.dart';
import '../pages/historial_entregas_xd_page.dart';
import '../pages/dev_cyc_page.dart';
import '../pages/entregas_cyc_page.dart';
import '../pages/historial_entregas_cyc_page.dart';
import '../pages/historial_tf_retornos_page.dart';
import 'paqueteria_externa_page.dart';
import 'historial_paqueteria_externa_page.dart';
import 'mensajes_page.dart';
import '../pages/transferencias_retornos_page.dart';
import '../pages/consulta_global_page.dart';
import '../utils/mensajes_service.dart';
import 'notificaciones_page.dart';

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
    'Mensajes': Icons.message,
    'Control de usuarios': Icons.admin_panel_settings,
    'Hoja de ruta': Icons.alt_route,
    'Hoja de XD': Icons.description,
    'Historial Hoja de XD': Icons.history,
    'Carta Porte': Icons.local_shipping,
    'Historial Carta Porte': Icons.history,
    'Plantilla Ejecutiva': Icons.assignment_turned_in,
    'DevCan': Icons.bolt,
    'Dev Mbodas': Icons.cake,
    'Historial Entregas Dev Mbodas': Icons.cake,
    'Historial Entregas DevCan': Icons.history_toggle_off,
    'Dev XD': Icons.extension,
    'Historial Entregas XD': Icons.history,
    'Dev CyC': Icons.assignment,
    // 'Entregas CyC': Icons.assignment_turned_in, // No debe estar en menú
    'Recogidos': Icons.shopping_bag_outlined,
    'Historial Entregas Recogidos': Icons.list_alt,
    'Historial Entregas CyC': Icons.history, // Nuevo ícono para historial CyC
    // 'Entregas XD': Icons.extension, // Eliminado del menú
    'Entregas CDR': Icons.inventory_2,
    'Historial De Entregas CDR': Icons.history_edu,
    'Paquetería Externa': Icons.local_shipping,
    'Historial Paquetería Externa': Icons.history,
    'Transferencias y Retornos': Icons.swap_horiz,
    'Historial TF o Retornos': Icons.history,
    'Consulta Global': Icons.public,
  };
  int _selectedIndex = 0;
  bool _menuExpandido = true;
  late List<String> _paginas;

  // Mapeo de nombre de página a Widget real
  late final Map<String, Widget> _pageWidgets = {
    'Bienvenida': BienvenidaPage(
        usuario: widget.usuario, tipoUsuario: widget.tipoUsuario),
    'Mensajes':
        MensajesPage(usuario: widget.usuario, tipoUsuario: widget.tipoUsuario),
    'Control de usuarios': UserControlPageBody(),
    'Hoja de ruta': HojaDeRutaPage(),
    'Hoja de XD': HojaDeXDPage(usuario: widget.usuario),
    'Historial Hoja de XD': HojaDeXDHistorialPage(),
    'Carta Porte': real_carta_porte.CartaPorteTable(), // Widget real con alias
    'Historial Carta Porte': HistorialCartaPortePage(),
    'Plantilla Ejecutiva': PlantillaEjecutivaPage(),
    'DevCan': DevCanPage(usuario: widget.usuario),
    'Dev Mbodas': DevMbodasPage(usuario: widget.usuario),
    'Dev XD': DevXdPage(usuario: widget.usuario),
    'Historial Entregas XD': HistorialEntregasXdPage(
        historial: const [], tipoUsuarioActual: widget.tipoUsuario),
    'Dev CyC': DevCycPage(usuario: widget.usuario),
    'Entregas CyC':
        EntregasCycPage(usuario: widget.usuario), // Solo navegación interna
    'Historial Entregas CyC': HistorialEntregasCycPage(usuario: widget.usuario),
    'Historial Entregas DevCan': HistorialEntregasDevCanPage(
        historial: const [], tipoUsuarioActual: widget.tipoUsuario),
    'Recogidos': RecogidosPage(usuario: widget.usuario),
    'Historial Entregas Recogidos': HistorialEntregasRecogidosPage(
        historial: const [], tipoUsuarioActual: widget.tipoUsuario),
    'Historial Entregas Dev Mbodas': HistorialEntregasDevMbodasPage(
        historial: const [], tipoUsuarioActual: widget.tipoUsuario),
    'Entregas CDR': EntregasCdrPage(usuario: widget.usuario),
    'Historial De Entregas CDR': HistorialFirmadasCdrPage(),
    'Paquetería Externa': PaqueteriaExternaPage(usuario: widget.usuario),
    'Historial Paquetería Externa': HistorialPaqueteriaExternaPage(
        usuario: widget.usuario, tipoUsuarioActual: widget.tipoUsuario),
    'Transferencias y Retornos':
        TransferenciasRetornosPage(usuario: widget.usuario),
    'Historial TF o Retornos': HistorialTfRetornosPage(usuario: widget.usuario),
    'Consulta Global': ConsultaGlobalPage(),
  };

  @override
  void initState() {
    super.initState();
    // Orden fijo solicitado
    final permitidas = widget.paginasPermitidas.toSet();
    // Eliminar "Entregas XD" y "Entregas CyC" si están en permitidas
    permitidas.remove('Entregas XD');
    permitidas.remove('Entregas CyC');
    final ordenFijo = [
      'Bienvenida',
      'Mensajes',
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
      'Entregas CDR',
      'Historial De Entregas CDR',
      'Dev Mbodas',
      'Historial Entregas Dev Mbodas',
      'Dev XD',
      'Historial Entregas XD',
      'Dev CyC',
      'Historial Entregas CyC', // Solo historial CyC en menú
      'Paquetería Externa',
      'Historial Paquetería Externa',
      'Transferencias y Retornos',
      'Historial TF o Retornos',
      'Consulta Global',
      'Plantilla Ejecutiva',
    ];
    // ...existing code...
    final paginasOrdenadas = ordenFijo
        .where((p) =>
            permitidas.contains(p) || p == 'Bienvenida' || p == 'Mensajes')
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
            const SizedBox(width: 10),
            // Usuario, Tipo y Fecha/Hora
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Usuario: ${widget.usuario}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text('Tipo: ${widget.tipoUsuario}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                _FechaHoraWidget(),
              ],
            ),
          ],
        ),
        actions: [
          // Campana de notificaciones
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
                                  ? const Text('No hay notificaciones nuevas.')
                                  : ListView(
                                      shrinkWrap: true,
                                      children:
                                          notificaciones.map<Widget>((notif) {
                                        final mensaje = notif['mensaje'] ?? '';
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
                                        final detalle = notif['detalle'] ?? '';
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
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8.0, horizontal: 4.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.notifications,
                                                        color:
                                                            Color(0xFF2D6A4F)),
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
                                                              Icons.restart_alt,
                                                              size: 18),
                                                          style: ElevatedButton
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
                                                          onPressed: () async {
                                                            // Extraer usuario del mensaje o detalle
                                                            String? usuario;
                                                            if (notif[
                                                                    'usuario'] !=
                                                                null) {
                                                              usuario = notif[
                                                                  'usuario'];
                                                            } else {
                                                              final msg =
                                                                  (notif['mensaje'] ??
                                                                          '')
                                                                      .toString();
                                                              final match = RegExp(
                                                                      r"'([^']+)' solicita reseteo")
                                                                  .firstMatch(
                                                                      msg);
                                                              if (match !=
                                                                  null) {
                                                                usuario = match
                                                                    .group(1);
                                                              }
                                                            }
                                                            if (usuario !=
                                                                    null &&
                                                                usuario
                                                                    .isNotEmpty) {
                                                              final usuarioNormalizado =
                                                                  usuario
                                                                      .trim()
                                                                      .toLowerCase();
                                                              try {
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'usuarios')
                                                                    .doc(
                                                                        usuarioNormalizado)
                                                                    .update({
                                                                  'password':
                                                                      usuarioNormalizado
                                                                });
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'notificaciones')
                                                                    .doc(notif[
                                                                        'id'])
                                                                    .update({
                                                                  'leida': true
                                                                });
                                                                if (mounted) {
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                        content:
                                                                            Text('Contraseña de $usuario reseteada.')),
                                                                  );
                                                                }
                                                              } catch (e) {
                                                                ScaffoldMessenger.of(
                                                                        context)
                                                                    .showSnackBar(
                                                                  SnackBar(
                                                                      content: Text(
                                                                          'Error al resetear: $e'),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .red),
                                                                );
                                                              }
                                                            } else {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        'No se pudo identificar el usuario a resetear.')),
                                                              );
                                                            }
                                                          },
                                                        )
                                                      : ElevatedButton.icon(
                                                          icon: const Icon(
                                                              Icons
                                                                  .check_circle,
                                                              size: 18),
                                                          style: ElevatedButton
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
                                                          onPressed: () async {
                                                            await FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'notificaciones')
                                                                .doc(
                                                                    notif['id'])
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
                        Widget leadingIcon = Icon(
                          icon,
                          color: _selectedIndex == index
                              ? Colors.amber
                              : Colors.white,
                        );
                        // Badge rojo para mensajes
                        if (pageName == 'Mensajes') {
                          leadingIcon = StreamBuilder<int>(
                            stream: MensajesService.mensajesNoLeidosStream(
                                widget.usuario, widget.tipoUsuario),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    icon,
                                    color: _selectedIndex == index
                                        ? Colors.amber
                                        : Colors.white,
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 1),
                                        ),
                                        child: Text(
                                          count.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        }
                        return Tooltip(
                          message: pageName,
                          child: ListTile(
                            leading: leadingIcon,
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
