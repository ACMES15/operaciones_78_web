import 'package:flutter/material.dart';
import '../home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingrese correo' : null,
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
                    if (!_formKey.currentState!.validate()) return;
                    final email = _emailController.text.trim();
                    final password = _passController.text.trim();
                    try {
                      final cred = await FirebaseAuth.instance
                          .signInWithEmailAndPassword(
                        email: email,
                        password: password,
                      );
                      // Crear documento de usuario y notificaciones si no existen
                      final uid = cred.user?.uid;
                      if (uid != null) {
                        final userDoc = await FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(uid)
                            .get();
                        if (!userDoc.exists) {
                          await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(uid)
                              .set({
                            'email': email,
                            'tipo': 'usuario', // Cambia según lógica de tu app
                          });
                        }
                        final notifDoc = await FirebaseFirestore.instance
                            .collection('notificaciones')
                            .doc(uid)
                            .get();
                        if (!notifDoc.exists) {
                          await FirebaseFirestore.instance
                              .collection('notificaciones')
                              .doc(uid)
                              .set({
                            'items': [],
                          });
                        }
                      }
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(),
                        ),
                      );
                    } on FirebaseAuthException catch (e) {
                      String msg = 'Error de autenticación';
                      if (e.code == 'user-not-found') {
                        msg = 'Usuario no encontrado';
                      } else if (e.code == 'wrong-password') {
                        msg = 'Contraseña incorrecta';
                      } else {
                        msg = '(${e.code}) ${e.message ?? e.toString()}';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Ingresar'),
                ),
                TextButton(
                  child: const Text('Olvidé mi contraseña'),
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Por favor ingresa tu correo electrónico para restablecer la contraseña.')),
                      );
                      return;
                    }
                    try {
                      await FirebaseAuth.instance
                          .sendPasswordResetEmail(email: email);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Revisa tu correo'),
                          content: Text(
                              'Se ha enviado un enlace para restablecer tu contraseña a $email.\n\n'
                              'Por favor revisa tu bandeja de entrada (y la carpeta de spam). Sigue el enlace para crear una nueva contraseña.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Entendido'),
                            ),
                          ],
                        ),
                      );
                    } on FirebaseAuthException catch (e) {
                      String msg =
                          'Error al enviar el correo de restablecimiento';
                      if (e.code == 'user-not-found') {
                        msg = 'No existe una cuenta con ese correo.';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
