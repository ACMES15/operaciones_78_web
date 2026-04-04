import 'package:flutter/material.dart';

class RecepcionBigTicketPage extends StatelessWidget {
  const RecepcionBigTicketPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recepción Big Ticket',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 2,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text(
              'Recepción Big Ticket',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D6A4F)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aquí podrás gestionar la recepción de productos de alto valor (Big Ticket).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_box),
              label: const Text('Registrar Recepción',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                // Aquí puedes agregar la lógica para registrar una nueva recepción
              },
            ),
          ],
        ),
      ),
    );
  }
}
