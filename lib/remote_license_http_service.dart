// lib/remote_license_http_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'license_store.dart';

class RemoteLicenseHttpService {
  /// JSON esperado:
  /// {
  ///   "clinics": {
  ///     "CLINIC_001": { "active": true, "until": "2026-02-15", "reason": "OK" }
  ///   }
  /// }
  static Future<void> syncFromUrl({
    required String clinicId,
    required String url,
  }) async {
    // ✅ IMPORTANTE: En Web NO hacemos HTTP a GitHub RAW (CORS)
    if (kIsWeb) {
      await LicenseStore.setRemoteInfo(
        plan: 'web_disabled',
        expiresAt: null,
        remoteReason: '',
      );
      return;
    }

    // 0) Normalizar URL "raw.githubusercontent.com" (corregir /refs/heads/)
    final fixedUrl = _normalizeGithubRaw(url.trim());

    // 1) Cache-bust: siempre pedir versión fresca
    final baseUri = Uri.parse(fixedUrl);
    final uri = baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        'v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    http.Response res;
    try {
      // ✅ Tip: sin headers para evitar preflight raro en algunos hosts
      res = await http.get(uri).timeout(const Duration(seconds: 12));
    } catch (e) {
      await LicenseStore.setRemoteInfo(
        plan: 'offline',
        expiresAt: null,
        remoteReason: 'No se pudo validar en línea (sin conexión / timeout)',
      );
      return;
    }

    if (res.statusCode != 200) {
      await LicenseStore.setRemoteInfo(
        plan: 'http_${res.statusCode}',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        remoteReason: 'No se pudo leer licencia remota (HTTP ${res.statusCode})',
      );
      await LicenseStore.setUnlocked(false);
      await LicenseStore.setForceLocked(
        true,
        forceReason: 'Licencia no disponible (HTTP ${res.statusCode})',
      );
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      await LicenseStore.setRemoteInfo(
        plan: 'invalid_json',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        remoteReason: 'Licencia inválida (JSON mal formado)',
      );
      await LicenseStore.setUnlocked(false);
      await LicenseStore.setForceLocked(
        true,
        forceReason: 'Licencia inválida (JSON mal formado)',
      );
      return;
    }

    if (decoded is! Map) {
      await LicenseStore.setRemoteInfo(
        plan: 'invalid_json',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        remoteReason: 'Licencia inválida (JSON no es objeto)',
      );
      await LicenseStore.setUnlocked(false);
      await LicenseStore.setForceLocked(
        true,
        forceReason: 'Licencia inválida (JSON no es objeto)',
      );
      return;
    }

    final data = Map<String, dynamic>.from(decoded as Map);

    final clinicsAny = data['clinics'];
    final clinics = (clinicsAny is Map)
        ? Map<String, dynamic>.from(clinicsAny)
        : <String, dynamic>{};

    final raw = clinics[clinicId];

    if (raw == null) {
      await LicenseStore.setRemoteInfo(
        plan: 'missing',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        remoteReason: 'Licencia no encontrada (clínica no registrada)',
      );
      await LicenseStore.setUnlocked(false);
      await LicenseStore.setForceLocked(
        true,
        forceReason: 'Licencia no encontrada (clínica no registrada)',
      );
      return;
    }

    if (raw is! Map) {
      await LicenseStore.setRemoteInfo(
        plan: 'invalid',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        remoteReason: 'Licencia inválida (estructura de clínica mal)',
      );
      await LicenseStore.setUnlocked(false);
      await LicenseStore.setForceLocked(
        true,
        forceReason: 'Licencia inválida (estructura de clínica mal)',
      );
      return;
    }

    final m = Map<String, dynamic>.from(raw);

    final active = m['active'] == true;
    final untilStr = (m['until'] ?? '').toString().trim();
    final reason = (m['reason'] ?? '').toString().trim();

    final until = DateTime.tryParse(untilStr);
    if (until == null) {
      await LicenseStore.setRemoteInfo(
        plan: 'invalid',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        remoteReason: 'Licencia inválida (fecha until mal)',
      );
      await LicenseStore.setUnlocked(false);
      await LicenseStore.setForceLocked(
        true,
        forceReason: 'Licencia inválida (fecha until mal)',
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final untilDay = DateTime(until.year, until.month, until.day);

    final validByDate = !untilDay.isBefore(today);
    final unlocked = active && validByDate;

    await LicenseStore.setRemoteInfo(
      plan: active ? 'paid' : 'inactive',
      expiresAt: untilDay,
      remoteReason: reason.isNotEmpty
          ? reason
          : (unlocked ? 'Licencia activa ✅' : 'Licencia vencida o inactiva'),
    );

    if (unlocked) {
      await LicenseStore.setForceLocked(false);
      await LicenseStore.setUnlocked(true);
    } else {
      await LicenseStore.setUnlocked(false);
      await LicenseStore.setForceLocked(
        true,
        forceReason: reason.isNotEmpty
            ? reason
            : (validByDate ? 'Licencia inactiva' : 'Licencia vencida'),
      );
    }
  }

  static String _normalizeGithubRaw(String url) {
    if (url.contains('raw.githubusercontent.com') && url.contains('/refs/heads/')) {
      return url.replaceFirst('/refs/heads/', '/');
    }
    return url;
  }
}