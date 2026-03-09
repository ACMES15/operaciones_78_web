// --- HOME PAGE CON MENÚ LATERAL ---
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/user_control_page.dart';
import 'pages/user_permissions_page.dart';
import 'pages/login_page.dart';
import 'pages/hoja_de_xd_page.dart';

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
  final List<Widget> _pages = [
    UserControlPage(),
    UserPermissionsPage(),
    HojaDeXDPage(),
  ];
  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
    // Leer tipo de usuario desde Firestore (colección 'usuarios', campo 'usuario')
    FirebaseFirestore.instance
        .collection('usuarios')
        .where('usuario', isEqualTo: _usuario)
        .limit(1)
        .get()
        .then((query) {
      if (query.docs.isNotEmpty &&
          query.docs.first.data().containsKey('tipo')) {
        setState(() {
          _tipoUsuario = query.docs.first['tipo'].toString();
        });
      }
    });
    // Adaptar notificaciones por nombre de usuario
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
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people),
                          label: Text('Usuarios'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.lock_outline),
                          selectedIcon: Icon(Icons.lock),
                          label: Text('Permisos'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.description_outlined),
                          selectedIcon: Icon(Icons.description),
                          label: Text('Hoja de XD'),
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
                      // CAMPANA DE NOTIFICACIONES
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
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
