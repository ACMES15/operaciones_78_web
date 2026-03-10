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
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passController = TextEditingController();

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
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    // Leer usuarios desde el documento 'usuarios_guardados' en la colección 'usuarios'
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
                    final usuario = _usuarioController.text.trim();
                    final password = _passController.text.trim();
                    final usuarioInput = usuario.trim().toLowerCase();
                    final passInput = password.trim().toLowerCase();
                    // Buscar usuario en el mapa
                    final entry = usuariosMap!.entries.firstWhere(
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
