import 'package:flutter/material.dart';
import '../home_page.dart';
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
  final _correoController = TextEditingController();
  final _tipoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> agregarUsuarioDesdeApp(
      String usuario, String password, String correo, String tipo) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc('usuarios_guardados');

      final docSnap = await docRef.get();
      Map<String, dynamic> usuariosMap = {};
      if (docSnap.exists && docSnap.data() != null) {
        usuariosMap = Map<String, dynamic>.from(docSnap.data()!);
      }

      // Añadir o actualizar el usuario en el mapa
      usuariosMap[usuario] = {
        'password': password,
        'correo': correo,
        'rol': tipo,
      };

      // Guardar el documento completo (puedes usar set con merge si prefieres)
      await docRef.set(usuariosMap);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario registrado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registrando usuario: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passController.dispose();
    _correoController.dispose();
    _tipoController.dispose();
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _correoController,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingrese el correo' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tipoController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Ingrese el tipo de usuario'
                      : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final usuario = _usuarioController.text.trim();
                    final password = _passController.text.trim();
                    // Intentar login normal
                    Map<String, dynamic>? usuariosMap;
                    try {
                      final docSnap = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc('usuarios_guardados')
                          .get();
                      if (!docSnap.exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'No existe el documento usuarios_guardados en Firestore.')),
                        );
                        return;
                      }
                      usuariosMap = docSnap.data();
                      if (usuariosMap == null || usuariosMap.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'El documento usuarios_guardados está vacío.')),
                        );
                        return;
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Error leyendo usuarios_guardados: $e')),
                      );
                      return;
                    }
                    final usuarioInput = usuario.trim().toLowerCase();
                    final passInput = password.trim().toLowerCase();
                    final entry = usuariosMap.entries.firstWhere(
                      (e) => (e.key.trim().toLowerCase() == usuarioInput),
                      orElse: () => const MapEntry('', null),
                    );
                    if (entry.key.isEmpty || entry.value == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Usuario no registrado en usuarios_guardados.')),
                      );
                      return;
                    }
                    final datos = entry.value as Map<String, dynamic>?;
                    final passDb = (datos?['password'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    // Si es la primera vez, la contraseña es igual al usuario
                    if (passDb == usuarioInput && passInput == usuarioInput) {
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
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(usuario: usuario),
                        ),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Usuario o contraseña incorrectos.')),
                    );
                  },
                  child: const Text('Ingresar'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    // Agregar usuario desde la app
                    final usuario = _usuarioController.text.trim();
                    final password = _passController.text.trim();
                    final correo = _correoController.text.trim();
                    final tipo = _tipoController.text.trim();
                    if (usuario.isEmpty ||
                        password.isEmpty ||
                        correo.isEmpty ||
                        tipo.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Todos los campos son requeridos para registrar.')),
                      );
                      return;
                    }
                    await agregarUsuarioDesdeApp(
                        usuario, password, correo, tipo);
                  },
                  child: const Text('Registrar usuario'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    // Buscar admins en usuarios_guardados
                    try {
                      final docSnap = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc('usuarios_guardados')
                          .get();
                      if (!docSnap.exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'No existe el documento usuarios_guardados en Firestore.')),
                        );
                        return;
                      }
                      final usuariosMap = docSnap.data();
                      if (usuariosMap == null || usuariosMap.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'El documento usuarios_guardados está vacío.')),
                        );
                        return;
                      }
                      // Buscar admins
                      final admins = usuariosMap.entries.where((e) {
                        final datos = e.value as Map<String, dynamic>?;
                        return (datos?['rol'] ?? '').toString().toLowerCase() ==
                            'admin';
                      }).toList();
                      if (admins.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('No hay usuarios admin registrados.')),
                        );
                        return;
                      }
                      // Aquí podrías enviar email o notificación real
                      String listaAdmins = admins.map((e) => e.key).join(', ');
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
