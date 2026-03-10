// lib/fire_appointments.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FireAppointments {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String clinicId) {
    return _db.collection('clinics').doc(clinicId).collection('appointments');
  }

  /// Crea una cita y devuelve el id del documento.
  static Future<String> create({
    required String clinicId,
    required String createdByUid,
    required String createdByEmail,
    required DateTime startAt,
    required String patientName,
    String? patientId,
    String? phone,
    String? notes,
    String? service,
    String? motivo,
    String? pieza,
    int? durationMin,
  }) async {
    final doc = _col(clinicId).doc();

    final data = <String, dynamic>{
      'id': doc.id,
      'status': 'pendiente',
      'startAt': Timestamp.fromDate(startAt),

      'patientName': patientName.trim(),
      'patientId': (patientId ?? '').trim(),
      'phone': (phone ?? '').trim(),

      'notes': (notes ?? '').trim(),
      'service': (service ?? '').trim(),
      'motivo': (motivo ?? '').trim(),
      'pieza': (pieza ?? '').trim(),
      'durationMin': durationMin ?? 30,

      // ✅ NUEVO: control de recordatorio 24h
      'reminderSent24h': false,
      'reminderSent24hAt': null,
      'reminderSent24hWhatsApp': false,
      'reminderSent24hPush': false,

      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': createdByUid,
    };

    await doc.set(data);
    return doc.id;
  }

  /// Actualiza una cita (parcial).
  static Future<void> update({
    required String clinicId,
    required String appointmentId,
    required String updatedByUid,
    DateTime? startAt,
    String? patientName,
    String? patientId,
    String? phone,
    String? notes,
    String? service,
    String? motivo,
    String? pieza,
    int? durationMin,
  }) async {
    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
    };

    if (startAt != null) {
      patch['startAt'] = Timestamp.fromDate(startAt);

      // ✅ NUEVO: si cambias fecha/hora, se reinicia el recordatorio
      patch['reminderSent24h'] = false;
      patch['reminderSent24hAt'] = null;
      patch['reminderSent24hWhatsApp'] = false;
      patch['reminderSent24hPush'] = false;
    }

    if (patientName != null) patch['patientName'] = patientName.trim();
    if (patientId != null) patch['patientId'] = patientId.trim();
    if (phone != null) patch['phone'] = phone.trim();
    if (notes != null) patch['notes'] = notes.trim();
    if (service != null) patch['service'] = service.trim();
    if (motivo != null) patch['motivo'] = motivo.trim();
    if (pieza != null) patch['pieza'] = pieza.trim();
    if (durationMin != null) patch['durationMin'] = durationMin;

    await _col(clinicId).doc(appointmentId).update(patch);
  }

  static Future<void> delete({
    required String clinicId,
    required String appointmentId,
  }) async {
    await _col(clinicId).doc(appointmentId).delete();
  }

  static Stream<List<Map<String, dynamic>>> streamUpcoming({
    required String clinicId,
    DateTime? from,
    int limit = 200,
  }) {
    final fromDate = from ?? DateTime.now();

    final q = _col(clinicId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
        .orderBy('startAt')
        .limit(limit);

    return q.snapshots().map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  static Stream<List<Map<String, dynamic>>> streamRange({
    required String clinicId,
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) {
    final q = _col(clinicId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('startAt', isLessThan: Timestamp.fromDate(to))
        .orderBy('startAt')
        .limit(limit);

    return q.snapshots().map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  static Future<void> updateStatus({
    required String clinicId,
    required String appointmentId,
    required String updatedByUid,
    required String status,
  }) async {
    await _col(clinicId).doc(appointmentId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
    });
  }
}