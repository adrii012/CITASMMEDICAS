// lib/auth_store.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStore {
  static const _kCurrentClinicId = 'auth_current_clinic_id_v2';
  static const _kCurrentUserId = 'auth_current_user_id_v2';
  static const _kCurrentUserRole = 'auth_current_user_role_v2';

  static final ValueNotifier<String?> clinicId = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> userId = ValueNotifier<String?>(null);
  static final ValueNotifier<String> role = ValueNotifier<String>('staff');
  static final ValueNotifier<bool> isLogged = ValueNotifier<bool>(false);

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    clinicId.value = prefs.getString(_kCurrentClinicId);
    userId.value = prefs.getString(_kCurrentUserId);
    role.value = prefs.getString(_kCurrentUserRole) ?? 'staff';
    isLogged.value = (clinicId.value != null && userId.value != null);
  }

  static Future<void> login({
    required String clinicIdValue,
    required String userIdValue,
    required String roleValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentClinicId, clinicIdValue);
    await prefs.setString(_kCurrentUserId, userIdValue);
    await prefs.setString(_kCurrentUserRole, roleValue);

    clinicId.value = clinicIdValue;
    userId.value = userIdValue;
    role.value = roleValue;
    isLogged.value = true;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentClinicId);
    await prefs.remove(_kCurrentUserId);
    await prefs.remove(_kCurrentUserRole);

    clinicId.value = null;
    userId.value = null;
    role.value = 'staff';
    isLogged.value = false;
  }

  static bool get isAdmin => role.value == 'admin';

  static String requireClinicId() {
    final id = clinicId.value;
    if (id == null || id.trim().isEmpty) {
      throw Exception('No hay clínica activa');
    }
    return id.trim();
  }

  /// ✅ si falta, usa fallback (ej. "clinic_demo")
  static String requireClinicIdOr(String fallback) {
    final id = clinicId.value;
    if (id == null || id.trim().isEmpty) return fallback.trim();
    return id.trim();
  }

  static String requireUserId() {
    final id = userId.value;
    if (id == null || id.trim().isEmpty) {
      throw Exception('No hay usuario activo');
    }
    return id.trim();
  }
}