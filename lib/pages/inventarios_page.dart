import 'package:flutter/material.dart';
import 'pdis_page.dart';

class InventariosPage extends StatelessWidget {
  final String usuario;
  const InventariosPage({Key? key, required this.usuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Inventarios',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Operaciones',
                style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            const Text('Inventarios',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildExecutiveCard(
                    context,
                    title: 'Auditoría PDIS',
                    subtitle: 'Revisión y auditoría de inventarios PDIS',
                    icon: Icons.analytics,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PdisPage(usuario: usuario),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap}) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(color: Color(0xFF666666))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.black45, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
