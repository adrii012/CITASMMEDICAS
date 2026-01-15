import 'package:flutter/material.dart';

class Festivos {
  static final Map<String, String> _fijos = {
    '01-01': 'Año Nuevo',
    '02-05': 'Día de la Constitución',
    '03-21': 'Natalicio de Benito Juárez',
    '05-01': 'Día del Trabajo',
    '09-16': 'Independencia de México',
    '11-20': 'Revolución Mexicana',
    '12-25': 'Navidad',
  };

  static String _mmdd(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? nombreFestivo(DateTime d) => _fijos[_mmdd(d)];

  static bool esFestivo(DateTime d) => nombreFestivo(d) != null;

  static bool esDomingo(DateTime d) => d.weekday == DateTime.sunday;

  static bool estaBloqueado(DateTime d) => esFestivo(d) || esDomingo(d);

  static String motivoBloqueo(DateTime d) {
    final festivo = nombreFestivo(d);
    if (festivo != null) return 'Festivo: $festivo';
    if (esDomingo(d)) return 'Domingo (día no laborable)';
    return 'Día no disponible';
  }

  static DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  static Color colorBloqueo(DateTime d) {
    if (esFestivo(d)) return Colors.red;
    if (esDomingo(d)) return Colors.grey;
    return Colors.transparent;
  }
}