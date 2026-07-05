import 'package:flutter/material.dart';
import 'pdis_detail_page.dart';

class PdisPage extends StatelessWidget {
  final String usuario;
  const PdisPage({Key? key, required this.usuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        title: const Text('PDIS - Auditoría',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Auditoría PDIS',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Usuario: $usuario',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Resumen ejecutivo',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                        'KPIs y estado de auditoría PDIS se muestran aquí de forma breve.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    icon: const Icon(Icons.visibility),
                    label:
                        const Text('OH PDIS', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PdisDetailPage(usuario: usuario),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Importar Excel'),
                  onPressed: () {
                    // Navega directamente al detalle donde está el importador
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PdisDetailPage(usuario: usuario),
                    ));
                  },
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Text(
                    'Seleccione "OH PDIS" para ver detalles e importar datos',
                    style: TextStyle(color: Colors.black45)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
