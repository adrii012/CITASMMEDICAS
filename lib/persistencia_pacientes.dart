// lib/persistencia_pacientes.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'pacientes_store.dart';
import 'paciente.dart';
import 'auth_store.dart';

class PersistenciaPacientes {
  // ✅ cada usuario tiene sus propios pacientes dentro de la clínica
  static const bool separarPorUsuario = true;

  static String _keyFor(String clinicId, String? userId) {
    if (separarPorUsuario) {
      final uid = (userId == null || userId.trim().isEmpty) ? 'anon' : userId.trim();
      return 'pacientes_guardados_v2_${clinicId}_$uid';
    }
    return 'pacientes_guardados_v2_$clinicId';
  }

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final uid = AuthStore.userId.value;

    final data = prefs.getString(_keyFor(clinicId, uid));

    if (data == null || data.trim().isEmpty) {
      PacientesStore.pacientes.clear();
      return;
    }

    try {
      final decoded = jsonDecode(data);
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
    final uid = AuthStore.userId.value;

    final list = PacientesStore.pacientes.map((p) => p.toJson()).toList();
    await prefs.setString(_keyFor(clinicId, uid), jsonEncode(list));
  }

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final clinicId = AuthStore.requireClinicId();
    final uid = AuthStore.userId.value;

    await prefs.remove(_keyFor(clinicId, uid));
    PacientesStore.pacientes.clear();
  }

  static Future<void> recargarPorSesionActual() async {
    await cargar();
  }
}