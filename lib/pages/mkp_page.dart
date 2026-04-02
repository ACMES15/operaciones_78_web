import 'package:flutter/material.dart';
import 'guias_mkp_page.dart';
import 'reporte_mkp_page.dart';
import '../widgets/mkp_badge_counter.dart';

class MkpPage extends StatelessWidget {
  const MkpPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MKP'),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Color(0xFF2D6A4F)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF2D6A4F),
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: MkpBadgeCounter(
                child: const Icon(Icons.assignment),
              ),
              label: const Text('Registro de Guías MKP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GuiasMkpPage()),
                );
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart),
              label: const Text('Reporte MKP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReporteMkpPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
