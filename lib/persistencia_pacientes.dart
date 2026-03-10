// lib/persistencia_pacientes.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'pacientes_store.dart';
import 'paciente.dart';
import 'auth_store.dart';

class PersistenciaPacientes {
  static String _keyFor(String clinicId) => 'pacientes_cache_v5_$clinicId';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();

    final raw = prefs.getString(_keyFor(clinicId));
    if (raw == null || raw.trim().isEmpty) {
      PacientesStore.pacientes.clear();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        PacientesStore.pacientes
          ..clear()
          ..addAll(
            decoded.map((e) => Paciente.fromJson(Map<String, dynamic>.from(e))),
          );
      } else {
        PacientesStore.pacientes.clear();
      }
    } catch (_) {
      PacientesStore.pacientes.clear();
    }
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final list = PacientesStore.pacientes.map((p) => p.toJson()).toList();
    await prefs.setString(_keyFor(clinicId), jsonEncode(list));
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    await prefs.remove(_keyFor(clinicId));
    PacientesStore.pacientes.clear();
  }

  static Future<void> recargarPorSesionActual() async => cargar();
}