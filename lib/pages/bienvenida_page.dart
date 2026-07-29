import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:html' as html;
import 'dart:typed_data';
import '../utils/bienvenida_cache.dart';

class BienvenidaPage extends StatefulWidget {
  final String usuario;
  final String tipoUsuario;
  const BienvenidaPage({
    Key? key,
    required this.usuario,
    required this.tipoUsuario,
  }) : super(key: key);

  @override
  State<BienvenidaPage> createState() => _BienvenidaPageState();
}

class _BienvenidaPageState extends State<BienvenidaPage>
    with TickerProviderStateMixin {
  bool _cargando = true;
  String _usuarioAnimado = '';
  int _puntos = 0;
  late final String _usuarioAnimar;

  late final AnimationController _entradaController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  late final AnimationController _iconoController;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();

    _entradaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn =
        CurvedAnimation(parent: _entradaController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entradaController, curve: Curves.easeOutCubic),
    );

    _iconoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _iconScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _iconoController, curve: Curves.easeInOut),
    );

    _verificarBienvenida();
  }

  @override
  void dispose() {
    _entradaController.dispose();
    _iconoController.dispose();
    super.dispose();
  }

  void _activarVistaFinal() {
    _entradaController.forward();
    _iconoController.repeat(reverse: true);
  }

  void _verificarBienvenida() async {
    _usuarioAnimar = widget.usuario;
    final yaMostrada = await BienvenidaCache.fueMostrada();
    if (!mounted) return;

    if (yaMostrada) {
      setState(() => _cargando = false);
      _activarVistaFinal();
    } else {
      await _iniciarAnimacionCarga();
      await BienvenidaCache.marcarMostrada();
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
      uploadInput.click();
      await uploadInput.onChange.first;
      final file = uploadInput.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final result = reader.result;
      if (result == null) return;
      Uint8List bytes;
      if (result is ByteBuffer)
        bytes = result.asUint8List();
      else if (result is Uint8List)
        bytes = result;
      else if (result is List) {
        try {
          bytes = Uint8List.fromList(result.cast<int>());
        } catch (_) {
          return;
        }
      } else {
        return;
      }

      final uid = widget.usuario.trim().toLowerCase();
      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref('user_avatars/$uid.jpg');
      final uploadTask = storageRef.putData(
          bytes, firebase_storage.SettableMetadata(contentType: file.type));
      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set({'avatarUrl': url}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar subido correctamente')));
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error subiendo avatar: $e')));
    }
  }

  Future<void> _iniciarAnimacionCarga() async {
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() => _puntos = (i % 4));
    }

    for (int i = 1; i <= _usuarioAnimar.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _usuarioAnimado = _usuarioAnimar.substring(0, i));
    }

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _cargando = false);
    _activarVistaFinal();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6FAF8), Color(0xFFFFFFFF)],
        ),
      ),
      child: Stack(
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
                  const SizedBox(height: 28),
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
                  const SizedBox(height: 8),
                  Text(
                    '.' * _puntos,
                    style: TextStyle(
                      color: Colors.grey[500],
                      letterSpacing: 3,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Container(
                    width: 640,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6ECE9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Bienvenido a Operaciones 0078 Web',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F3F33),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ScaleTransition(
                          scale: _iconScale,
                          child: GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF1F7F4),
                                border:
                                    Border.all(color: const Color(0xFFDCE9E2)),
                              ),
                              child: FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('usuarios')
                                    .doc(widget.usuario.trim().toLowerCase())
                                    .get(),
                                builder: (context, snap) {
                                  final avatar = snap.hasData &&
                                          snap.data!.data() != null
                                      ? (snap.data!.data() as Map)['avatarUrl']
                                          ?.toString()
                                      : null;
                                  if (avatar != null && avatar.isNotEmpty) {
                                    return CircleAvatar(
                                      radius: 38,
                                      backgroundColor: Colors.transparent,
                                      backgroundImage: NetworkImage(avatar),
                                    );
                                  }
                                  return const Icon(
                                    Icons.account_circle,
                                    size: 82,
                                    color: Color(0xFF6E7D76),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Usuario: ${widget.usuario}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tipo de usuario: ${widget.tipoUsuario}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
      ),
    );
  }
}
