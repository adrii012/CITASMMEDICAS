// lib/remote_license_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'license_store.dart';

class RemoteLicenseService {
  // Soporta ambos nombres por si tu consola tiene mayúscula/minúscula
  static const String collectionLower = 'licenses';
  static const String collectionUpper = 'Licenses';

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  // Recordamos cuál colección escucha el listener
  static String _listeningCollection = collectionUpper;

  /// ✅ 1) Sincroniza una vez
  static Future<void> syncFromFirestore({
    required String clinicId,
  }) async {
    try {
      final doc = await _readDoc(clinicId);

      // ❌ No existe doc => SUSPENDER (force lock)
      if (doc == null || !doc.exists) {
        await _forceLock('Licencia no encontrada');
        await LicenseStore.setRemoteInfo(
          plan: 'free',
          expiresAt: null,
          remoteReason: 'Licencia no encontrada',
        );
        return;
      }

      final data = doc.data() ?? {};
      final enabled = data['enabled'] == true;
      final plan = data['plan']?.toString() ?? 'free';
      final expiresAt = _parseExpiresAt(data['expiresAt']);

      // Guardar info remota (para UI)
      await LicenseStore.setRemoteInfo(
        plan: plan,
        expiresAt: expiresAt,
        remoteReason: enabled
            ? (expiresAt == null
                ? 'Fecha de licencia inválida'
                : 'Licencia $plan válida hasta ${_fmt(expiresAt)}')
            : 'Licencia deshabilitada',
      );

      // ❌ Si está deshabilitada => SUSPENDER (force lock)
      if (!enabled) {
        await _forceLock('Licencia deshabilitada');
        return;
      }

      // ❌ Fecha inválida => SUSPENDER (force lock)
      if (expiresAt == null) {
        await _forceLock('Fecha de licencia inválida');
        return;
      }

      // ❌ Vencida => SUSPENDER (force lock)
      if (DateTime.now().isAfter(expiresAt)) {
        await _forceLock('Licencia vencida');
        await LicenseStore.setRemoteInfo(
          plan: plan,
          expiresAt: expiresAt,
          remoteReason: 'Licencia vencida',
        );
        return;
      }

      // ✅ Licencia válida => QUITAR SUSPENSIÓN + desbloquear
      await LicenseStore.setForceLocked(false);
      await LicenseStore.setUnlocked(true);

      final msg = 'Licencia $plan válida hasta ${_fmt(expiresAt)}';
      LicenseStore.reason.value = msg;

      await LicenseStore.setRemoteInfo(
        plan: plan,
        expiresAt: expiresAt,
        remoteReason: msg,
      );
    } catch (_) {
      // Offline/red: intenta cache remoto
      final usedCache = await _applyCachedRemoteIfAny();
      if (!usedCache) {
        // Si no hay cache, cae a local (trial)
        await LicenseStore.validar();
        LicenseStore.reason.value = 'Sin conexión. Usando licencia local';

        await LicenseStore.setRemoteInfo(
          plan: LicenseStore.remotePlan.value,
          expiresAt: _tryParseIso(LicenseStore.remoteExpiryIso.value),
          remoteReason: 'Sin conexión. Usando licencia local',
        );
      }
    }
  }

