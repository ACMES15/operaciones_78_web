class HistorialTfRetorno {
  final String id;
  final String tfOdev;
  final String origen;
  final bool retorno;
  final String valido;
  final String entrego;
  final String? observaciones;
  final DateTime? fecha;

  HistorialTfRetorno({
    required this.id,
    required this.tfOdev,
    required this.origen,
    required this.retorno,
    required this.valido,
    required this.entrego,
    this.observaciones,
    this.fecha,
  });

  factory HistorialTfRetorno.fromMap(Map<String, dynamic> map, String id) {
    // Aceptar RETORNO como bool, string 'true'/'false', o numérico
    bool retornoParsed = false;
    final rawRetorno = map['RETORNO'];
    if (rawRetorno is bool) {
      retornoParsed = rawRetorno;
    } else if (rawRetorno is String) {
      retornoParsed = rawRetorno.trim().toLowerCase() == 'true';
    } else if (rawRetorno is num) {
      retornoParsed = rawRetorno != 0;
    }
    return HistorialTfRetorno(
      id: id,
      tfOdev: map['TF O DEV']?.toString() ?? '-',
      origen: map['ORIGEN']?.toString() ?? '-',
      retorno: retornoParsed,
      valido: map['VALIDO']?.toString() ?? '-',
      entrego: map['ENTREGO']?.toString() ?? '-',
      observaciones: map['OBSERVACIONES']?.toString(),
      fecha: map['FECHA'] != null
          ? DateTime.tryParse(map['FECHA'].toString())
          : null,
    );
  }
}
