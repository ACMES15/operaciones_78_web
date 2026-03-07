import 'package:shared_preferences/shared_preferences.dart';

class BienvenidaCache {
  static const String _key = 'bienvenida_mostrada';

  static Future<bool> fueMostrada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> marcarMostrada() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
