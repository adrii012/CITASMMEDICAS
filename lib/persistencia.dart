import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'citas_store.dart';

class PersistenciaCitas {
  static const _key = 'citas_guardadas_v1';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);

    if (data == null || data.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(data);
      if (decoded is List) {
        CitasStore.citas
          ..clear()
          ..addAll(decoded.map((e) => Cita.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (_) {
      // no crashear
    }
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final list = CitasStore.citas.map((c) => c.toJson()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    CitasStore.citas.clear();
  }
}