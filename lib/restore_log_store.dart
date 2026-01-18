import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RestoreLogEntry {
  final String timestampIso;
  final String fromBackupTimestampIso;
  final bool ok;
  final String restoredWhat; // "license,settings,pacientes,citas" etc
  final int pacientesCount;
  final int citasCount;
  final String message; // error o resumen

  RestoreLogEntry({
    required this.timestampIso,
    required this.fromBackupTimestampIso,
    required this.ok,
    required this.restoredWhat,
    required this.pacientesCount,
    required this.citasCount,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'timestampIso': timestampIso,
        'fromBackupTimestampIso': fromBackupTimestampIso,
        'ok': ok,
        'restoredWhat': restoredWhat,
        'pacientesCount': pacientesCount,
        'citasCount': citasCount,
        'message': message,
      };

  factory RestoreLogEntry.fromJson(Map<String, dynamic> json) => RestoreLogEntry(
        timestampIso: (json['timestampIso'] ?? '').toString(),
        fromBackupTimestampIso: (json['fromBackupTimestampIso'] ?? '').toString(),
        ok: json['ok'] == true,
        restoredWhat: (json['restoredWhat'] ?? '').toString(),
        pacientesCount: (json['pacientesCount'] is int)
            ? json['pacientesCount'] as int
            : int.tryParse('${json['pacientesCount']}') ?? 0,
        citasCount: (json['citasCount'] is int)
            ? json['citasCount'] as int
            : int.tryParse('${json['citasCount']}') ?? 0,
        message: (json['message'] ?? '').toString(),
      );
}

class RestoreLogStore {
  static const _key = 'restore_log_v1';

  static Future<List<RestoreLogEntry>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<dynamic>()
            .map((e) => RestoreLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        // newest first
        return list.reversed.toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(RestoreLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await cargar();
    final list = [entry, ...current]; // newest first
    final trimmed = list.take(50).toList(); // límite
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}