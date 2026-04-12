import 'package:flutter/material.dart';
import 'home_page.dart';
import 'cambiar_password_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usuarioController = TextEditingController();
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // El registro de usuarios se hace en 'Control de usuarios'.

  @override
  void dispose() {
    _usuarioController.dispose();
    _passController.dispose();
    super.dispose();
  }

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
                  controller: _usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingrese su usuario' : null,
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
                      v == null || v.isEmpty ? 'Ingrese su contraseña' : null,
                ),
                // Los campos 'Correo' y 'Tipo' fueron movidos a Control de usuarios.
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final usuario = _usuarioController.text.trim();
                    final password = _passController.text.trim();
                    // Siempre usar minúsculas y sin espacios para el ID
                    final usuarioInput = usuario.trim().toLowerCase();
                    final passInput = password.trim().toLowerCase();
                    try {
                      final docSnap = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(usuarioInput)
                          .get();
                      if (!docSnap.exists || docSnap.data() == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Usuario o contraseña incorrectos.')),
                        );
                        return;
                      }
                      final datos = docSnap.data() ?? {};
                      final tipoUsuario = (datos['tipo'] ?? '').toString();
                      print(
                          '[DEBUG][LOGIN] Tipo de usuario Firestore: $tipoUsuario');
                      final passDb = (datos['password'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();
                      // Si es la primera vez, la contraseña es igual al usuario
                      if (passDb == usuarioInput.trim().toLowerCase() &&
                          passInput == usuarioInput.trim().toLowerCase()) {
                        final changed = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CambiarPasswordPage(usuario: usuarioInput),
                          ),
                        );
                        if (changed == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Contraseña cambiada. Ingresa con tu nueva contraseña.'),
                            ),
                          );
                        }
                        return;
                      }
                      // Si ya cambió la contraseña, validar normalmente
                      if (passDb == passInput) {
                        // Obtener páginas permitidas desde permisos_tipo_usuario/permisos/{tipoUsuario}
                        final permisosSnap = await FirebaseFirestore.instance
                            .collection('permisos_tipo_usuario')
                            .doc('permisos')
                            .get();
                        print(
                            '[DEBUG][LOGIN] permisosSnap.exists: ${permisosSnap.exists}');
                        print(
                            '[DEBUG][LOGIN] permisosSnap.data(): ${permisosSnap.data()}');
                        final allPermisos = permisosSnap.data() ?? {};
                        final permisosData = allPermisos[tipoUsuario] ?? {};
                        print('[DEBUG][LOGIN] permisosData Firestore:');
                        if (permisosData is Map) {
                          permisosData.forEach((k, v) => print('  - "$k": $v'));
                        } else {
                          print(
                              '  [ADVERTENCIA] permisosData no es un mapa. Valor: $permisosData');
                        }
                        final paginasPermitidas = <String>[];
                        if (permisosData is Map) {
                          permisosData.forEach((key, value) {
                            if (value == true || value == 'true')
                              paginasPermitidas.add(key);
                          });
                        }
                        print('[DEBUG][LOGIN] paginasPermitidas filtradas:');
                        for (final p in paginasPermitidas) {
                          print('  - "$p"');
                        }
                        // Obtener cantidad de notificaciones no leídas para el tipo de usuario
                        final notifsSnap = await FirebaseFirestore.instance
                            .collection('notificaciones')
                            .where('para', isEqualTo: tipoUsuario)
                            .where('leida', isEqualTo: false)
                            .get();
                        final notificaciones = notifsSnap.docs.length;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomePage(
                              usuario: usuarioInput,
                              tipoUsuario: tipoUsuario,
                              paginasPermitidas: paginasPermitidas,
                              notificaciones: notificaciones,
                              onLogout: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Usuario o contraseña incorrectos.')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error leyendo usuario: $e')),
                      );
                    }
                  },
                  child: const Text('Ingresar'),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final usuarioInput =
                        _usuarioController.text.trim().toLowerCase();
                    if (usuarioInput.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingrese su usuario')),
                      );
                      return;
                    }
                    try {
                      final userSnap = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(usuarioInput)
                          .get();
                      if (!userSnap.exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Usuario no registrado.')),
                        );
                        return;
                      }
                      // Buscar admins en la colección usuarios
                      final query = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .where('tipo', isEqualTo: 'ADMIN')
                          .get();
                      if (query.docs.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('No hay usuarios admin registrados.')),
                        );
                        return;
                      }
                      // Crear notificación en la colección 'notificaciones'
                      final notifRef = await FirebaseFirestore.instance
                          .collection('notificaciones')
                          .add({
                        'tipo': 'reset_password',
                        'mensaje':
                            'El usuario \'${_usuarioController.text.trim()}\' solicita reseteo de contraseña.',
                        'fecha': DateTime.now(),
                        'leida': false,
                        'para': 'ADMIN',
                        'usuario': _usuarioController.text.trim(),
                      });
                      // Guardar el ID del documento para poder marcar como leída
                      await notifRef.update({'id': notifRef.id});
                      String listaAdmins =
                          query.docs.map((e) => e.id).join(', ');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Se notificó a los administradores: $listaAdmins para restablecer tu contraseña.')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error notificando a admins: $e')),
                      );
                    }
                  },
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
