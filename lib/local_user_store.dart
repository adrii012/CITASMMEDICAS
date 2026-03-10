// lib/local_user_store.dart
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class LocalUser {
  final String uid;
  final String email;
  final String role; // admin | staff
  final bool active;

  LocalUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.active,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'role': role,
        'active': active,
      };

  static LocalUser fromJson(Map<String, dynamic> j) => LocalUser(
        uid: (j['uid'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? 'staff').toString(),
        active: (j['active'] ?? true) == true,
      );
}

class _UserRecord {
  final LocalUser user;
  final String passHash; // hash simple (para demo/local)

  _UserRecord({required this.user, required this.passHash});

  Map<String, dynamic> toJson() => {
        ...user.toJson(),
        'passHash': passHash,
      };

  static _UserRecord fromJson(Map<String, dynamic> j) => _UserRecord(
        user: LocalUser.fromJson(j),
        passHash: (j['passHash'] ?? '').toString(),
      );
}

class LocalUserStore {
  static String _kClinicMeta(String clinicId) => 'local_clinic_meta_$clinicId';
  static String _kUsers(String clinicId) => 'local_users_$clinicId';

  static String _hash(String input) {
    // ⚠️ Hash simple para demo/local.
    // Para producción real: esto NO es suficiente contra ataques, pero para tu caso (sin servidor) cumple.
    var h = 2166136261;
    for (final c in input.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String _uid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _normEmail(String e) => e.trim().toLowerCase();

  static Future<void> ensureClinicLocal({
    required String clinicId,
    required String clinicName,
    required String ownerEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _kClinicMeta(clinicId);

    if ((prefs.getString(key) ?? '').trim().isNotEmpty) return;

    final meta = {
      'clinicId': clinicId.trim(),
      'clinicName': clinicName.trim(),
      'ownerEmail': ownerEmail.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(key, jsonEncode(meta));
  }

  static Future<Map<String, dynamic>?> getClinicMeta(String clinicId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kClinicMeta(clinicId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<List<_UserRecord>> _loadUsers(String clinicId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsers(clinicId));
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((m) => _UserRecord.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<void> _saveUsers(String clinicId, List<_UserRecord> users) async {
    final prefs = await SharedPreferences.getInstance();
    final list = users.map((u) => u.toJson()).toList();
    await prefs.setString(_kUsers(clinicId), jsonEncode(list));
  }

  static int _countAdmins(List<_UserRecord> users) {
    return users.where((r) => r.user.role == 'admin' && r.user.active).length;
  }

  // =========================
  // LOGIN / CREAR ADMIN
  // =========================

  static Future<LocalUser> createOrValidateAdmin({
    required String clinicId,
    required String email,
    required String password,
  }) async {
    final cid = clinicId.trim();
    final em = _normEmail(email);

    if (cid.isEmpty) throw Exception('Clinic ID vacío');
    if (em.isEmpty) throw Exception('Email vacío');
    if (password.isEmpty) throw Exception('Contraseña vacía');

    final users = await _loadUsers(cid);

    final existing =
        users.where((u) => _normEmail(u.user.email) == em).toList();

    if (existing.isNotEmpty) {
      final rec = existing.first;
      if (rec.passHash != _hash(password)) {
        throw Exception('Contraseña incorrecta');
      }
      if (!rec.user.active) throw Exception('Usuario desactivado');
      return rec.user;
    }

    // Crear admin si no existe
    final user = LocalUser(
      uid: _uid(),
      email: em,
      role: 'admin',
      active: true,
    );

    users.add(_UserRecord(user: user, passHash: _hash(password)));
    await _saveUsers(cid, users);
    return user;
  }

  static Future<LocalUser> signIn({
    required String clinicId,
    required String email,
    required String password,
  }) async {
    final cid = clinicId.trim();
    final em = _normEmail(email);

    if (cid.isEmpty) throw Exception('Clinic ID vacío');
    if (em.isEmpty) throw Exception('Email vacío');
    if (password.isEmpty) throw Exception('Contraseña vacía');

    final users = await _loadUsers(cid);

    final rec = users.firstWhere(
      (u) => _normEmail(u.user.email) == em,
      orElse: () => throw Exception('Usuario no encontrado en esta clínica'),
    );

    if (rec.passHash != _hash(password)) {
      throw Exception('Contraseña incorrecta');
    }

    if (!rec.user.active) {
      throw Exception('Usuario desactivado');
    }

    return rec.user;
  }

  // =========================
  // ADMIN CONTROL (TU CONTROL TOTAL)
  // =========================

  static Future<List<LocalUser>> listUsers(String clinicId) async {
    final users = await _loadUsers(clinicId.trim());
    // Orden: admins primero, luego staff, luego por email
    users.sort((a, b) {
      final ra = a.user.role == 'admin' ? 0 : 1;
      final rb = b.user.role == 'admin' ? 0 : 1;
      if (ra != rb) return ra.compareTo(rb);
      return a.user.email.toLowerCase().compareTo(b.user.email.toLowerCase());
    });
    return users.map((r) => r.user).toList();
  }

  static Future<LocalUser> createStaffUser({
    required String clinicId,
    required String email,
    required String tempPassword,
    bool active = true,
  }) async {
    final cid = clinicId.trim();
    final em = _normEmail(email);

    if (cid.isEmpty) throw Exception('Clinic ID vacío');
    if (em.isEmpty) throw Exception('Email vacío');
    if (tempPassword.isEmpty) throw Exception('Contraseña vacía');

    final users = await _loadUsers(cid);

    final exists = users.any((u) => _normEmail(u.user.email) == em);
    if (exists) throw Exception('Ya existe un usuario con ese correo');

    final user = LocalUser(
      uid: _uid(),
      email: em,
      role: 'staff',
      active: active,
    );

    users.add(_UserRecord(user: user, passHash: _hash(tempPassword)));
    await _saveUsers(cid, users);
    return user;
  }

  static Future<void> resetPasswordByEmail({
    required String clinicId,
    required String email,
    required String newPassword,
  }) async {
    final cid = clinicId.trim();
    final em = _normEmail(email);
    if (newPassword.isEmpty) throw Exception('Nueva contraseña vacía');

    final users = await _loadUsers(cid);
    final idx = users.indexWhere((u) => _normEmail(u.user.email) == em);
    if (idx < 0) throw Exception('Usuario no encontrado');

    final old = users[idx];
    users[idx] = _UserRecord(user: old.user, passHash: _hash(newPassword));
    await _saveUsers(cid, users);
  }

  static Future<void> setActiveByEmail({
    required String clinicId,
    required String email,
    required bool active,
  }) async {
    final cid = clinicId.trim();
    final em = _normEmail(email);

    final users = await _loadUsers(cid);
    final idx = users.indexWhere((u) => _normEmail(u.user.email) == em);
    if (idx < 0) throw Exception('Usuario no encontrado');

    final rec = users[idx];

    // Protección: no desactivar al último admin activo
    if (!active && rec.user.role == 'admin') {
      final admins = _countAdmins(users);
      if (admins <= 1) {
        throw Exception('No puedes desactivar al último admin');
      }
    }

    users[idx] = _UserRecord(
      user: LocalUser(
        uid: rec.user.uid,
        email: rec.user.email,
        role: rec.user.role,
        active: active,
      ),
      passHash: rec.passHash,
    );

    await _saveUsers(cid, users);
  }

  static Future<void> setRoleByEmail({
    required String clinicId,
    required String email,
    required String role, // admin|staff
  }) async {
    final cid = clinicId.trim();
    final em = _normEmail(email);
    final newRole = role.trim();

    if (newRole != 'admin' && newRole != 'staff') {
      throw Exception('Rol inválido: $newRole');
    }

    final users = await _loadUsers(cid);
    final idx = users.indexWhere((u) => _normEmail(u.user.email) == em);
    if (idx < 0) throw Exception('Usuario no encontrado');

    final rec = users[idx];

    // Protección: no quitar admin al último admin activo
    if (rec.user.role == 'admin' && newRole != 'admin' && rec.user.active) {
      final admins = _countAdmins(users);
      if (admins <= 1) throw Exception('No puedes quitar el último admin');
    }

    users[idx] = _UserRecord(
      user: LocalUser(
        uid: rec.user.uid,
        email: rec.user.email,
        role: newRole,
        active: rec.user.active,
      ),
      passHash: rec.passHash,
    );

    await _saveUsers(cid, users);
  }

  static Future<void> deleteUserByEmail({
    required String clinicId,
    required String email,
  }) async {
    final cid = clinicId.trim();
    final em = _normEmail(email);

    final users = await _loadUsers(cid);
    final idx = users.indexWhere((u) => _normEmail(u.user.email) == em);
    if (idx < 0) throw Exception('Usuario no encontrado');

    final rec = users[idx];

    // Protección: no borrar al último admin activo
    if (rec.user.role == 'admin' && rec.user.active) {
      final admins = _countAdmins(users);
      if (admins <= 1) throw Exception('No puedes borrar al último admin');
    }

    users.removeAt(idx);
    await _saveUsers(cid, users);
  }

  // =========================
  // UTIL: DEBUG / LIMPIEZA
  // =========================

  static Future<void> wipeClinicLocal(String clinicId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kClinicMeta(clinicId.trim()));
    await prefs.remove(_kUsers(clinicId.trim()));
  }
}