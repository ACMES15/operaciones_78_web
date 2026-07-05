import 'package:flutter/material.dart';
import 'pdis_detail_page.dart';

class PdisPage extends StatelessWidget {
  final String usuario;
  const PdisPage({Key? key, required this.usuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('PDIS - Auditoría',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón principal colocado arriba con contraste
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.visibility, color: Colors.white),
                    label: const Text('OH PDIS',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PdisDetailPage(usuario: usuario),
                      ));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Auditoría PDIS',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Usuario: $usuario',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            // Mensaje guía
            Expanded(
              child: Center(
                child:
                    Text(' "OH PDIS"', style: TextStyle(color: Colors.black45)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
