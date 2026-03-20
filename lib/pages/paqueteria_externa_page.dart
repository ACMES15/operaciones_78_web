import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';

class PaqueteriaExternaPage extends StatefulWidget {
  final String usuario;
  const PaqueteriaExternaPage({Key? key, required this.usuario})
      : super(key: key);

  @override
  State<PaqueteriaExternaPage> createState() => _PaqueteriaExternaPageState();
}

class _PaqueteriaExternaPageState extends State<PaqueteriaExternaPage> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _paqueterias = [
    'DHL',
    'PAQUETE EXPRESS',
    '99 MINUTOS',
    'ESTAFETA',
    'CASTORES',
    'REDPACK',
    'FEDEX',
    'UPS',
    'EXTERNO SIN DATOS'
  ];
  String? _paqueteria;
  final TextEditingController _guiaController = TextEditingController();
  final TextEditingController _bultosController = TextEditingController();
  final TextEditingController _pedidoController = TextEditingController();
  final TextEditingController _contrareciboController = TextEditingController();
  final TextEditingController _nombreRecibeController = TextEditingController();
  final SignatureController _signatureController =
      SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  bool _firmaRealizada = false;
  bool _guardando = false;

  @override
  void dispose() {
    _guiaController.dispose();
    _bultosController.dispose();
    _pedidoController.dispose();
    _contrareciboController.dispose();
    _nombreRecibeController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _guardarFormulario() async {
    if (!_formKey.currentState!.validate() || !_firmaRealizada) return;
    setState(() => _guardando = true);
    final signatureBytes = await _signatureController.toPngBytes();
    final data = {
      'paqueteria': _paqueteria,
      'guia': _guiaController.text.trim(),
      'bultos': _bultosController.text.trim(),
      'pedido': _pedidoController.text.trim(),
      'contrarecibo': _contrareciboController.text.trim(),
      'nombreRecibe': _nombreRecibeController.text.trim(),
      'firma': signatureBytes,
      'usuario': widget.usuario,
      'fecha': DateTime.now(),
    };
    await FirebaseFirestore.instance.collection('paqueteria_externa').add(data);
    // Aquí deberías actualizar el cache local según tu lógica de cache
    setState(() {
      _guardando = false;
      _firmaRealizada = false;
      _signatureController.clear();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Guardado correctamente')));
    _formKey.currentState!.reset();
    _paqueteria = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.local_shipping, color: Colors.white),
            const SizedBox(width: 10),
            const Text('Paquetería Externa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 4,
                    ),
                  ],
                )),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _paqueteria,
                  items: _paqueterias
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) => setState(() => _paqueteria = val),
                  decoration: const InputDecoration(
                      labelText: 'Paquetería', border: OutlineInputBorder()),
                  validator: (val) =>
                      val == null ? 'Seleccione una paquetería' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _guiaController,
                  decoration: const InputDecoration(
                      labelText: 'Guía', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _bultosController,
                  decoration: const InputDecoration(
                      labelText: 'Bultos', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _pedidoController,
                  decoration: const InputDecoration(
                      labelText: 'Pedido', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  // No validator para permitir vacío
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _contrareciboController,
                  decoration: const InputDecoration(
                      labelText: 'Contrarecibo', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  // No validator para permitir vacío
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nombreRecibeController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre de quien recibe',
                      border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) {
                    final upper = v.toUpperCase();
                    if (v != upper) {
                      _nombreRecibeController.value =
                          _nombreRecibeController.value.copyWith(
                        text: upper,
                        selection:
                            TextSelection.collapsed(offset: upper.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),
                const Text('Firma:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  height: 180,
                  child: Listener(
                    onPointerUp: (_) => setState(() =>
                        _firmaRealizada = _signatureController.isNotEmpty),
                    child: Signature(
                      controller: _signatureController,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.blueGrey),
                      onPressed: () {
                        _signatureController.clear();
                        setState(() => _firmaRealizada = false);
                      },
                      label: const Text('Limpiar firma'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_firmaRealizada)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 28),
                      label: const Text('Guardar',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 246, 248, 247),
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                        shadowColor: Colors.black38,
                      ),
                      onPressed: _guardando ? null : _guardarFormulario,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
