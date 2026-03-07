import 'package:flutter/material.dart';
import 'home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/bienvenida_cache.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _mensajeRestablecido = '';
  @override
  void initState() {
    super.initState();
    _userController.addListener(_verificarRestablecido);
  }

  void _verificarRestablecido() async {
    final usuario = _userController.text.trim();
    if (usuario.isEmpty) {
      setState(() {
        _mensajeRestablecido = '';
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final notificaciones = prefs.getString('notificaciones_password') ?? '[]';
    final List<dynamic> lista = jsonDecode(notificaciones);
    final existe = lista.any((n) =>
        n['usuario'] == usuario &&
        n['mensaje'] ==
            'Tu contraseña ha sido restablecida por el administrador');
    setState(() {
      _mensajeRestablecido =
          existe ? 'Usuario reestablecido por el administrador' : '';
    });
    if (existe && !_mostrandoDialogo) {
      _mostrarDialogoCambio(usuario, prefs, lista);
    }
  }

  bool _mostrandoDialogo = false;
  void _mostrarDialogoCambio(
      String usuario, SharedPreferences prefs, List<dynamic> lista) async {
    _mostrandoDialogo = true;
    String nuevaPass = '';
    String confirmPass = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Tu contraseña fue restablecida por el administrador. Ingresa una nueva.'),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Nueva contraseña'),
                onChanged: (v) => nuevaPass = v,
              ),
              const SizedBox(height: 8),
              TextField(
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirmar contraseña'),
                onChanged: (v) => confirmPass = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nuevaPass.isEmpty || confirmPass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Completa ambos campos.')),
                  );
                  return;
                }
                if (nuevaPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Las contraseñas no coinciden.')),
                  );
                  return;
                }
                // Actualizar contraseña
                final data = prefs.getString('usuarios_guardados');
                List<Map<String, dynamic>> usuarios = [];
                if (data != null) {
                  final List<dynamic> decoded = jsonDecode(data);
                  usuarios = decoded
                      .cast<Map<String, dynamic>>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                }
                final index =
                    usuarios.indexWhere((u) => u['usuario'] == usuario);
                if (index != -1) {
                  usuarios[index]['password'] = nuevaPass;
                  await prefs.setString(
                      'usuarios_guardados', jsonEncode(usuarios));
                }
                // Eliminar notificación
                lista.removeWhere((n) =>
                    n['usuario'] == usuario &&
                    n['mensaje'] ==
                        'Tu contraseña ha sido restablecida por el administrador');
                await prefs.setString(
                    'notificaciones_password', jsonEncode(lista));
                setState(() {
                  _mensajeRestablecido = '';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Contraseña actualizada correctamente.')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    _mostrandoDialogo = false;
  }

  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D6A4F),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 370),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 48, color: const Color(0xFF2D6A4F)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bienvenido',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF2D6A4F),
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Inicia sesión para continuar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _userController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingrese usuario' : null,
                ),
                if (_mensajeRestablecido.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Text(
                      _mensajeRestablecido,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingrese contraseña' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final usuario = _userController.text.trim();
                    final password = _passController.text.trim();
                    final prefs = await SharedPreferences.getInstance();
                    final data = prefs.getString('usuarios_guardados');
                    List<Map<String, dynamic>> usuarios = [];
                    if (data != null) {
                      final List<dynamic> decoded = jsonDecode(data);
                      usuarios = decoded
                          .cast<Map<String, dynamic>>()
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                    }
                    // Asegurar usuario maestro
                    final existeAcmes =
                        usuarios.any((u) => u['usuario'] == 'acmes15');
                    if (!existeAcmes) {
                      usuarios.add({
                        'nombre': 'Administrador General',
                        'usuario': 'acmes15',
                        'correo': 'acmes15@empresa.com',
                        'tipo': 'SUPERADMIN',
                        'activo': true,
                        'password': 'cecoatl1315',
                        'requiereCambioPassword': false,
                      });
                      await prefs.setString(
                          'usuarios_guardados', jsonEncode(usuarios));
                    }
                    final user = usuarios.firstWhere(
                      (u) =>
                          u['usuario'] == usuario &&
                          u['password'] == password &&
                          (u['activo'] ?? true),
                      orElse: () => {},
                    );
                    if (user.isNotEmpty) {
                      // Limpiar flag de bienvenida para mostrar animación tras login
                      await BienvenidaCache.limpiar();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(usuario: usuario),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Usuario o contraseña incorrectos'),
                        ),
                      );
                    }
                  },
                  child: const Text('Ingresar'),
                ),
                TextButton(
                  onPressed: () async {
                    final usuario = _userController.text.trim();
                    if (usuario.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Ingrese su usuario para solicitar el restablecimiento.')),
                      );
                      return;
                    }
                    // Guardar notificación en SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    final notificaciones =
                        prefs.getString('notificaciones_password') ?? '[]';
                    final List<dynamic> lista = jsonDecode(notificaciones);
                    lista.add({
                      'usuario': usuario,
                      'fecha': DateTime.now().toIso8601String(),
                      'mensaje': 'Solicitud de restablecimiento de contraseña',
                    });
                    await prefs.setString(
                        'notificaciones_password', jsonEncode(lista));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Se ha enviado una solicitud de restablecimiento de contraseña para $usuario al administrador.')),
                    );
                  },
                  child: const Text('Olvidé mi contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
