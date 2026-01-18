// lib/clinic_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class ClinicUser {
  final String id;
  final String username; // sin espacios
  final String passHash; // sha256(salt+pass)
  final String salt;
  final String role; // "admin" / "staff"

  ClinicUser({
    required this.id,
    required this.username,
    required this.passHash,
    required this.salt,
    this.role = 'staff',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'passHash': passHash,
    'salt': salt,
    'role': role,
  };

  factory ClinicUser.fromJson(Map<String, dynamic> j) => ClinicUser(
    id: (j['id'] ?? '').toString(),
    username: (j['username'] ?? '').toString(),
    passHash: (j['passHash'] ?? '').toString(),
    salt: (j['salt'] ?? '').toString(),
    role: (j['role'] ?? 'staff').toString(),
  );
}

class Clinic {
  final String id;
  final String name;
  final List<ClinicUser> users;

  Clinic({
    required this.id,
    required this.name,
    required this.users,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'users': users.map((u) => u.toJson()).toList(),
  };

  factory Clinic.fromJson(Map<String, dynamic> j) => Clinic(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    users: (j['users'] is List)
        ? (j['users'] as List)
            .whereType<Map>()
            .map((e) => ClinicUser.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : [],
  );
}

class ClinicStore {
  static const _kClinics = 'clinics_v1';

  static Future<List<Clinic>> cargarClinics() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kClinics);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Clinic.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardarClinics(List<Clinic> clinics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kClinics,
      jsonEncode(clinics.map((c) => c.toJson()).toList()),
    );
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static String makeSalt() {
    // simple salt (suficiente para local dev)
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    return _sha256(now).substring(0, 16);
  }

  static ClinicUser createUser({
    required String id,
    required String username,
    required String password,
    String role = 'staff',
  }) {
    final salt = makeSalt();
    final hash = _sha256('$salt$password');
    return ClinicUser(id: id, username: username.trim(), passHash: hash, salt: salt, role: role);
  }

  static bool verifyUser(ClinicUser u, String password) {
    final hash = _sha256('${u.salt}${password}');
    return hash == u.passHash;
  }
}