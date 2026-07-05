import 'package:flutter/material.dart';
import 'user_control_page.dart';

class InventariosPage extends StatelessWidget {
  final String usuario;
  const InventariosPage({Key? key, required this.usuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Reuse the user control view for Inventarios. The page accepts the
    // `usuario` argument so HomePage can pass it; the control widget itself
    // manages its own data via Firestore.
    return UserControlPageBody();
  }
}
