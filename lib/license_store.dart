// lib/license_store.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseStore {
  // (Se dejan por compatibilidad, pero ya NO se usan para trial)
  static const _kFirstRun = 'lic_first_run_v1';
  static const _kTrialDays = 'lic_trial_days_v1';

  static const _kUnlocked = 'lic_unlocked_v1';

  static const _kRemoteReason = 'lic_remote_reason_v1';
  static const _kRemotePlan = 'lic_remote_plan_v1';
  static const _kRemoteExpiryIso = 'lic_remote_expiry_iso_v1';

  static const _kForceLocked = 'lic_force_locked_v1';
  static const _kForceReason = 'lic_force_reason_v1';

  // Ya no hay trial, pero se deja para snapshots viejos
  static const int defaultTrialDays = 7;

  static final ValueNotifier<bool> isLocked = ValueNotifier<bool>(false);

  /// Se deja por compatibilidad (aunque ya no mostramos “días restantes”)
  static final ValueNotifier<int> daysLeft = ValueNotifier<int>(9999);

  /// Mensaje simple: “Licencia activa” o motivo de bloqueo
  static final ValueNotifier<String> reason = ValueNotifier<String>('Licencia activa');

  static final ValueNotifier<String> remotePlan = ValueNotifier<String>('free');
  static final ValueNotifier<String> remoteExpiryIso = ValueNotifier<String>('');

  static final ValueNotifier<bool> forceLocked = ValueNotifier<bool>(false);
  static final ValueNotifier<String> debugState = ValueNotifier<String>('');

  /// ✅ SIN TRIAL:
  /// - Si forceLocked=true -> bloqueada
  /// - Si no -> activa (por defecto)
  /// - Si hay remoteReason, se usa para texto, pero no mostramos “días”
  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();

    remotePlan.value = prefs.getString(_kRemotePlan) ?? 'free';
    remoteExpiryIso.value = prefs.getString(_kRemoteExpiryIso) ?? '';
    final remoteReason = (prefs.getString(_kRemoteReason) ?? '').trim();

    final forced = prefs.getBool(_kForceLocked) ?? false;
    final forcedReason = (prefs.getString(_kForceReason) ?? '').trim();
    forceLocked.value = forced;

    final unlocked = prefs.getBool(_kUnlocked) ?? true; // ✅ por defecto activo

    debugState.value =
        'forced=$forced | unlocked=$unlocked | '
        'remotePlan=${remotePlan.value} | remoteExpiryIso=${remoteExpiryIso.value} | '
        'remoteReason=${remoteReason.isEmpty ? "-" : remoteReason}';

    if (forced) {
      isLocked.value = true;
      daysLeft.value = 0;
      reason.value = forcedReason.isNotEmpty ? forcedReason : 'Acceso suspendido';
      return;
    }

    // Activo por defecto (sin trial)
    isLocked.value = false;
    daysLeft.value = 9999;

    // Si tu licencia remota manda un mensaje, lo mostramos; si no, texto neutro.
    reason.value = remoteReason.isNotEmpty ? remoteReason : (unlocked ? 'Licencia activa' : 'Licencia activa');
  }

  static Future<void> validar() async => cargar();

  /// Mantiene el contrato: si lo marcas unlocked, queda activo.
  static Future<void> setUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUnlocked, value);

    if (value == true) {
      await prefs.setBool(_kForceLocked, false);
      await prefs.remove(_kForceReason);
      forceLocked.value = false;
    }

    await cargar();
  }

  /// ✅ Ya no usamos trial: se deja para que no truene el panel DEV.
  static Future<void> setTrialDays(int days) async {
    // No-op intencional (sin trial)
    await cargar();
  }

  /// ✅ Ya no hay trial: “reset” solo limpia locks/unlocked y remotos opcional.
  static Future<void> resetTrial() async {
    final prefs = await SharedPreferences.getInstance();

    // Limpieza de llaves viejas de trial para que nunca vuelvan a aparecer
    await prefs.remove(_kFirstRun);
    await prefs.remove(_kTrialDays);

    // Mantén activo por defecto
    await prefs.setBool(_kUnlocked, true);

    // Quitar bloqueo forzado
    await prefs.setBool(_kForceLocked, false);
    await prefs.remove(_kForceReason);

    await cargar();
  }

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

  static Future<void> setForceLocked(bool value, {String? forceReason}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kForceLocked, value);
    forceLocked.value = value;

    if (value == true) {
      final msg = (forceReason ?? 'Acceso suspendido').trim();
      await prefs.setString(_kForceReason, msg.isEmpty ? 'Acceso suspendido' : msg);

      // Si fuerzas bloqueo, también desmarcamos unlocked para evitar confusiones
      await prefs.setBool(_kUnlocked, false);
    } else {
      await prefs.remove(_kForceReason);

      // Por defecto activo
      await prefs.setBool(_kUnlocked, true);
    }

    await cargar();
  }

  static Future<void> clearLocalLocks({bool alsoClearUnlocked = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kForceLocked, false);
    await prefs.remove(_kForceReason);

    if (alsoClearUnlocked) {
      await prefs.setBool(_kUnlocked, true);
    }

    await cargar();
  }

  static Future<void> nukeAllLicenseLocal() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_kFirstRun);
    await prefs.remove(_kTrialDays);

    await prefs.remove(_kRemotePlan);
    await prefs.remove(_kRemoteExpiryIso);
    await prefs.remove(_kRemoteReason);

    await prefs.remove(_kForceLocked);
    await prefs.remove(_kForceReason);

    // Activo por defecto
    await prefs.setBool(_kUnlocked, true);

    remotePlan.value = 'free';
    remoteExpiryIso.value = '';
    forceLocked.value = false;

    await cargar();
  }

  static Future<Map<String, dynamic>> getBackupSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      // Se dejan campos viejos por compatibilidad
      'trialDays': prefs.getInt(_kTrialDays) ?? defaultTrialDays,
      'firstRunIso': prefs.getString(_kFirstRun) ?? '',

      // Estado actual
      'unlocked': prefs.getBool(_kUnlocked) ?? true,
      'remotePlan': prefs.getString(_kRemotePlan) ?? 'free',
      'remoteExpiryIso': prefs.getString(_kRemoteExpiryIso) ?? '',
      'remoteReason': prefs.getString(_kRemoteReason) ?? '',
      'forceLocked': prefs.getBool(_kForceLocked) ?? false,
      'forceReason': prefs.getString(_kForceReason) ?? '',
    };
  }

  static Future<void> applySnapshot(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();

    // Ignoramos trial, pero limpiamos las llaves para que no reaparezca
    await prefs.remove(_kFirstRun);
    await prefs.remove(_kTrialDays);

    final unlockedRaw = json['unlocked'];
    final unlocked = (unlockedRaw is bool)
        ? unlockedRaw
        : unlockedRaw?.toString().toLowerCase() == 'true';

    // Por defecto activo
    await prefs.setBool(_kUnlocked, unlocked != false);

    final rp = (json['remotePlan'] ?? '').toString().trim();
    final re = (json['remoteExpiryIso'] ?? '').toString().trim();
    final rr = (json['remoteReason'] ?? '').toString().trim();

    if (rp.isNotEmpty) await prefs.setString(_kRemotePlan, rp);
    if (re.isNotEmpty) await prefs.setString(_kRemoteExpiryIso, re);
    if (rr.isNotEmpty) await prefs.setString(_kRemoteReason, rr);

    final fl = json['forceLocked'];
    final fr = (json['forceReason'] ?? '').toString().trim();
    final force = (fl is bool) ? fl : fl?.toString().toLowerCase() == 'true';

    await prefs.setBool(_kForceLocked, force);
    if (force) {
      await prefs.setString(_kForceReason, fr.isNotEmpty ? fr : 'Acceso suspendido');
      await prefs.setBool(_kUnlocked, false);
    } else {
      await prefs.remove(_kForceReason);
      await prefs.setBool(_kUnlocked, true);
    }

    await cargar();
  }
}
