import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/user_control_page.dart';
import '../pages/hoja_de_ruta_page.dart';
import '../pages/hoja_de_xd_page.dart';
import '../pages/hoja_de_xd_historial_page.dart';
import '../pages/carta_porte_page.dart';
import '../pages/historial_carta_porte_page.dart';
import '../pages/plantilla_ejecutiva_page.dart';
import '../pages/devcan_page.dart';
import '../pages/historial_entregas_devcan_page.dart';
import '../pages/recogidos/recogidos_page.dart';
import '../pages/recogidos/historial_entregas_recogidos_page.dart';

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
  int _selectedIndex = 0;
  bool _menuExpandido = true;
  late List<String> _paginas;

  // Mapeo de nombre de página a Widget real
  late final Map<String, Widget> _pageWidgets = {
    'Control de usuarios': UserControlPageBody(),
    'Hoja de ruta': HojaDeRutaPage(),
    'Hoja de XD': HojaDeXDPage(usuario: widget.usuario),
    'Historial Hoja de XD': HojaDeXDHistorialPage(),
    'Carta Porte': CartaPorteTable(),
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
    _paginas = widget.paginasPermitidas;
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
                  onPressed: () {},
                ),
                if (widget.notificaciones > 0)
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
                        '${widget.notificaciones}',
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
                        return ListTile(
                          leading:
                              const Icon(Icons.circle, color: Colors.white),
                          title: _menuExpandido
                              ? Text(
                                  _paginas[index],
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                          selected: _selectedIndex == index,
                          selectedTileColor: Colors.green.shade700,
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
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
