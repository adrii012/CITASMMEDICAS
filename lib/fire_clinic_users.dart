// lib/fire_clinic_users.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FireClinicUsers {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _clinicRef(String clinicId) {
    return _db.collection('clinics').doc(clinicId);
  }

  static DocumentReference<Map<String, dynamic>> _userRef({
    required String clinicId,
    required String uid,
  }) {
    return _clinicRef(clinicId).collection('users').doc(uid);
  }

  static Future<void> ensureClinic({
    required String clinicId,
    required String clinicName,
    required String ownerUid,
    required String ownerEmail,
  }) async {
    final ref = _clinicRef(clinicId);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();

    if (!snap.exists) {
      await ref.set({
        'id': clinicId,
        'name': clinicName.trim(),
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail.trim().toLowerCase(),
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      await ref.update({
        'name': clinicName.trim(),
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail.trim().toLowerCase(),
        'updatedAt': now,
      });
    }
  }

  static Future<void> ensureUser({
    required String clinicId,
    required String uid,
    required String email,
    required String role, // admin | staff
    bool active = true,
  }) async {
    final ref = _userRef(clinicId: clinicId, uid: uid);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'uid': uid,
      'email': email.trim().toLowerCase(),
      'role': role,
      'active': active,
      'updatedAt': now,
    };

    if (!snap.exists) {
      await ref.set({
        ...data,
        'createdAt': now,
      });
    } else {
      await ref.update(data);
    }
  }

  static Future<({String role, bool active})> getRoleForClinic({
    required String clinicId,
    required String uid,
  }) async {
    final snap = await _userRef(clinicId: clinicId, uid: uid).get();
    if (!snap.exists) return (role: 'staff', active: false);

    final data = snap.data() ?? {};
    final role = (data['role'] ?? 'staff').toString();
    final active = (data['active'] ?? false) == true;
    return (role: role, active: active);
  }

  // ✅ NUEVO: guardar token FCM
  static Future<void> addFcmToken({
    required String clinicId,
    required String uid,
    required String token,
  }) async {
    final clean = token.trim();
    if (clean.isEmpty) return;

    final ref = _userRef(clinicId: clinicId, uid: uid);
    await ref.set({
      'fcmTokens': FieldValue.arrayUnion([clean]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ✅ NUEVO: quitar token FCM
  static Future<void> removeFcmToken({
    required String clinicId,
    required String uid,
    required String token,
  }) async {
    final clean = token.trim();
    if (clean.isEmpty) return;

    final ref = _userRef(clinicId: clinicId, uid: uid);
    await ref.set({
      'fcmTokens': FieldValue.arrayRemove([clean]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}