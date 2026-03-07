class HojaDeXDHistorial {
  final String usuario;
  final DateTime fecha;
  final Map<String, String> datos;
  final String fileName;

  HojaDeXDHistorial({
    required this.usuario,
    required this.fecha,
    required this.datos,
    required this.fileName,
  });

  Map<String, dynamic> toJson() => {
        'usuario': usuario,
        'fecha': fecha.toIso8601String(),
        'datos': datos,
        'fileName': fileName,
      };

  static HojaDeXDHistorial fromJson(Map<String, dynamic> json) =>
      HojaDeXDHistorial(
        usuario: json['usuario'],
        fecha: DateTime.parse(json['fecha']),
        datos: Map<String, String>.from(json['datos']),
        fileName: json['fileName'],
      );
}
