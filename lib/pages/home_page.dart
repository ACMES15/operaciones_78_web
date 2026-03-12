import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_control_page.dart';
import 'user_permissions_page.dart';
import 'hoja_de_ruta_page.dart';
import 'hoja_de_xd_page.dart';
import 'hoja_de_xd_historial_page.dart';
import 'historial_entregas_devcan_page.dart';
import 'historial_carta_porte_page.dart';
import 'plantilla_ejecutiva_page.dart';
import 'devcan_page.dart';
import 'recogidos/recogidos_page.dart';
import 'recogidos/historial_entregas_recogidos_page.dart';
import 'bienvenida_page.dart';
import '../utils/firebase_cache_utils.dart';
import 'historial_entregas_recogidos_mobile.dart';
import 'historial_entregas_devcan_mobile.dart';

class HomePage extends StatefulWidget {
  final String usuario;
  const HomePage({required this.usuario, super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Estado para error de usuario/tipo
  String? _errorUsuario;

  /// Normaliza un string: quita espacios, lo pasa a mayúsculas y elimina tildes.
  String _normalizar(String s) {
    final withNoSpaces = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    final upper = withNoSpaces.toUpperCase();
    // Elimina tildes
    final normalized = upper
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
    return normalized;
  }

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
        Builder(builder: (context) => HojaDeXDPage(usuario: widget.usuario)),
        HojaDeXDHistorialPage(),
        Builder(
          builder: (context) {
            // CartaPorteTable no está garantizado en la librería importada;
            // mostrar un placeholder para evitar errores de compilación.
            return const Center(child: Text('Carta Porte no disponible'));
          },
        ),
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
    _determinarTipoUsuarioFirestore();
    _actualizarNotificaciones();
  }

  Future<void> _determinarTipoUsuarioFirestore() async {
    // Leer usuario y permisos directamente de Firestore
    final usuarioDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc('usuarios_guardados')
        .get();
    if (!usuarioDoc.exists || usuarioDoc.data() == null) {
      setState(() {
        _errorUsuario = 'No existe el documento de usuarios en Firestore.';
      });
      return;
    }
    final usuariosMap = usuarioDoc.data()!;
    final datos = usuariosMap[widget.usuario] as Map<String, dynamic>?;
    if (datos == null) {
      setState(() {
        _errorUsuario =
            'El usuario "${widget.usuario}" no existe en el sistema.';
      });
      return;
    }
    final tipoOriginal = datos['tipo'] ?? datos['rol'] ?? '';
    if (tipoOriginal == null || tipoOriginal.toString().trim().isEmpty) {
      setState(() {
        _errorUsuario =
            'El usuario "${widget.usuario}" no tiene un tipo asignado.';
      });
      return;
    }
    String tipo = tipoOriginal.toString();
    print(
        '[DEBUG] Tipo de usuario leído desde Firestore: "$tipoOriginal" para usuario: "${widget.usuario}"');
    if (_normalizar(tipo).contains('ADMIN')) {
      tipo = 'ADMIN';
    }
    List<int> permitidas = [];
    if (_normalizar(tipo) == 'SUPERADMIN') {
      permitidas = List.generate(_paginas.length, (i) => i);
    } else {
      final permisosDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc('permisos_tipo_usuario')
          .get();
      if (permisosDoc.exists && permisosDoc.data() != null) {
        final permisos =
            permisosDoc.data()!['permisos'] as Map<String, dynamic>?;
        if (permisos != null) {
          String? clavePermiso;
          for (final k in permisos.keys) {
            if (_normalizar(k) == _normalizar(tipo)) {
              clavePermiso = k;
              break;
            }
          }
          final permisosTipo = clavePermiso != null
              ? permisos[clavePermiso] as Map<String, dynamic>?
              : null;
          if (permisosTipo != null) {
            for (int i = 0; i < _paginas.length; i++) {
              final nombrePagina = _paginas[i];
              String? clavePagina;
              for (final pk in permisosTipo.keys) {
                if (_normalizar(pk) == _normalizar(nombrePagina)) {
                  clavePagina = pk;
                  break;
                }
              }
              if (clavePagina != null && permisosTipo[clavePagina] == true) {
                permitidas.add(i);
              }
            }
          }
        }
      }
      if (permitidas.isEmpty) permitidas = [0];
    }
    setState(() {
      _tipoUsuario = tipoOriginal;
      _paginasPermitidas = permitidas;
      _errorUsuario = null;
    });
  }

  Future<void> _actualizarNotificaciones() async {
    // final notificaciones = await _getNotificaciones();
    // setState(() {
    //   _notificacionesPendientes = notificaciones.length;
    // });
  }

  Future<List<Map<String, dynamic>>> _cargarHistorialRecogidos() async {
    // Intenta leer de cache, si no existe, lee de Firestore y cachea
    final datos =
        await leerDatosConCache('historial_entregas', 'recogidos_firmadas');
    if (datos != null && datos['items'] != null) {
      final List<dynamic> items = datos['items'];
      return items
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  // ignore: unused_element
  Future<List<Map<String, dynamic>>> _getNotificaciones() async {
    // TODO: Implementar notificaciones desde Firestore si es necesario
    return [];
  }

  Future<List<Map<String, dynamic>>> _cargarHistorialDevCan() async {
    // Intenta leer de cache, si no existe, lee de Firestore y cachea
    final datos =
        await leerDatosConCache('historial_entregas', 'devcan_firmadas');
    if (datos != null && datos['items'] != null) {
      final List<dynamic> items = datos['items'];
      return items
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_errorUsuario != null) {
      return Scaffold(
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorUsuario!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
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
                            maxHeight: 1500,
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
                    // TODO: Implementar carga de historial desde Firestore si es necesario
                    return const Center(child: Text('No disponible.'));
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
                    // TODO: Implementar carga de historial desde Firestore si es necesario
                    return const Center(child: Text('No disponible.'));
                  }

                  if (pagina == 'DevCan') {
                    // En móvil, mostrar botón que lleva al proceso de selección y firma (EntregasDevCanPage)
                    // TODO: Implementar carga de entregas desde Firestore si es necesario
                    return const Center(child: Text('No disponible.'));
                  } else if (pagina == 'Recogidos') {
                    // En móvil, mostrar botón que lleva al proceso de selección y firma (EntregasRecogidosPage)
                    // TODO: Implementar carga de recogidos desde Firestore si es necesario
                    return const Center(child: Text('No disponible.'));
                  } else if (pagina == 'Hoja de XD') {
                    return HojaDeXDPage(usuario: widget.usuario);
                  } else if (pagina == 'Carta Porte') {
                    // CartaPorteTable no disponible en la importación actual; usar placeholder
                    return const Center(
                        child: Text('Carta Porte no disponible'));
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
