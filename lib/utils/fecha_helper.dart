import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Normaliza distintos formatos de fecha a DateTime.
DateTime? toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed;
  }
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'];
    final nanoseconds = value['_nanoseconds'] ?? 0;
    final millis = (seconds is num ? seconds.toInt() : 0) * 1000 +
        (nanoseconds is num ? (nanoseconds / 1000000).round() : 0);
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  return null;
}

/// Detecta la fecha de un registro probando múltiples campos.
DateTime? fechaRegistro(Map<String, dynamic> entrega,
    {List<String>? camposPersonalizados}) {
  final keysDefault = [
    'fechaFirma',
    'createdAt',
    'fecha',
    'timestamp',
    'fechaValidacion',
    'date',
  ];
  final keys = camposPersonalizados ?? keysDefault;

  for (final key in keys) {
    final dt = toDate(entrega[key]);
    if (dt != null) return dt;
  }
  return null;
}

/// Formatea una fecha a string legible: dd/mm/yyyy hh:mm
String formatearFecha(dynamic value) {
  final dt = toDate(value);
  if (dt == null) return '-';
  final local = dt.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min';
}

/// Widget uniforme para mostrar un campo con etiqueta y valor.
Widget campoUniforme(String label, dynamic value,
    {double? width, int maxLines = 2}) {
  return SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2D6A4F).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D6A4F),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value ?? '-'}',
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Ordena una lista por fecha descendente (más nuevo primero).
void ordenarPorFechaDescendente(List<Map<String, dynamic>> lista,
    {List<String>? camposPersonalizados}) {
  lista.sort((a, b) {
    final fechaA = fechaRegistro(a, camposPersonalizados: camposPersonalizados);
    final fechaB = fechaRegistro(b, camposPersonalizados: camposPersonalizados);
    if (fechaA == null && fechaB == null) return 0;
    if (fechaA == null) return 1;
    if (fechaB == null) return -1;
    return fechaB.compareTo(fechaA);
  });
}
