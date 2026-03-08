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
import 'login_page.dart';
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
  int _notificacionesPendientes = 0;
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
    final notificaciones = await _getNotificaciones();
    setState(() {
      _notificacionesPendientes = notificaciones.length;
    });
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

  String _fechaHoraActual() {
    final ahora = DateTime.now();
    return '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}';
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

  void _mostrarNotificaciones() async {
    final notificaciones = await _getNotificaciones();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notificaciones'),
          content: SizedBox(
            width: 400,
            child: notificaciones.isEmpty
                ? const Text('No hay notificaciones pendientes.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: notificaciones.length,
                    itemBuilder: (context, i) {
                      final n = notificaciones[i];
                      final esFaltante = n['mensaje'] == 'FALTANTE DevCan';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            esFaltante
                                ? Icons.warning_amber_rounded
                                : Icons.person_outline,
                            color: esFaltante ? Colors.red : null,
                          ),
                          title: Text(esFaltante
                              ? 'Faltante DevCan'
                              : (n['usuario'] ?? '')),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['fecha'] ?? ''),
                              if (esFaltante && n['detalle'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(n['detalle'],
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              if (!esFaltante && n['mensaje'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(n['mensaje'],
                                      style: const TextStyle(fontSize: 13)),
                                ),
                            ],
                          ),
                          trailing: esFaltante
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Atendido'),
                                  onPressed: () async {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    final notificaciones = prefs.getString(
                                            'notificaciones_password') ??
                                        '[]';
                                    final List<dynamic> lista =
                                        jsonDecode(notificaciones);
                                    lista.removeAt(i);
                                    await prefs.setString(
                                        'notificaciones_password',
                                        jsonEncode(lista));
                                    Navigator.pop(context);
                                    _actualizarNotificaciones();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Notificación de faltante marcada como atendida.')),
                                    );
                                  },
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Restablecer'),
                                  onPressed: () async {
                                    // Restablecer usuario y notificar
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    final usuariosData =
                                        prefs.getString('usuarios_guardados');
                                    List<Map<String, dynamic>> usuarios = [];
                                    if (usuariosData != null) {
                                      final List<dynamic> decoded =
                                          jsonDecode(usuariosData);
                                      usuarios = decoded
                                          .cast<Map<String, dynamic>>()
                                          .map((e) =>
                                              Map<String, dynamic>.from(e))
                                          .toList();
                                    }
                                    final index = usuarios.indexWhere(
                                        (u) => u['usuario'] == n['usuario']);
                                    if (index != -1) {
                                      usuarios[index]['password'] =
                                          n['usuario'];
                                      await prefs.setString(
                                          'usuarios_guardados',
                                          jsonEncode(usuarios));
                                      // Notificar al usuario
                                      final notificaciones = prefs.getString(
                                              'notificaciones_password') ??
                                          '[]';
                                      final List<dynamic> lista =
                                          jsonDecode(notificaciones);
                                      lista.add({
                                        'usuario': n['usuario'],
                                        'fecha':
                                            DateTime.now().toIso8601String(),
                                        'mensaje':
                                            'Tu contraseña ha sido restablecida por el administrador',
                                      });
                                      // Eliminar solicitud
                                      lista.removeAt(i);
                                      await prefs.setString(
                                          'notificaciones_password',
                                          jsonEncode(lista));
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Contraseña de ${n['usuario']} restablecida y notificada.')),
                                      );
                                      _actualizarNotificaciones();
                                    }
                                  },
                                ),
                        ),
                      );
                    },
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
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay páginas permitidas, mostrar mensaje
    if (_paginasPermitidas.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text('No tienes permisos para ver ninguna página.'),
        ),
      );
    }
    // Método para detectar si es celular (no tablet)
    bool esCelular(BuildContext context) {
      final ancho = MediaQuery.of(context).size.width;
      final alto = MediaQuery.of(context).size.height;
      return ancho < 600 && alto < 1000;
    }

    // Obtención de historiales para móvil
    // Hoja de XD historial
    Future<List<dynamic>> cargarHistorialHojaXD() async {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('historial_hoja_de_xd');
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded;
      }
      return [];
    }

    // Detectar si es móvil
    final esMovil = esCelular(context);

    // Si es móvil, filtra las páginas permitidas solo a las de móvil
    List<int> paginasPermitidas = _paginasPermitidas;
    if (esMovil) {
      paginasPermitidas = _paginasPermitidas
          .where((i) => _paginasMovil.contains(_paginas[i]))
          .toList();
      // Si no hay ninguna página móvil permitida, muestra mensaje
      if (paginasPermitidas.isEmpty) {
        return Scaffold(
          body: Center(
            child: Text('No tienes permisos para ver ninguna página en móvil.'),
          ),
        );
      }
      // Si el índice seleccionado no está en las páginas móviles, selecciona la primera
      if (!paginasPermitidas.contains(_paginasPermitidas[_selectedIndex])) {
        _selectedIndex = _paginasPermitidas.indexOf(paginasPermitidas.first);
      }
    }

    // Selección de página actual
    final pagina = _paginas[paginasPermitidas[_selectedIndex]];

    // Si es móvil, muestra los widgets móviles para cada proceso
    if (esMovil) {
      if (pagina == 'Historial Hoja de XD') {
        return FutureBuilder<List<dynamic>>(
          future: cargarHistorialHojaXD(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return HistorialHojaDeXDPageMobile(historial: snapshot.data!);
          },
        );
      }
      if (pagina == 'Historial Entregas DevCan') {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _cargarHistorialDevCan(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return HistorialEntregasDevCanPageMobile(
              historial: snapshot.data!,
              tipoUsuarioActual: _tipoUsuario,
            );
          },
        );
      }
      if (pagina == 'Historial Entregas Recogidos') {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _cargarHistorialRecogidos(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return HistorialEntregasRecogidosPageMobile(
              historial: snapshot.data!,
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
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return HistorialCartaPortePageMobile(historial: snapshot.data!);
          },
        );
      }
      if (pagina == 'DevCan') {
        return DevCanPage();
      }
      if (pagina == 'Recogidos') {
        return RecogidosPage();
      }
    }
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
                              for (final i in (esMovil
                                  ? paginasPermitidas
                                  : _paginasPermitidas))
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: _paginas[i],
                                    child: i == 0
                                        ? const Icon(Icons.people_outline)
                                        : i == 1
                                            ? const Icon(Icons.lock_outline)
                                            : i == 2
                                                ? const Icon(Icons.map_outlined)
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
                                                                                : const Icon(Icons.pages),
                                  ),
                                  selectedIcon: i == 0
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
                                                          ? const Icon(
                                                              Icons.table_view)
                                                          : i == 6
                                                              ? const Icon(Icons
                                                                  .history_toggle_off)
                                                              : i == 7
                                                                  ? const Icon(Icons
                                                                      .assignment)
                                                                  : i == 8
                                                                      ? const Icon(
                                                                          Icons
                                                                              .fact_check)
                                                                      : i == 9
                                                                          ? const Icon(
                                                                              Icons.archive)
                                                                          : i == 10
                                                                              ? const Icon(Icons.archive_outlined)
                                                                              : const Icon(Icons.pages),
                                  label: Text(_paginas[i]),
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
                final pagina = _paginas[(esMovil
                    ? paginasPermitidas
                    : _paginasPermitidas)[_selectedIndex]];
                if (!esMovil) {
                  if (pagina == 'Hoja de XD') {
                    return Navigator(
                      onGenerateRoute: (settings) {
                        return MaterialPageRoute(
                          builder: (context) => HojaDeXDPage(),
                          settings: RouteSettings(arguments: widget.usuario),
                        );
                      },
                    );
                  } else if (pagina == 'Carta Porte') {
                    return const CartaPorteTable();
                  } else if (pagina == 'Historial Carta Porte') {
                    return HistorialCartaPortePage(key: UniqueKey());
                  } else if (pagina == 'Historial Entregas DevCan') {
                    // Cargar historial desde SharedPreferences
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
                  } else {
                    return _pages[_paginasPermitidas[_selectedIndex]];
                  }
                } else {
                  // Ya manejado arriba para móvil
                  if (pagina == 'Historial Hoja de XD') {
                    return FutureBuilder<List<dynamic>>(
                      future: cargarHistorialHojaXD(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return HistorialHojaDeXDPageMobile(
                            historial: snapshot.data!);
                      },
                    );
                  }
                  if (pagina == 'Historial Entregas DevCan') {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cargarHistorialDevCan(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return HistorialEntregasDevCanPageMobile(
                          historial: snapshot.data!,
                          tipoUsuarioActual: _tipoUsuario,
                        );
                      },
                    );
                  }
                  if (pagina == 'Historial Entregas Recogidos') {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cargarHistorialRecogidos(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return HistorialEntregasRecogidosPageMobile(
                          historial: snapshot.data!,
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
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return HistorialCartaPortePageMobile(
                            historial: snapshot.data!);
                      },
                    );
                  }
                  if (pagina == 'DevCan') {
                    return DevCanPage();
                  }
                  if (pagina == 'Recogidos') {
                    return RecogidosPage();
                  }
                  // fallback
                  return Center(child: Text('Página no disponible.'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
