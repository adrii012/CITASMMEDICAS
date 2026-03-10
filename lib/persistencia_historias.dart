// lib/persistencia_historias.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';
import 'historias_store.dart';
import 'historia_clinica.dart';

class PersistenciaHistorias {
  static String _key(String clinicId) => 'historias_cache_v5_$clinicId';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();

    final raw = prefs.getString(_key(clinicId));
    if (raw == null || raw.trim().isEmpty) {
      HistoriasStore.clear();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        HistoriasStore.historias
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map((e) {
              return HistoriaClinica.fromJson(Map<String, dynamic>.from(e));
            }),
          );
      } else {
        HistoriasStore.clear();
      }
    } catch (_) {
      HistoriasStore.clear();
    }
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final list = HistoriasStore.historias.map((h) => h.toJson()).toList();
    await prefs.setString(_key(clinicId), jsonEncode(list));
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    await prefs.remove(_key(clinicId));
    HistoriasStore.clear();
  }
}