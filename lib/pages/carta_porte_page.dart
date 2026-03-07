import 'package:flutter/material.dart';

class CartaPortePage extends StatelessWidget {
  const CartaPortePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carta Porte'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CartaPorteTable(),
      ),
    );
  }
}

class CartaPorteTable extends StatelessWidget {
  const CartaPorteTable({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Replace with your actual table or content
    return Center(child: Text('Carta Porte Table'));
  }
}
