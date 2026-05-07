import 'package:flutter/material.dart';

class CartaPortePage extends StatelessWidget {
  final String usuario;
  const CartaPortePage({Key? key, required this.usuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carta Porte'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CartaPorteTable(usuario: usuario),
      ),
    );
  }
}

class CartaPorteTable extends StatelessWidget {
  final String usuario;
  const CartaPorteTable({Key? key, required this.usuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Aquí deberías usar el usuario si es necesario
    return Center(child: Text('Carta Porte Table para $usuario'));
  }
}
