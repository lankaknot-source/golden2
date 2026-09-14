import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/data_models.dart';

class CareLogViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DailyCareLog> _logs = [];
  List<DailyCareLog> get logs => _logs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void loadLogsForBooking(String bookingId) {
    _isLoading = true;
    notifyListeners();

    _firestore.collection("care_logs")
        .where("bookingId", isEqualTo: bookingId)
        .snapshots()
        .listen((snapshot) {
      final fetchedLogs = snapshot.docs.map((doc) => DailyCareLog.fromMap(doc.data())).toList();
      fetchedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      _logs = fetchedLogs;
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addLog({
    required String bookingId,
    required String elderId,
    required String bloodPressure,
    required String sugarLevel,
    required String temperature,
    required String mealStatus,
    required bool medicationGiven,
    required String notes,
    required Function(bool, String) onResult,
  }) async {
    try {
      final caregiverId = _auth.currentUser?.uid;
      if (caregiverId == null) return;

      final logId = const Uuid().v4();
      final log = DailyCareLog(
        id: logId,
        bookingId: bookingId,
        caregiverId: caregiverId,
        elderId: elderId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        bloodPressure: bloodPressure,
        sugarLevel: sugarLevel,
        temperature: temperature,
        mealStatus: mealStatus,
        medicationGiven: medicationGiven,
        notes: notes,
      );

      await _firestore.collection("care_logs").doc(logId).set(log.toMap());
      onResult(true, "Log added successfully");
    } catch (e) {
      onResult(false, e.toString());
    }
  }

  // NOTE: PDF generation logic using `pdf` package would be triggered from UI and consume this data.
}
