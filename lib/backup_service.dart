import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'settings_store.dart';
import 'citas_store.dart';
import 'pacientes_store.dart';
import 'paciente.dart';

import 'persistencia.dart';
import 'persistencia_pacientes.dart';

import 'restore_log_store.dart';
import 'license_store.dart';

class RestoreResult {
  final bool ok;
  final String backupTimestampIso;
  final int pacientesCount;
  final int citasCount;
  final String restoredWhat;
  final String message;

  RestoreResult({
    required this.ok,
    required this.backupTimestampIso,
    required this.pacientesCount,
    required this.citasCount,
    required this.restoredWhat,
    required this.message,
  });
}

class BackupService {
  static Future<Map<String, dynamic>> _buildBackup() async {
    return {
      'version': 2,
      'timestamp': DateTime.now().toIso8601String(),
      'settings': SettingsStore.snapshot(),
      'license': await LicenseStore.getBackupSnapshot(),
      'pacientes': PacientesStore.pacientes.map((p) => p.toJson()).toList(),
      'citas': CitasStore.citas.map((c) => c.toJson()).toList(),
    };
  }

  /// ✅ Para UI: obtener JSON formateado (para copiar/pegar)
  static Future<String> buildBackupJsonPretty() async {
    final backup = await _buildBackup();
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// ✅ Guardar backup como archivo (ideal en PC)
  static Future<File> saveBackupFile() async {
    final jsonStr = await buildBackupJsonPretty();

    Directory dir;
    try {
      dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final file = File('${dir.path}/backup_citas_medicas_$ts.json');
    await file.writeAsString(jsonStr);
    return file;
  }

  /// ✅ Compartir (Android/iOS). En PC puede no mostrar nada.
  static Future<void> shareBackup(BuildContext context) async {
    final backup = await _buildBackup();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/backup_citas_medicas.json');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Respaldo de Citas Médicas',
    );
  }

  /// ✅ Copiar JSON al portapapeles (perfecto para PC)
  static Future<void> copyBackupJsonToClipboard() async {
    final jsonStr = await buildBackupJsonPretty();
    await Clipboard.setData(ClipboardData(text: jsonStr));
  }

  static Future<RestoreResult> restoreFromJsonString(
    BuildContext context,
    String jsonStr, {
    bool restoreLicense = true,
    bool restoreSettings = true,
    bool restorePacientes = true,
    bool restoreCitas = true,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    if (jsonStr.trim().isEmpty) {
      final res = RestoreResult(
        ok: false,
        backupTimestampIso: '',
        pacientesCount: 0,
        citasCount: 0,
        restoredWhat: '',
        message: 'El JSON está vacío',
      );

      await RestoreLogStore.add(
        RestoreLogEntry(
          timestampIso: nowIso,
          fromBackupTimestampIso: '',
          ok: false,
          restoredWhat: '',
          pacientesCount: 0,
          citasCount: 0,
          message: res.message,
        ),
      );

      throw Exception(res.message);
    }

    String backupTs = '';

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) throw Exception('JSON inválido (no es objeto)');

      final data = Map<String, dynamic>.from(decoded);
      backupTs = (data['timestamp'] ?? '').toString();

      int pacientesRest = 0;
      int citasRest = 0;

      if (restoreLicense && data['license'] is Map) {
        await LicenseStore.applySnapshot(
          Map<String, dynamic>.from(data['license'] as Map),
        );
      }

      if (restoreSettings && data['settings'] is Map) {
        await SettingsStore.applySnapshot(
          Map<String, dynamic>.from(data['settings'] as Map),
        );
      }

      if (restorePacientes) {
        PacientesStore.pacientes.clear();
        final raw = data['pacientes'];
        if (raw is List) {
          for (final p in raw) {
            if (p is Map) {
              PacientesStore.pacientes.add(
                Paciente.fromJson(Map<String, dynamic>.from(p)),
              );
            }
          }
        }
        pacientesRest = PacientesStore.pacientes.length;
        await PersistenciaPacientes.guardar();
      }

      if (restoreCitas) {
        CitasStore.citas.clear();
        final raw = data['citas'];
        if (raw is List) {
          for (final c in raw) {
            if (c is Map) {
              CitasStore.citas.add(
                Cita.fromJson(Map<String, dynamic>.from(c)),
              );
            }
          }
        }
        citasRest = CitasStore.citas.length;
        await PersistenciaCitas.guardar();
      }

      final restoredWhat = [
        if (restoreLicense) 'license',
        if (restoreSettings) 'settings',
        if (restorePacientes) 'pacientes',
        if (restoreCitas) 'citas',
      ].join(',');

      final res = RestoreResult(
        ok: true,
        backupTimestampIso: backupTs,
        pacientesCount: pacientesRest,
        citasCount: citasRest,
        restoredWhat: restoredWhat,
        message: 'Restauración exitosa',
      );

      await RestoreLogStore.add(
        RestoreLogEntry(
          timestampIso: nowIso,
          fromBackupTimestampIso: backupTs,
          ok: true,
          restoredWhat: restoredWhat,
          pacientesCount: pacientesRest,
          citasCount: citasRest,
          message: res.message,
        ),
      );

      return res;
    } catch (e) {
      final restoredWhat = [
        if (restoreLicense) 'license',
        if (restoreSettings) 'settings',
        if (restorePacientes) 'pacientes',
        if (restoreCitas) 'citas',
      ].join(',');

      await RestoreLogStore.add(
        RestoreLogEntry(
          timestampIso: nowIso,
          fromBackupTimestampIso: backupTs,
          ok: false,
          restoredWhat: restoredWhat,
          pacientesCount: 0,
          citasCount: 0,
          message: 'Error: $e',
        ),
      );

      rethrow;
    }
  }
}