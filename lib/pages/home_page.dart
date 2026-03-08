import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'user_control_page.dart';
import 'user_permissions_page.dart';
import 'hoja_de_ruta_page.dart';
import 'hoja_de_xd_page.dart';
import 'hoja_de_xd_historial_page.dart';
import 'historial_hoja_de_xd_mobile.dart';
import 'historial_entregas_devcan_mobile.dart';
import 'historial_entregas_recogidos_mobile.dart';
import 'historial_carta_porte_mobile.dart';
// import 'login_page.dart';
import 'entregas_devcan_page.dart';
import 'recogidos/entregas_recogidos_page.dart';
import 'carta_porte_table.dart';
import 'historial_carta_porte_page.dart';
import 'plantilla_ejecutiva_page.dart';
import 'devcan_page.dart';
import 'historial_entregas_devcan_page.dart';
import 'recogidos/recogidos_page.dart';
import 'recogidos/historial_entregas_recogidos_page.dart';
import 'bienvenida_page.dart';

class HomePage extends StatefulWidget {
  final String usuario;
  const HomePage({required this.usuario, super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // int _notificacionesPendientes = 0;
  int _selectedIndex = 0;
  bool _menuExpandido = false;
  String _tipoUsuario = '';
  List<String> _paginas = [
    'Inicio',
    'Control de usuarios',
    'Permisos de usuario',
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

  // Páginas permitidas en móvil (solo historiales y DevCan/Recogidos)
  final List<String> _paginasMovil = [
    'Historial Hoja de XD',
    'Historial Entregas DevCan',
    'Historial Carta Porte',
    'Historial Entregas Recogidos',
    'DevCan',
    'Recogidos',
  ];
  List<int> _paginasPermitidas = [];
  List<Widget> get _pages => [
        BienvenidaPage(usuario: widget.usuario, tipoUsuario: _tipoUsuario),
        UserControlPage(),
        UserPermissionsPage(),
        HojaDeRutaPage(),
        Builder(builder: (context) => HojaDeXDPage()),
        HojaDeXDHistorialPage(),
        CartaPorteTable(),
        HistorialCartaPortePage(),
        PlantillaEjecutivaPage(),
        DevCanPage(),
        Builder(
          builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
            future: _cargarHistorialDevCan(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return HistorialEntregasDevCanPage(
                historial: snapshot.data!,
                tipoUsuarioActual: _tipoUsuario,
              );
            },
          ),
        ),
        RecogidosPage(),
        Builder(
          builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
            future: _cargarHistorialRecogidos(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return HistorialEntregasRecogidosPage(
                historial: snapshot.data!,
                tipoUsuarioActual: _tipoUsuario,
              );
            },
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _determinarTipoUsuario();
    _actualizarNotificaciones();
  }

  Future<void> _actualizarNotificaciones() async {
    // final notificaciones = await _getNotificaciones();
    // setState(() {
    //   _notificacionesPendientes = notificaciones.length;
    // });
  }

  Future<void> _determinarTipoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('usuarios_guardados');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      final usuario = decoded.firstWhere(
        (u) => u['usuario'] == widget.usuario,
        orElse: () => null,
      );
      if (usuario != null) {
        final tipo = usuario['tipo'] ?? '';
        List<int> permitidas = [];
        if (tipo == 'SUPERADMIN') {
          permitidas = List.generate(_paginas.length, (i) => i);
        } else {
          // Leer permisos personalizados
          final permisosData = prefs.getString('permisos_tipo_usuario');
          if (permisosData != null) {
            final permisos = jsonDecode(permisosData) as Map<String, dynamic>;
            final permisosTipo = permisos[tipo] as Map<String, dynamic>?;
            if (permisosTipo != null) {
              for (int i = 0; i < _paginas.length; i++) {
                final nombrePagina = _paginas[i];
                if (permisosTipo[nombrePagina] == true) {
                  permitidas.add(i);
                }
              }
            }
          }
          // Si no hay permisos configurados, solo Inicio
          if (permitidas.isEmpty) permitidas = [0];
        }
        setState(() {
          _tipoUsuario = tipo;
          _paginasPermitidas = permitidas;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _cargarHistorialRecogidos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('historial_entregas_recogidos');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getNotificaciones() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notificaciones_password') ?? '[]';
    final List<dynamic> lista = jsonDecode(data);
    return lista.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _cargarHistorialDevCan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('historial_entregas_devcan');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // Método para detectar si es celular (no tablet)
    bool esCelular(BuildContext context) {
      final ancho = MediaQuery.of(context).size.width;
      final alto = MediaQuery.of(context).size.height;
      return ancho < 600 && alto < 1000;
    }

    final esMovil = esCelular(context);
    List<int> paginasPermitidas = _paginasPermitidas;
    int selectedMenuIndex = _selectedIndex;
    if (esMovil) {
      paginasPermitidas = _paginasPermitidas
          .where((i) => _paginasMovil.contains(_paginas[i]))
          .toList();
      if (paginasPermitidas.isEmpty) {
        return Scaffold(
          body: Center(
            child: Text('No tienes permisos para ver ninguna página en móvil.'),
          ),
        );
      }
      if (selectedMenuIndex < 0 ||
          selectedMenuIndex >= paginasPermitidas.length) {
        selectedMenuIndex = 0;
      }
    } else {
      if (selectedMenuIndex < 0 ||
          selectedMenuIndex >= paginasPermitidas.length) {
        selectedMenuIndex = 0;
      }
    }

    final pagina = _paginas[paginasPermitidas[selectedMenuIndex]];

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
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 0,
                            maxHeight: 900,
                          ),
                          child: NavigationRail(
                            selectedIndex: selectedMenuIndex,
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
                              for (int menuIdx = 0;
                                  menuIdx < paginasPermitidas.length;
                                  menuIdx++)
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message:
                                        _paginas[paginasPermitidas[menuIdx]],
                                    child: (() {
                                      int i = paginasPermitidas[menuIdx];
                                      return i == 0
                                          ? const Icon(Icons.people_outline)
                                          : i == 1
                                              ? const Icon(Icons.lock_outline)
                                              : i == 2
                                                  ? const Icon(
                                                      Icons.map_outlined)
                                                  : i == 3
                                                      ? const Icon(Icons
                                                          .description_outlined)
                                                      : i == 4
                                                          ? const Icon(
                                                              Icons.history)
                                                          : i == 5
                                                              ? const Icon(Icons
                                                                  .table_view)
                                                              : i == 6
                                                                  ? const Icon(Icons
                                                                      .history_toggle_off)
                                                                  : i == 7
                                                                      ? const Icon(
                                                                          Icons
                                                                              .assignment)
                                                                      : i == 8
                                                                          ? const Icon(
                                                                              Icons.fact_check)
                                                                          : i == 9
                                                                              ? const Icon(Icons.archive)
                                                                              : i == 10
                                                                                  ? const Icon(Icons.archive_outlined)
                                                                                  : const Icon(Icons.pages);
                                    })(),
                                  ),
                                  selectedIcon: (() {
                                    int i = paginasPermitidas[menuIdx];
                                    return i == 0
                                        ? const Icon(Icons.people)
                                        : i == 1
                                            ? const Icon(Icons.lock)
                                            : i == 2
                                                ? const Icon(Icons.map)
                                                : i == 3
                                                    ? const Icon(
                                                        Icons.description)
                                                    : i == 4
                                                        ? const Icon(
                                                            Icons.history)
                                                        : i == 5
                                                            ? const Icon(Icons
                                                                .table_view)
                                                            : i == 6
                                                                ? const Icon(Icons
                                                                    .history_toggle_off)
                                                                : i == 7
                                                                    ? const Icon(
                                                                        Icons
                                                                            .assignment)
                                                                    : i == 8
                                                                        ? const Icon(
                                                                            Icons.fact_check)
                                                                        : i == 9
                                                                            ? const Icon(Icons.archive)
                                                                            : i == 10
                                                                                ? const Icon(Icons.archive_outlined)
                                                                                : const Icon(Icons.pages);
                                  })(),
                                  label: Text(
                                      _paginas[paginasPermitidas[menuIdx]]),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                // Manejo móvil simplificado y sin duplicaciones
                if (esMovil) {
                  if (pagina == 'Historial Hoja de XD') {
                    Future<List<dynamic>> cargarHistorialHojaXD() async {
                      final prefs = await SharedPreferences.getInstance();
                      final data = prefs.getString('historial_hoja_de_xd');
                      if (data != null) {
                        final List<dynamic> decoded = jsonDecode(data);
                        return decoded;
                      }
                      return [];
                    }

                    return FutureBuilder<List<dynamic>>(
                      future: cargarHistorialHojaXD(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                              child: CircularProgressIndicator());
                        final datos = snapshot.data!;
                        if (datos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No hay historial disponible.'),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Regresar al menú'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                        return HistorialHojaDeXDPageMobile(historial: datos);
                      },
                    );
                  }

                  if (pagina == 'Historial Entregas DevCan') {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cargarHistorialDevCan(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                              child: CircularProgressIndicator());
                        final datos = snapshot.data!;
                        if (datos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No hay historial disponible.'),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Regresar al menú'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                        return HistorialEntregasDevCanPageMobile(
                          historial: datos,
                          tipoUsuarioActual: _tipoUsuario,
                        );
                      },
                    );
                  }

                  if (pagina == 'Historial Entregas Recogidos') {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cargarHistorialRecogidos(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                              child: CircularProgressIndicator());
                        final datos = snapshot.data!;
                        if (datos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No hay historial disponible.'),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Regresar al menú'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                        return HistorialEntregasRecogidosPageMobile(
                          historial: datos,
                          tipoUsuarioActual: _tipoUsuario,
                        );
                      },
                    );
                  }

                  if (pagina == 'Historial Carta Porte') {
                    Future<List<dynamic>> cargarHistorialCartaPorte() async {
                      final prefs = await SharedPreferences.getInstance();
                      final data = prefs.getString('historial_carta_porte');
                      if (data != null) {
                        final List<dynamic> decoded = jsonDecode(data);
                        return decoded;
                      }
                      return [];
                    }

                    return FutureBuilder<List<dynamic>>(
                      future: cargarHistorialCartaPorte(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                              child: CircularProgressIndicator());
                        final datos = snapshot.data!;
                        if (datos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No hay historial disponible.'),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Regresar al menú'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                        return HistorialCartaPortePageMobile(historial: datos);
                      },
                    );
                  }

                  if (pagina == 'DevCan') {
                    // En móvil, mostrar botón que lleva al proceso de selección y firma (EntregasDevCanPage)
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final data = prefs.getString('entregas_devcan') ?? '[]';
                        final List<dynamic> lista = jsonDecode(data);
                        return lista
                            .map<Map<String, dynamic>>(
                                (e) => Map<String, dynamic>.from(e))
                            .toList();
                      }(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final entregasRecientes = snapshot.data!;
                        return Center(
                          child: ElevatedButton(
                            onPressed: entregasRecientes.isEmpty
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EntregasDevCanPage(
                                                entregasRecientes:
                                                    entregasRecientes),
                                      ),
                                    );
                                  },
                            child: const Text('Ver Entregas DevCan'),
                          ),
                        );
                      },
                    );
                  } else if (pagina == 'Recogidos') {
                    // En móvil, mostrar botón que lleva al proceso de selección y firma (EntregasRecogidosPage)
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final data =
                            prefs.getString('entregas_recogidos') ?? '[]';
                        final List<dynamic> lista = jsonDecode(data);
                        return lista
                            .map<Map<String, dynamic>>(
                                (e) => Map<String, dynamic>.from(e))
                            .toList();
                      }(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final entregasRecientes = snapshot.data!;
                        return Center(
                          child: ElevatedButton(
                            onPressed: entregasRecientes.isEmpty
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EntregasRecogidosPage(
                                                entregasRecientes:
                                                    entregasRecientes),
                                      ),
                                    );
                                  },
                            child: const Text('Ver Entregas Recogidos'),
                          ),
                        );
                      },
                    );
                  } else if (pagina == 'Hoja de XD') {
                    return HojaDeXDPage();
                  } else if (pagina == 'Carta Porte') {
                    return const CartaPorteTable();
                  } else if (pagina == 'Historial Carta Porte') {
                    return HistorialCartaPortePage(key: UniqueKey());
                  } else if (pagina == 'Historial Entregas DevCan') {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cargarHistorialDevCan(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return HistorialEntregasDevCanPage(
                          historial: snapshot.data!,
                          tipoUsuarioActual: _tipoUsuario,
                        );
                      },
                    );
                  } else if (_pages.isNotEmpty &&
                      _paginasPermitidas.isNotEmpty) {
                    return _pages[_paginasPermitidas[selectedMenuIndex]];
                  } else {
                    return const Center(child: Text('Página no disponible'));
                  }
                } else {
                  // Desktop/tablet: always return the selected page
                  return _pages[paginasPermitidas[selectedMenuIndex]];
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
