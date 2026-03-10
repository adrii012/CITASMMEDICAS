// lib/persistencia.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';
import 'citas_store.dart';

class PersistenciaCitas {
  static String _keyFor(String clinicId) => 'citas_cache_v5_$clinicId';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();

    final raw = prefs.getString(_keyFor(clinicId));
    if (raw == null || raw.trim().isEmpty) {
      CitasStore.citas.clear();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        CitasStore.citas
          ..clear()
          ..addAll(
            decoded.map((e) => Cita.fromJson(Map<String, dynamic>.from(e))),
          );
      } else {
        CitasStore.citas.clear();
      }
    } catch (_) {
      CitasStore.citas.clear();
    }
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final list = CitasStore.citas.map((c) => c.toJson()).toList();
    await prefs.setString(_keyFor(clinicId), jsonEncode(list));
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    await prefs.remove(_keyFor(clinicId));
    CitasStore.citas.clear();
  }

  static Future<void> recargarPorSesionActual() async => cargar();
}