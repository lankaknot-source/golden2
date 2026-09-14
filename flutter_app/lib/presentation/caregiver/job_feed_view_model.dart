import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/model/data_models.dart';

class JobFeedUiState {
  final bool isLoading;
  final List<Booking> jobs;
  final String? errorMessage;

  JobFeedUiState({
    this.isLoading = true,
    this.jobs = const [],
    this.errorMessage,
  });

  JobFeedUiState copyWith({
    bool? isLoading,
    List<Booking>? jobs,
    String? errorMessage,
  }) {
    return JobFeedUiState(
      isLoading: isLoading ?? this.isLoading,
      jobs: jobs ?? this.jobs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class JobFeedViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  JobFeedUiState _uiState = JobFeedUiState();
  JobFeedUiState get uiState => _uiState;

  JobFeedViewModel() {
    fetchAvailableJobs();
  }

  void _setUiState(JobFeedUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void fetchAvailableJobs() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection("bookings")
        .where("status", whereIn: ["BROADCASTED", "PENDING"])
        .snapshots()
        .listen((snapshot) {
      final jobList = snapshot.docs.map((doc) => Booking.fromMap(doc.data()))
          .where((it) => !it.rejectedBy.contains(userId))
          .where((it) => it.status == "BROADCASTED" || (it.status == "PENDING" && it.caregiverId == userId))
          .where((booking) {
            if (booking.isSubscriptionBooking && booking.allowedCaregivers.isNotEmpty) {
              return booking.allowedCaregivers.contains(userId);
            }
            return true;
          }).toList();

      jobList.sort((a, b) {
        if (a.isEmergency != b.isEmergency) {
          return a.isEmergency ? -1 : 1;
        }
        return b.requestedTime.compareTo(a.requestedTime);
      });

      _setUiState(_uiState.copyWith(isLoading: false, jobs: jobList));
    }, onError: (error) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: error.toString()));
    });
  }

  Future<void> rejectJob(String jobId, Function(bool, String) onResult) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      final bookingRef = _firestore.collection("bookings").doc(jobId);

      final doc = await bookingRef.get();
      if (!doc.exists) return;
      
      final status = doc.data()?['status'] as String?;
      final caregiverId = doc.data()?['caregiverId'] as String?;

      if (status == "PENDING" && caregiverId == userId) {
        await bookingRef.update({"status": "REJECTED"});
      } else {
        await bookingRef.update({
          "rejectedBy": FieldValue.arrayUnion([userId])
        });
      }

      onResult(true, "රැකියාව ප්‍රතික්ෂේප කරන ලදී.");
    } catch (e) {
      onResult(false, e.toString());
    }
  }

  Future<void> acceptJob(String jobId, Function(bool, String) onResult) async {
    try {
      final caregiverId = _auth.currentUser?.uid;
      if (caregiverId == null) return;
      
      final bookingRef = _firestore.collection("bookings").doc(jobId);
      final caregiverDoc = await _firestore.collection("users").doc(caregiverId).get();
      
      final hourlyRate = caregiverDoc.data()?['hourlyRate'] ?? 0.0;
      
      const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
      const digits = "0123456789";
      final rnd = Random();
      final code = "${chars[rnd.nextInt(chars.length)]}${List.generate(4, (_) => digits[rnd.nextInt(digits.length)]).join()}";

      final currentBookingDoc = await bookingRef.get();
      final currentBooking = Booking.fromMap(currentBookingDoc.data()!);

      final Map<String, dynamic> updates = {
        "status": "ACCEPTED",
        "caregiverId": caregiverId,
        "startCode": code,
      };

      if (!currentBooking.isSubscriptionBooking) {
        updates["hourlyRate"] = hourlyRate;
      }

      await bookingRef.update(updates);
      await _firestore.collection("users").doc(caregiverId).update({"isBusy": true});

      // TODO: Schedule job reminders (WorkManager)

      onResult(true, "රැකියාව සාර්ථකව භාර ගන්නා ලදී!");
    } catch (e) {
      onResult(false, e.toString());
    }
  }
}
