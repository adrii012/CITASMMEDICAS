import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'access_guard.dart';
import 'fire_clinic_users.dart';

class AuthStore {
  static const _kCurrentClinicId = 'auth_current_clinic_id_v3';
  static const _kCurrentUid = 'auth_current_uid_v3';
  static const _kCurrentUserRole = 'auth_current_user_role_v3';
  static const _kCurrentEmail = 'auth_current_email_v3';

  static final ValueNotifier<String?> clinicId = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> uid = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> email = ValueNotifier<String?>(null);
  static final ValueNotifier<String> role = ValueNotifier<String>('staff');
  static final ValueNotifier<bool> isLogged = ValueNotifier<bool>(false);

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    clinicId.value = prefs.getString(_kCurrentClinicId);
    uid.value = prefs.getString(_kCurrentUid);
    role.value = prefs.getString(_kCurrentUserRole) ?? 'staff';
    email.value = prefs.getString(_kCurrentEmail);
    isLogged.value = (clinicId.value != null && uid.value != null);

    if (isLogged.value) {
      await AccessGuard.start();
    }
  }

  static Future<void> login({
    required String clinicIdValue,
    required String uidValue,
    required String roleValue,
    String? emailValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentClinicId, clinicIdValue);
    await prefs.setString(_kCurrentUid, uidValue);
    await prefs.setString(_kCurrentUserRole, roleValue);
    if (emailValue != null) {
      await prefs.setString(_kCurrentEmail, emailValue);
    }

    clinicId.value = clinicIdValue;
    uid.value = uidValue;
    role.value = roleValue;
    email.value = emailValue ?? email.value;
    isLogged.value = true;

    await AccessGuard.start();
  }

  /// logout normal: cierra FirebaseAuth + limpia prefs
  /// logout(localOnly:true): solo limpia prefs (se usa desde AccessGuard después del signOut)
  static Future<void> logout({bool localOnly = false}) async {
    await AccessGuard.stop();

    // ✅ NUEVO: quitar token FCM del usuario
    try {
      final currentClinicId = clinicId.value;
      final currentUid = uid.value;
      final token = await FirebaseMessaging.instance.getToken();

      if (currentClinicId != null &&
          currentUid != null &&
          token != null &&
          token.trim().isNotEmpty) {
        await FireClinicUsers.removeFcmToken(
          clinicId: currentClinicId,
          uid: currentUid,
          token: token,
        );
      }
    } catch (_) {}

    if (!localOnly) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentClinicId);
    await prefs.remove(_kCurrentUid);
    await prefs.remove(_kCurrentUserRole);
    await prefs.remove(_kCurrentEmail);

    clinicId.value = null;
    uid.value = null;
    email.value = null;
    role.value = 'staff';
    isLogged.value = false;
  }

  static bool get isAdmin => role.value == 'admin';

  static String requireClinicId() {
    final id = clinicId.value?.trim();
    if (id == null || id.isEmpty) throw Exception('No hay clínica activa');
    return id;
  }

  static String requireUid() {
    final id = uid.value?.trim();
    if (id == null || id.isEmpty) throw Exception('No hay usuario activo (UID)');
    return id;
  }
}