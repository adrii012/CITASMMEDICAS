// lib/persistencia_almacen.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';
import 'almacen_store.dart';
import 'almacen_item.dart';

class PersistenciaAlmacen {
  static String _keyFor(String clinicId) => 'almacen_cache_v5_$clinicId';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();

    final raw = prefs.getString(_keyFor(clinicId));
    if (raw == null || raw.trim().isEmpty) {
      AlmacenStore.clear();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        AlmacenStore.items
          ..clear()
          ..addAll(
            decoded.map((e) => AlmacenItem.fromJson(Map<String, dynamic>.from(e))),
          );
        AlmacenStore.recomputeLowStock();
      } else {
        AlmacenStore.clear();
      }
    } catch (_) {
      AlmacenStore.clear();
    }
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();

    final list = AlmacenStore.items.map((x) => x.toJson()).toList();
    await prefs.setString(_keyFor(clinicId), jsonEncode(list));
    AlmacenStore.recomputeLowStock();
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    await prefs.remove(_keyFor(clinicId));
    AlmacenStore.clear();
  }
}