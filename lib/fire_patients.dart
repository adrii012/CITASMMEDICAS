// lib/fire_patients.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirePatients {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String clinicId) {
    return _db.collection('clinics').doc(clinicId).collection('patients');
  }

  static Stream<List<Map<String, dynamic>>> streamAll({
    required String clinicId,
    int limit = 500,
  }) {
    final q = _col(clinicId).orderBy('nameLower').limit(limit);
    return q.snapshots().map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  static Future<String> create({
    required String clinicId,
    required String name,
    String? phone,
    String? notes,
    required String createdByUid,
    required String createdByEmail,
  }) async {
    final doc = _col(clinicId).doc();
    final cleanName = name.trim();

    await doc.set({
      'id': doc.id,
      'name': cleanName,
      'nameLower': cleanName.toLowerCase(),
      'phone': (phone ?? '').trim(),
      'notes': (notes ?? '').trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'updatedByUid': createdByUid,
    });

    return doc.id;
  }

  static Future<void> delete({
    required String clinicId,
    required String patientId,
  }) async {
    await _col(clinicId).doc(patientId).delete();
  }
}