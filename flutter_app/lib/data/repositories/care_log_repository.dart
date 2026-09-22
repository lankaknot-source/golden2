import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/daily_care_log_model.dart';

class CareLogRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.careLogsCollection);

  Future<String> addLog(DailyCareLog log) async {
    final ref = await _col.add(log.toMap());
    return ref.id;
  }

  Stream<List<DailyCareLog>> streamBookingLogs(String bookingId) {
    return _col
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => DailyCareLog.fromMap(d.data(), d.id)).toList());
  }

  Future<List<DailyCareLog>> getBookingLogs(String bookingId) async {
    final snap = await _col
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map((d) => DailyCareLog.fromMap(d.data(), d.id)).toList();
  }

  Future<void> updateLog(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> deleteLog(String id) => _col.doc(id).delete();
}
