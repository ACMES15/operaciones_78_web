import 'package:flutter/material.dart';
import '../utils/bienvenida_cache.dart';

class BienvenidaPage extends StatefulWidget {
  final String usuario;
  final String tipoUsuario;
  const BienvenidaPage(
      {Key? key, required this.usuario, required this.tipoUsuario})
      : super(key: key);

  @override
  State<BienvenidaPage> createState() => _BienvenidaPageState();
}

class _BienvenidaPageState extends State<BienvenidaPage> {
  bool _cargando = true;
  String _textoAnimado = '';
  String _usuarioAnimado = '';
  int _puntos = 0;
  late final String _usuarioAnimar;

  @override
  void initState() {
    super.initState();
    _verificarBienvenida();
  }

  void _verificarBienvenida() async {
    _usuarioAnimar = widget.usuario;
    final yaMostrada = await BienvenidaCache.fueMostrada();
    if (yaMostrada) {
      setState(() {
        _cargando = false;
      });
    } else {
      await _iniciarAnimacionCarga();
      await BienvenidaCache.marcarMostrada();
    }
  }

  Future<void> _iniciarAnimacionCarga() async {
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 220));
      setState(() {
        _puntos = (i % 4);
      });
    }
    for (int i = 1; i <= _usuarioAnimar.length; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      setState(() {
        _usuarioAnimado = _usuarioAnimar.substring(0, i);
      });
    }
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_cargando)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF2D6A4F),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 32),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 120),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D6A4F),
                    letterSpacing: 8,
                  ),
                  child: Text(_usuarioAnimado),
                ),
              ],
            ),
          )
        else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Bienvenido a Operaciones 0078 Web',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D6A4F),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Icon(Icons.account_circle, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Usuario: ${widget.usuario}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tipo de usuario: ${widget.tipoUsuario}',
                  style: const TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ],
            ),
          ),
        // ACMES fijo en la esquina inferior izquierda
        Positioned(
          left: 16,
          bottom: 12,
          child: Text(
            'ACMES',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 6,
            ),
          ),
        ),
      ],
    );
  }
}
