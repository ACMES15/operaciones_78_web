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
    return HistorialTfRetorno(
      id: id,
      tfOdev: map['TF O DEV']?.toString() ?? '-',
      origen: map['ORIGEN']?.toString() ?? '-',
      retorno: map['RETORNO'] == true,
      valido: map['VALIDO']?.toString() ?? '-',
      entrego: map['ENTREGO']?.toString() ?? '-',
      observaciones: map['OBSERVACIONES']?.toString(),
      fecha: map['FECHA'] != null
          ? DateTime.tryParse(map['FECHA'].toString())
          : null,
    );
  }
}
