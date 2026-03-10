// lib/firestore_access_service.dart
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class ClinicUserInfo {
  final String role; // admin / staff
  final bool active;

  ClinicUserInfo({required this.role, required this.active});
}

/// ✅ Versión LOCAL (sin Firestore)
/// Guarda accesos por clínica en SharedPreferences.
/// Esto te da CONTROL TOTAL sin depender de Firebase.
class FirestoreAccessService {
  static String _kClinicDoc(String clinicId) => 'local_access_clinic_$clinicId';
  static String _kClinicUsers(String clinicId) => 'local_access_users_$clinicId';

  static String _uid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Future<Map<String, dynamic>?> _getClinic(String clinicId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kClinicDoc(clinicId));
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> _setClinic(String clinicId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClinicDoc(clinicId), jsonEncode(data));
  }

  static Future<List<Map<String, dynamic>>> _loadUsers(String clinicId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kClinicUsers(clinicId));
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static Future<void> _saveUsers(String clinicId, List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClinicUsers(clinicId), jsonEncode(users));
  }

  static int _idxByUid(List<Map<String, dynamic>> users, String uid) {
    for (var i = 0; i < users.length; i++) {
      if ((users[i]['uid'] ?? '').toString() == uid) return i;
    }
    return -1;
  }

  /// =========================
  /// CLÍNICAS
  /// =========================

  /// ✅ Crea la clínica si no existe y asegura al admin (LOCAL)
  static Future<void> ensureClinic({
    required String clinicId,
    required String clinicName,
    required String ownerUid,
    required String ownerEmail,
  }) async {
    final now = DateTime.now().toIso8601String();
    final clinic = await _getClinic(clinicId);

    if (clinic == null) {
      await _setClinic(clinicId, {
        'id': clinicId,
        'name': clinicName,
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail,
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      clinic['name'] = clinicName;
      clinic['updatedAt'] = now;
      await _setClinic(clinicId, clinic);
    }

    // asegurar admin en users
    final users = await _loadUsers(clinicId);
    final idx = _idxByUid(users, ownerUid);

    final adminData = <String, dynamic>{
      'uid': ownerUid,
      'email': ownerEmail,
      'role': 'admin',
      'active': true,
      'updatedAt': now,
    };

    if (idx == -1) {
      adminData['createdAt'] = now;
      users.add(adminData);
    } else {
      final prev = users[idx];
      adminData['createdAt'] = (prev['createdAt'] ?? now).toString();
      users[idx] = {...prev, ...adminData};
    }

    await _saveUsers(clinicId, users);
  }

  /// =========================
  /// USUARIOS / ROLES
  /// =========================

  /// ✅ Obtiene rol y estado del usuario dentro de una clínica (LOCAL)
  static Future<({String role, bool active})> getRoleForClinic({
    required String clinicId,
    required String uid,
  }) async {
    final users = await _loadUsers(clinicId);
    final idx = _idxByUid(users, uid);
    if (idx == -1) return (role: 'staff', active: false);

    final data = users[idx];
    final role = (data['role'] ?? 'staff').toString();
    final active = (data['active'] ?? false) == true;

    return (role: role, active: active);
  }

  /// ✅ Inserta o actualiza un usuario dentro de la clínica (LOCAL)
  ///
  /// Nota: aquí no guardo contraseña; eso va por tu sistema de login local.
  /// Esto sirve para "control total" de active/role.
  static Future<void> upsertClinicUser({
    required String clinicId,
    required String uid,
    required String email,
    required String role, // admin / staff
    bool active = true,
  }) async {
    final now = DateTime.now().toIso8601String();
    final users = await _loadUsers(clinicId);

    final idx = _idxByUid(users, uid);

    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'role': role,
      'active': active,
      'updatedAt': now,
    };

    if (idx == -1) {
      data['createdAt'] = now;
      users.add(data);
    } else {
      final prev = users[idx];
      data['createdAt'] = (prev['createdAt'] ?? now).toString();
      users[idx] = {...prev, ...data};
    }

    await _saveUsers(clinicId, users);
  }

  /// ✅ Verifica si el usuario pertenece a la clínica y está activo (LOCAL)
  static Future<bool> isActiveMember({
    required String clinicId,
    required String uid,
  }) async {
    final info = await getRoleForClinic(clinicId: clinicId, uid: uid);
    return info.active;
  }

  /// =========================
  /// UTILIDADES
  /// =========================

  /// ✅ Elimina completamente a un usuario de una clínica (LOCAL)
  static Future<void> removeUserFromClinic({
    required String clinicId,
    required String uid,
  }) async {
    final users = await _loadUsers(clinicId);
    users.removeWhere((u) => (u['uid'] ?? '').toString() == uid);
    await _saveUsers(clinicId, users);
  }

  /// ✅ Crear UID rápido (si quieres crear usuarios desde un panel)
  static String newUid() => _uid();

  /// ✅ Listar usuarios de clínica (para futuro panel admin)
  static Future<List<Map<String, dynamic>>> listClinicUsers(String clinicId) async {
    return _loadUsers(clinicId);
  }
}