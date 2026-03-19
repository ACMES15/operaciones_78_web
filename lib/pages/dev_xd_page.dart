import 'package:flutter/material.dart';
import 'entregas_xd_page.dart';
import 'package:flutter/foundation.dart';

// Clon de DevMbodasPage adaptado para XD
class DevXdPage extends StatefulWidget {
  final String usuario;
  const DevXdPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<DevXdPage> createState() => _DevXdPageState();
}

class _DevXdPageState extends State<DevXdPage> {
  // --- Lógica y estado igual a DevMbodasPage, pero adaptado para XD ---

  void _verEntregasXD() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntregasXdPage(usuario: widget.usuario),
      ),
    );
  }
  // Variables eliminadas por no usarse
  // Variables eliminadas por no usarse

  // Método _addRow eliminado por no usarse

  @override
  Widget build(BuildContext context) {
    final isMobileSmall = MediaQuery.of(context).size.shortestSide <= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.extension, color: Color(0xFF2D6A4F), size: 28),
            SizedBox(width: 10),
            Text(
              'Dev XD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: Color(0xFF2D6A4F),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFE9ECEF),
        elevation: 0,
      ),
      body: isMobileSmall
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Ver Entregas XD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18),
                    ),
                    onPressed: _verEntregasXD,
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Importar Excel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Guardar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Agregar fila'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _verEntregasXD,
                        child: const Text('Ver entregas XD'),
                      ),
                    ],
                  ),
                  // ...aquí iría el resto de la UI de Dev XD...
                ],
              ),
            ),
    );
  }
}
