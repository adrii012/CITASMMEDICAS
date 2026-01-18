// lib/license_store.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseStore {
  static const _kFirstRun = 'lic_first_run_v1';
  static const _kUnlocked = 'lic_unlocked_v1';
  static const _kTrialDays = 'lic_trial_days_v1';

  // ✅ info remota opcional (cache UI)
  static const _kRemoteReason = 'lic_remote_reason_v1';
  static const _kRemotePlan = 'lic_remote_plan_v1';
  static const _kRemoteExpiryIso = 'lic_remote_expiry_iso_v1';

  // ✅ NUEVO: bloqueo forzado por remoto (gana siempre)
  static const _kForceLocked = 'lic_force_locked_v1';
  static const _kForceReason = 'lic_force_reason_v1';

  static const int defaultTrialDays = 7;

  static final ValueNotifier<bool> isLocked = ValueNotifier<bool>(false);
  static final ValueNotifier<int> daysLeft = ValueNotifier<int>(0);
  static final ValueNotifier<String> reason =
      ValueNotifier<String>('Sin licencia');

  // ✅ info remota para mostrar (opcional)
  static final ValueNotifier<String> remotePlan = ValueNotifier<String>('free');
  static final ValueNotifier<String> remoteExpiryIso =
      ValueNotifier<String>('');

  // ✅ NUEVO: estado de bloqueo forzado
  static final ValueNotifier<bool> forceLocked = ValueNotifier<bool>(false);

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();

    // cargar info remota guardada
    remotePlan.value = prefs.getString(_kRemotePlan) ?? 'free';
    remoteExpiryIso.value = prefs.getString(_kRemoteExpiryIso) ?? '';
    final remoteReason = prefs.getString(_kRemoteReason);

    // ✅ NUEVO: leer bloqueo forzado
    final forced = prefs.getBool(_kForceLocked) ?? false;
    final forcedReason = prefs.getString(_kForceReason) ?? '';
    forceLocked.value = forced;

    final trialDays = prefs.getInt(_kTrialDays) ?? defaultTrialDays;

    var first = prefs.getString(_kFirstRun);
    if (first == null) {
      first = DateTime.now().toIso8601String();
      await prefs.setString(_kFirstRun, first);
      await prefs.setInt(_kTrialDays, trialDays);
    }

    final unlocked = prefs.getBool(_kUnlocked) ?? false;

    // ✅ NUEVO: si remoto forzó bloqueo -> SIEMPRE bloquea (aunque haya trial)
    if (forced) {
      isLocked.value = true;
      daysLeft.value = 0;
      reason.value =
          forcedReason.trim().isNotEmpty ? forcedReason.trim() : 'Acceso suspendido';
      return;
    }

    if (unlocked) {
      isLocked.value = false;
      daysLeft.value = 9999;

      // si hay motivo remoto, úsalo
      reason.value = (remoteReason != null && remoteReason.trim().isNotEmpty)
          ? remoteReason.trim()
          : 'Licencia activa';
      return;
    }

    final firstRunDate = DateTime.tryParse(first) ?? DateTime.now();
    final diff = DateTime.now().difference(firstRunDate).inDays;
    final left = (trialDays - diff);

    daysLeft.value = left < 0 ? 0 : left;
    isLocked.value = left <= 0;

    reason.value = isLocked.value
        ? 'Trial vencido'
        : 'Trial activo (${daysLeft.value} día(s) restante(s))';
  }

  static Future<void> validar() async {
    await cargar();
  }

  static Future<void> setUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUnlocked, value);

    // ✅ NUEVO: si se desbloquea por licencia válida, quitamos bloqueo forzado
    if (value == true) {
      await prefs.setBool(_kForceLocked, false);
      await prefs.remove(_kForceReason);
      forceLocked.value = false;
    }

    await cargar();
  }

  static Future<void> setTrialDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTrialDays, days);
    await cargar();
  }

  static Future<void> resetTrial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFirstRun);
    await prefs.setBool(_kUnlocked, false);

    // ✅ NUEVO: también limpiar bloqueo forzado
    await prefs.setBool(_kForceLocked, false);
    await prefs.remove(_kForceReason);

    await cargar();
  }

  // =========================
  // ✅ REMOTE HELPERS (para Firestore)
  // =========================

  static Future<void> setRemoteInfo({
    String? plan,
    DateTime? expiresAt,
    String? remoteReason,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (plan != null) {
      await prefs.setString(_kRemotePlan, plan);
      remotePlan.value = plan;
    }

    // ✅ mejora: si expiresAt viene null, guardamos vacío para no dejar basura vieja
    if (expiresAt != null) {
      final iso = expiresAt.toIso8601String();
      await prefs.setString(_kRemoteExpiryIso, iso);
      remoteExpiryIso.value = iso;
    } else {
      await prefs.setString(_kRemoteExpiryIso, '');
      remoteExpiryIso.value = '';
    }

    if (remoteReason != null) {
      await prefs.setString(_kRemoteReason, remoteReason);
    }

    await cargar();
  }

  static Future<void> clearRemoteInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRemotePlan);
    await prefs.remove(_kRemoteExpiryIso);
    await prefs.remove(_kRemoteReason);

    remotePlan.value = 'free';
    remoteExpiryIso.value = '';

    await cargar();
  }

  // =========================
  // ✅ NUEVO: FORZAR BLOQUEO (remoto manda)
  // =========================
  static Future<void> setForceLocked(bool value, {String? forceReason}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kForceLocked, value);
    forceLocked.value = value;

    if (value == true) {
      await prefs.setString(
        _kForceReason,
        (forceReason ?? 'Acceso suspendido').trim().isEmpty
            ? 'Acceso suspendido'
            : (forceReason ?? 'Acceso suspendido'),
      );
    } else {
      await prefs.remove(_kForceReason);
    }

    await cargar();
  }

  // =========================
  // ✅ BACKUP HELPERS
  // =========================

  static Future<Map<String, dynamic>> getBackupSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'trialDays': prefs.getInt(_kTrialDays) ?? defaultTrialDays,
      'firstRunIso': prefs.getString(_kFirstRun) ?? '',
      'unlocked': prefs.getBool(_kUnlocked) ?? false,

      // extras
      'remotePlan': prefs.getString(_kRemotePlan) ?? 'free',
      'remoteExpiryIso': prefs.getString(_kRemoteExpiryIso) ?? '',
      'remoteReason': prefs.getString(_kRemoteReason) ?? '',

      // ✅ nuevo
      'forceLocked': prefs.getBool(_kForceLocked) ?? false,
      'forceReason': prefs.getString(_kForceReason) ?? '',
    };
  }

  static Future<void> applySnapshot(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();

    final trialRaw = json['trialDays'];
    final firstRaw = json['firstRunIso'];
    final unlockedRaw = json['unlocked'];

    final trialDays = (trialRaw is int)
        ? trialRaw
        : int.tryParse((trialRaw ?? '').toString());

    final unlocked = (unlockedRaw is bool)
        ? unlockedRaw
        : unlockedRaw?.toString().toLowerCase() == 'true';

    final firstIso = (firstRaw ?? '').toString();

    if (trialDays != null && trialDays > 0) {
      await prefs.setInt(_kTrialDays, trialDays);
    } else if (prefs.getInt(_kTrialDays) == null) {
      await prefs.setInt(_kTrialDays, defaultTrialDays);
    }

    if (unlocked == true) {
      await prefs.setBool(_kUnlocked, true);
    }

    if (firstIso.trim().isNotEmpty) {
      await prefs.setString(_kFirstRun, firstIso);
    } else if (prefs.getString(_kFirstRun) == null) {
      await prefs.setString(_kFirstRun, DateTime.now().toIso8601String());
    }

    // extras remotos
    final rp = (json['remotePlan'] ?? '').toString().trim();
    final re = (json['remoteExpiryIso'] ?? '').toString().trim();
    final rr = (json['remoteReason'] ?? '').toString().trim();
    if (rp.isNotEmpty) await prefs.setString(_kRemotePlan, rp);
    if (re.isNotEmpty) await prefs.setString(_kRemoteExpiryIso, re);
    if (rr.isNotEmpty) await prefs.setString(_kRemoteReason, rr);

    // ✅ nuevo: forceLocked
    final fl = json['forceLocked'];
    final fr = (json['forceReason'] ?? '').toString().trim();
    final force = (fl is bool)
        ? fl
        : fl?.toString().toLowerCase() == 'true';

    await prefs.setBool(_kForceLocked, force);
    if (force) {
      await prefs.setString(_kForceReason, fr.isNotEmpty ? fr : 'Acceso suspendido');
    } else {
      await prefs.remove(_kForceReason);
    }

    await cargar();
  }
}