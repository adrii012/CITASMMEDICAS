import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'pacientes_store.dart';
import 'paciente.dart';

class PersistenciaPacientes {
  static const _key = 'pacientes_guardados_v1';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);

    if (data == null || data.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(data);
      if (decoded is List) {
        PacientesStore.pacientes
          ..clear()
          ..addAll(decoded.map((e) => Paciente.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (_) {
      // no crashear
    }
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final list = PacientesStore.pacientes.map((p) => p.toJson()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    PacientesStore.pacientes.clear();
  }
}