  /// ✅ 2) Listener en vivo
  static Future<void> startListener({
    required String clinicId,
  }) async {
    await stopListener();

    // 1) Sync inicial
    await syncFromFirestore(clinicId: clinicId);

    // 2) Detectar colección correcta para escuchar
    _listeningCollection = await _detectCollectionForListener(clinicId);

    final ref = _docRef(clinicId);

    _sub = ref.snapshots().listen(
      (snap) async {
        if (!snap.exists) {
          await _forceLock('Licencia no encontrada');
          await LicenseStore.setRemoteInfo(
            plan: 'free',
            expiresAt: null,
            remoteReason: 'Licencia no encontrada',
          );
          return;
        }

        final data = snap.data() ?? {};
        final enabled = data['enabled'] == true;
        final plan = data['plan']?.toString() ?? 'free';
        final expiresAt = _parseExpiresAt(data['expiresAt']);

        await LicenseStore.setRemoteInfo(
          plan: plan,
          expiresAt: expiresAt,
          remoteReason: enabled
              ? (expiresAt == null
                  ? 'Fecha de licencia inválida'
                  : 'Licencia $plan válida hasta ${_fmt(expiresAt)}')
              : 'Licencia deshabilitada',
        );

        if (!enabled) {
          await _forceLock('Licencia deshabilitada');
          return;
        }

        if (expiresAt == null) {
          await _forceLock('Fecha de licencia inválida');
          return;
        }

        if (DateTime.now().isAfter(expiresAt)) {
          await _forceLock('Licencia vencida');
          await LicenseStore.setRemoteInfo(
            plan: plan,
            expiresAt: expiresAt,
            remoteReason: 'Licencia vencida',
          );
          return;
        }

        // ✅ válida => quitar suspensión + desbloquear
        await LicenseStore.setForceLocked(false);
        await LicenseStore.setUnlocked(true);

        final msg = 'Licencia $plan válida hasta ${_fmt(expiresAt)}';
        LicenseStore.reason.value = msg;

        await LicenseStore.setRemoteInfo(
          plan: plan,
          expiresAt: expiresAt,
          remoteReason: msg,
        );
      },
      onError: (_) async {
        final usedCache = await _applyCachedRemoteIfAny();
        if (!usedCache) {
          await LicenseStore.validar();
          LicenseStore.reason.value = 'Sin conexión. Usando licencia local';

          await LicenseStore.setRemoteInfo(
            plan: LicenseStore.remotePlan.value,
            expiresAt: _tryParseIso(LicenseStore.remoteExpiryIso.value),
            remoteReason: 'Sin conexión. Usando licencia local',
          );
        }
      },
    );
  }

  /// ✅ 3) Detener listener (logout)
  static Future<void> stopListener() async {
    await _sub?.cancel();
    _sub = null;
  }

  // =========================
  // ✅ SUSPENSIÓN REAL (gana siempre)
  // =========================
  static Future<void> _forceLock(String msg) async {
    // Esto hace que aunque haya trial, SE BLOQUEE
    await LicenseStore.setForceLocked(true, forceReason: msg);

    // Además quitamos “unlocked” para no dejarlo activo local
    await LicenseStore.setUnlocked(false);

    LicenseStore.reason.value = msg;

    await LicenseStore.setRemoteInfo(
      plan: LicenseStore.remotePlan.value,
      expiresAt: _tryParseIso(LicenseStore.remoteExpiryIso.value),
      remoteReason: msg,
    );
  }

  // =========================
  // Helpers
  // =========================

  static String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  static DateTime? _parseExpiresAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DateTime? _tryParseIso(String iso) {
    final s = iso.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DocumentReference<Map<String, dynamic>> _docRef(String clinicId) {
    return FirebaseFirestore.instance
        .collection(_listeningCollection)
        .doc(clinicId);
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> _readDoc(
    String clinicId,
  ) async {
    final upper = await FirebaseFirestore.instance
        .collection(collectionUpper)
        .doc(clinicId)
        .get();
    if (upper.exists) return upper;

    final lower = await FirebaseFirestore.instance
        .collection(collectionLower)
        .doc(clinicId)
        .get();
    return lower;
  }

  static Future<String> _detectCollectionForListener(String clinicId) async {
    try {
      final upper = await FirebaseFirestore.instance
          .collection(collectionUpper)
          .doc(clinicId)
          .get();
      if (upper.exists) return collectionUpper;

      final lower = await FirebaseFirestore.instance
          .collection(collectionLower)
          .doc(clinicId)
          .get();
      if (lower.exists) return collectionLower;
    } catch (_) {}
    return collectionUpper;
  }

  /// Cache remoto: usa lo guardado en LicenseStore (lic_remote_*)
  static Future<bool> _applyCachedRemoteIfAny() async {
    // Si está forzado a locked, respetamos eso (no “desbloqueamos” por cache)
    if (LicenseStore.forceLocked.value == true) return true;

    final plan = LicenseStore.remotePlan.value;
    final expiresAt = _tryParseIso(LicenseStore.remoteExpiryIso.value);

    if ((plan.trim().isEmpty || plan == 'free') && expiresAt == null) {
      return false;
    }

    if (expiresAt == null) return false;

    if (DateTime.now().isAfter(expiresAt)) {
      await _forceLock('Licencia vencida (offline cache)');
      return true;
    }

    await LicenseStore.setForceLocked(false);
    await LicenseStore.setUnlocked(true);

    final msg = 'Licencia $plan válida (offline) hasta ${_fmt(expiresAt)}';
    LicenseStore.reason.value = msg;

    await LicenseStore.setRemoteInfo(
      plan: plan,
      expiresAt: expiresAt,
      remoteReason: msg,
    );

    return true;
  }
}