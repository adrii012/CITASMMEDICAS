// lib/persistencia_historias.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';
import 'historias_store.dart';
import 'historia_clinica.dart';

class PersistenciaHistorias {
  static String _key(String clinicId, String userId) =>
      'historias_guardadas_v2_${clinicId}_$userId';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final userId = AuthStore.requireUserId();

    final raw = prefs.getString(_key(clinicId, userId));

    // ✅ IMPORTANTE: si no hay nada guardado, limpiar memoria para no mezclar sesiones
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
            decoded
                .whereType<Map>()
                .map((e) => HistoriaClinica.fromJson(
                      Map<String, dynamic>.from(e),
                    )),
          );
      } else {
        // ✅ si viene raro, limpia para evitar basura
        HistoriasStore.clear();
      }
    } catch (_) {
      // ✅ si el json está corrupto, no crashear y no mezclar
      HistoriasStore.clear();
    }
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final userId = AuthStore.requireUserId();

    final list = HistoriasStore.historias.map((h) => h.toJson()).toList();
    await prefs.setString(_key(clinicId, userId), jsonEncode(list));
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final userId = AuthStore.requireUserId();

    await prefs.remove(_key(clinicId, userId));
    HistoriasStore.clear();
  }
}