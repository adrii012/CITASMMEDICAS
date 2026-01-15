import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Horarios {
  static const _kInicio = 'horario_inicio_min';
  static const _kFin = 'horario_fin_min';

  // Default 09:00 a 18:00
  static int _inicioMin = 9 * 60;
  static int _finMin = 18 * 60;

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _inicioMin = prefs.getInt(_kInicio) ?? _inicioMin;
    _finMin = prefs.getInt(_kFin) ?? _finMin;
  }

  static Future<void> guardar(int inicioMin, int finMin) async {
    _inicioMin = inicioMin;
    _finMin = finMin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kInicio, _inicioMin);
    await prefs.setInt(_kFin, _finMin);
  }

  static TimeOfDay get inicio => _toTOD(_inicioMin);
  static TimeOfDay get fin => _toTOD(_finMin);

  static bool permite(TimeOfDay hora) {
    final m = hora.hour * 60 + hora.minute;
    return m >= _inicioMin && m <= _finMin;
  }

  static TimeOfDay _toTOD(int mins) => TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
}