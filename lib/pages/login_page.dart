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
                    // DEBUG: Mostrar todos los usuarios leídos de Firestore
                    try {
                      final debugQuery = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .get();
                      print('DEBUG Firestore usuarios:');
                      for (var doc in debugQuery.docs) {
                        print('usuario: "' +
                            (doc['usuario'] ?? '').toString() +
                            '", password: "' +
                            (doc['password'] ?? '').toString() +
                            '"');
                      }
                    } catch (e) {
                      print('DEBUG Error leyendo usuarios Firestore: $e');
                    }
                    if (!_formKey.currentState!.validate()) return;
                    final usuario = _usuarioController.text.trim();
                    final password = _passController.text.trim();
                    final usuarioInput = usuario.trim().toLowerCase();
                    final passInput = password.trim().toLowerCase();
                    try {
                      final query = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .get();
                      // Buscar usuario ignorando mayúsculas y espacios
                      final docs = query.docs.where((doc) {
                        final dbUser = (doc['usuario'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();
                        return dbUser == usuarioInput;
                      }).toList();
                      if (docs.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Usuario no registrado. Verifica el campo "usuario" en Firestore.')),
                        );
                        return;
                      }
                      final data = docs.first.data();
                      final passDb = (data['password'] ?? '')
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
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Ingresar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
