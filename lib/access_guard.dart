import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_store.dart';

class AccessGuard {
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  static Future<void> start() async {
    await stop();

    final clinicId = AuthStore.clinicId.value?.trim();
    final uid = AuthStore.uid.value?.trim();

    if (clinicId == null || clinicId.isEmpty || uid == null || uid.isEmpty) {
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .collection('users')
        .doc(uid);

    _sub = ref.snapshots().listen((snap) async {
      if (!snap.exists) {
        await _kick();
        return;
      }

      final data = snap.data() ?? {};
      final active = data['active'] == true;

      if (!active) {
        await _kick();
      }
    });
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  static Future<void> _kick() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    try {
      await AuthStore.logout(localOnly: true);
    } catch (_) {}
  }
}