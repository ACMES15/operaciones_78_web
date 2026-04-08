import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class GuiasCycPage extends StatefulWidget {
  final String usuario;
  const GuiasCycPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<GuiasCycPage> createState() => _GuiasCycPageState();
}

class _GuiasCycPageState extends State<GuiasCycPage> {
  final List<List<TextEditingController>> _rows = [];
  final int _minRows = 5;
  final int _maxRows = 1000;
  final FocusNode _firstFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _minRows; i++) {
      _rows.add([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    }
  }

  @override
  void dispose() {
    for (var row in _rows) {
      for (var ctrl in row) {
        ctrl.dispose();
      }
    }
    _firstFocus.dispose();
    super.dispose();
  }

  void _addRowIfNeeded(int idx) {
    if (idx >= _rows.length - 2 && _rows.length < _maxRows) {
      setState(() {
        _rows.add([
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ]);
      });
    }
  }

  void _onGuiaSubmitted(int idx) {
    // Registrar fecha y hora solo si el campo guía no está vacío
    final guia = _rows[idx][0].text.trim();
    if (guia.isNotEmpty) {
      final now = DateTime.now();
      final fecha = DateFormat('dd/MM/yyyy').format(now);
      final hora = DateFormat('HH:mm:ss').format(now);
      setState(() {
        _rows[idx][1].text = fecha;
        _rows[idx][2].text = hora;
      });
      _addRowIfNeeded(idx);
      // Mover el foco a la siguiente fila, campo guía
      if (idx + 1 < _rows.length) {
        FocusScope.of(context).requestFocus(FocusNode());
        Future.delayed(const Duration(milliseconds: 50), () {
          FocusScope.of(context).nextFocus();
        });
      }
    }
  }

  void _guardar() {
    // Aquí puedes implementar la lógica de guardado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registros guardados (demo).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.shortestSide <= 600;
    final pink = const Color(0xFFF06292);
    final darkPink = const Color(0xFFD81B60);
    final bg = const Color(0xFFFCE4EC);
    final border = const Color(0xFFF8BBD0);
    final titleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 28,
      color: darkPink,
      letterSpacing: 1.2,
    );
    final headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: Colors.white,
      letterSpacing: 1.1,
    );
    final cellStyle = TextStyle(
      fontSize: 16,
      color: darkPink,
      fontWeight: FontWeight.w500,
    );
    final tableBg = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border, width: 2),
    );

    final table = Container(
      decoration: tableBg,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: pink,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text('Guias CYC',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white)),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                      child: Text('Fecha',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white))),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                      child: Text('Hora',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white))),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, idx) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: TextField(
                            controller: _rows[idx][0],
                            focusNode: idx == 0 ? _firstFocus : null,
                            maxLength: 40,
                            style: cellStyle,
                            decoration: InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              hintText: 'Escanea o ingresa guía',
                              hintStyle:
                                  TextStyle(color: pink.withOpacity(0.5)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                            ),
                            onSubmitted: (_) => _onGuiaSubmitted(idx),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(40),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: TextField(
                            controller: _rows[idx][1],
                            style: cellStyle,
                            readOnly: true,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Fecha',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: TextField(
                            controller: _rows[idx][2],
                            style: cellStyle,
                            readOnly: true,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Hora',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    final content = isMobile
        ? Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: pink,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guias CYC',
                      style: titleStyle.copyWith(color: Colors.white)),
                  Text('Usuario:  ${widget.usuario}',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
              centerTitle: false,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(child: table),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkPink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _guardar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : Container(
            color: bg,
            child: Center(
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 1100, maxHeight: 700),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: pink.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping, color: darkPink, size: 36),
                        const SizedBox(width: 12),
                        Text('Guias CYC', style: titleStyle),
                        const SizedBox(width: 24),
                        Text('Usuario:  ${widget.usuario}',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black87)),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkPink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 28),
                            textStyle: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _guardar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(child: table),
                  ],
                ),
              ),
            ),
          );
    return content;
  }
}
