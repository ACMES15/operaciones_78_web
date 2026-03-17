// --- HOME PAGE CON MENÚ LATERAL ---
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'pages/user_control_page.dart';
import 'pages/login_page.dart';
import 'pages/hoja_de_xd_page.dart';
import 'pages/hoja_de_ruta_page.dart';
import 'pages/hoja_de_xd_historial_page.dart';
import 'pages/carta_porte_table.dart';
import 'pages/historial_carta_porte_page.dart';
import 'pages/plantilla_ejecutiva_page.dart';
import 'pages/devcan_page.dart';
import 'pages/historial_entregas_devcan_page.dart';
import 'pages/recogidos/recogidos_page.dart';
import 'pages/recogidos/historial_entregas_recogidos_page.dart';
import 'pages/user_control_page.dart';

class HomePage extends StatefulWidget {
  final String usuario;
  const HomePage({required this.usuario, super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Simulación de notificaciones (puedes conectar a Firebase o tu backend)
  late String _usuario;
  String _tipoUsuario = '';
  List<String> _notificaciones = [];
  int get _notificacionesNoLeidas => _notificaciones.length;
  int _selectedIndex = 0;
  bool _menuExpandido = false;
  final List<String> _paginas = [
    'Control de usuarios',
    'Hoja de ruta',
    'Hoja de XD',
    'Historial Hoja de XD',
    'Carta Porte',
    'Historial Carta Porte',
    'Plantilla Ejecutiva',
    'DevCan',
    'Historial Entregas DevCan',
    'Recogidos',
    'Historial Entregas Recogidos',
  ];
  final List<IconData> _paginaIconos = [
    Icons.admin_panel_settings_outlined,
    Icons.map_outlined,
    Icons.description_outlined,
    Icons.history,
    Icons.note_alt_outlined,
    Icons.history_toggle_off,
    Icons.article_outlined,
    Icons.developer_mode,
    Icons.history_edu,
    Icons.shopping_bag_outlined,
    Icons.list_alt,
  ];
  final List<String> _paginaTooltips = [
    'Control de usuarios',
    'Hoja de ruta',
    'Hoja de XD',
    'Historial Hoja de XD',
    'Carta Porte',
    'Historial Carta Porte',
    'Plantilla Ejecutiva',
    'DevCan',
    'Historial Entregas DevCan',
    'Recogidos',
    'Historial Entregas Recogidos',
  ];
  List<Widget> get _pages => [
        UserControlPageBody(),
        HojaDeRutaPage(),
        HojaDeXDPage(usuario: widget.usuario),
        HojaDeXDHistorialPage(),
        CartaPorteTable(),
        HistorialCartaPortePage(),
        PlantillaEjecutivaPage(),
        DevCanPage(usuario: widget.usuario),
        HistorialEntregasDevCanPage(historial: const [], tipoUsuarioActual: ''),
        RecogidosPage(usuario: widget.usuario),
        HistorialEntregasRecogidosPage(
            historial: const [], tipoUsuarioActual: ''),
      ];
  // ...existing code...
  List<int> _paginasPermitidas = [];
  Map<String, Map<String, bool>> _permisosTipoUsuario = {};
  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
    _cargarTipoYPermisos();
    // Notificaciones
    FirebaseFirestore.instance
        .collection('notificaciones')
        .where('usuario', isEqualTo: _usuario)
        .limit(1)
        .snapshots()
        .listen((query) {
      if (query.docs.isNotEmpty &&
          query.docs.first.data().containsKey('items')) {
        setState(() {
          _notificaciones = List<String>.from(query.docs.first['items']);
        });
      } else {
        setState(() {
          _notificaciones = [];
        });
      }
    });
  }

  Future<void> _cargarTipoYPermisos() async {
    final usuarioDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc('usuarios_guardados')
        .get();
    if (usuarioDoc.exists && usuarioDoc.data() != null) {
      final usuariosMap = usuarioDoc.data() ?? {};
      final datos = usuariosMap[_usuario];
      if (datos != null && datos['rol'] != null) {
        _tipoUsuario = datos['rol'].toString();
      }
    }
    // Acceso total para SUPERADMIN acmes15
    if (_usuario == 'acmes15' ||
        _tipoUsuario == 'SUPERADMIN' ||
        _tipoUsuario == 'ADMIN') {
      _paginasPermitidas = List<int>.generate(_paginas.length, (i) => i);
      setState(() {});
      return;
    }
    final permisosDoc = await FirebaseFirestore.instance
        .collection('permisos_tipo_usuario')
        .doc('permisos_tipo_usuario')
        .get();
    if (permisosDoc.exists && permisosDoc.data() != null) {
      final permisosMap = permisosDoc.data() ?? {};
      _permisosTipoUsuario = Map<String, Map<String, bool>>.from(
        (permisosMap['permisos'] as Map<String, dynamic>).map(
          (tipo, pags) => MapEntry(
            tipo,
            (pags as Map<String, dynamic>)
                .map((pag, val) => MapEntry(pag, val == true)),
          ),
        ),
      );
      _paginasPermitidas = [];
      if (_permisosTipoUsuario.containsKey(_tipoUsuario)) {
        for (int i = 0; i < _paginas.length; i++) {
          final nombrePagina = _paginas[i];
          if (_permisosTipoUsuario[_tipoUsuario]?[nombrePagina] == true) {
            _paginasPermitidas.add(i);
          }
        }
      }
      if (_paginasPermitidas.isEmpty) _paginasPermitidas = [0];
      setState(() {});
    } else {
      // Si no existe documento de permisos, dar acceso mínimo (Control de usuarios)
      if (_paginasPermitidas.isEmpty) {
        _paginasPermitidas = [0];
        setState(() {});
      }
    }
  }
  // Si tienes notificaciones en Firebase, usa un StreamBuilder en el widget.

  // Para mostrar el usuario firmado, puedes recibirlo por constructor o variable global
  // Ejemplo: final String usuario;
  // Y en el constructor: HomePage({required this.usuario, super.key});

  String _fechaHoraActual() {
    final ahora = DateTime.now();
    return '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelType: _menuExpandido
                          ? NavigationRailLabelType.all
                          : NavigationRailLabelType.none,
                      backgroundColor: Colors.transparent,
                      selectedIconTheme:
                          const IconThemeData(color: Colors.white),
                      selectedLabelTextStyle:
                          const TextStyle(color: Colors.white),
                      unselectedIconTheme:
                          const IconThemeData(color: Colors.white70),
                      unselectedLabelTextStyle:
                          const TextStyle(color: Colors.white70),
                      destinations: [
                        for (final idx in _paginasPermitidas)
                          NavigationRailDestination(
                            icon: Tooltip(
                              message: _paginaTooltips[idx],
                              child: Icon(_paginaIconos[idx]),
                            ),
                            selectedIcon: Tooltip(
                              message: _paginaTooltips[idx],
                              child: Icon(_paginaIconos[idx]),
                            ),
                            label: Text(_paginas[idx]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF2D6A4F),
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                  child: Row(
                    children: [
                      Text(
                        'Operaciones 78',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(2, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Usuario, tipo y fecha/hora donde estaba la campana
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _usuario,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        offset: Offset(1, 1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_tipoUsuario.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade700,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _tipoUsuario,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _fechaHoraActual(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        offset: Offset(1, 1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Campana de notificaciones junto a cierre de sesión
                      Stack(
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
                                    title: const Text('Notificaciones'),
                                    content: SizedBox(
                                      width: 350,
                                      child: _notificaciones.isEmpty
                                          ? const Text('No hay notificaciones')
                                          : ListView.separated(
                                              shrinkWrap: true,
                                              itemCount: _notificaciones.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(),
                                              itemBuilder: (context, idx) =>
                                                  ListTile(
                                                leading: const Icon(
                                                    Icons.notifications_active,
                                                    color: Colors.teal),
                                                title:
                                                    Text(_notificaciones[idx]),
                                              ),
                                            ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Cerrar'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          if (_notificacionesNoLeidas > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  _notificacionesNoLeidas.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _paginasPermitidas.isNotEmpty
                      ? _pages[_paginasPermitidas[_selectedIndex]]
                      : const Center(child: Text('Sin permisos')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
