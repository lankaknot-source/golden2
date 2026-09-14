import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/data_models.dart';

class BookingsUiState {
  final bool isLoading;
  final List<Booking> bookings;
  final String? errorMessage;
  final bool isCaregiverAway;
  final bool isPhotoUploading;

  BookingsUiState({
    this.isLoading = true,
    this.bookings = const [],
    this.errorMessage,
    this.isCaregiverAway = false,
    this.isPhotoUploading = false,
  });

  BookingsUiState copyWith({
    bool? isLoading,
    List<Booking>? bookings,
    String? errorMessage,
    bool? isCaregiverAway,
    bool? isPhotoUploading,
  }) {
    return BookingsUiState(
      isLoading: isLoading ?? this.isLoading,
      bookings: bookings ?? this.bookings,
      errorMessage: errorMessage ?? this.errorMessage,
      isCaregiverAway: isCaregiverAway ?? this.isCaregiverAway,
      isPhotoUploading: isPhotoUploading ?? this.isPhotoUploading,
    );
  }
}

class BookingsViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  BookingsUiState _uiState = BookingsUiState();
  BookingsUiState get uiState => _uiState;

  BookingsViewModel() {
    fetchMyBookings();
  }

  void _setUiState(BookingsUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void fetchMyBookings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection("users").doc(userId).get().then((userDoc) {
      final role = userDoc.data()?['role'] ?? "CLIENT";
      final queryField = (role == "CAREGIVER" || role == "NURSE") ? "caregiverId" : "clientId";

      _firestore.collection("bookings")
          .where(queryField, isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        final bookingList = snapshot.docs.map((doc) => Booking.fromMap(doc.data())).toList();
        bookingList.sort((a, b) => b.requestedTime.compareTo(a.requestedTime));
        
        _setUiState(_uiState.copyWith(isLoading: false, bookings: bookingList));
      });
    });
  }

  Future<void> startJob(String bookingId, String startCode, String enteredCode, Function(bool, String) onResult) async {
    if (enteredCode.trim().toUpperCase() != startCode.toUpperCase()) {
      onResult(false, "Invalid code!");
      return;
    }
    
    try {
      await _firestore.collection("bookings").doc(bookingId).update({
        "status": "IN_PROGRESS",
        "startTime": DateTime.now().millisecondsSinceEpoch,
      });
      // TODO: Schedule auto-end job WorkManager task here
      onResult(true, "Job Started.");
    } catch (e) {
      onResult(false, e.toString());
    }
  }

  Future<void> confirmJobEndByCaregiver(String bookingId, double totalEarning, Function(bool, String) onResult) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection("bookings").doc(bookingId).update({
        "isCaregiverAcceptedEnd": true,
      });
      await _firestore.collection("users").doc(userId).update({
        "isBusy": false,
      });

      onResult(true, "Job Fully Completed.");
    } catch (e) {
      onResult(false, "Error: ${e.toString()}");
    }
  }

  Future<void> endJobByClientWithVerification({
    required String bookingId,
    required List<String> approvedTasks,
    required bool hasComplaint,
    required String complaintNotes,
    required double totalAmount,
    required Function(bool, String) onResult,
  }) async {
    try {
      await _firestore.collection("bookings").doc(bookingId).update({
        "status": "COMPLETED",
        "isClientEnded": true,
        "endTime": DateTime.now().millisecondsSinceEpoch,
        "clientApprovedTasks": approvedTasks,
        "hasComplaint": hasComplaint,
        "complaintNotes": complaintNotes,
        "totalAmount": totalAmount,
      });
      onResult(true, "Job completed successfully!");
    } catch (e) {
      onResult(false, "Error: ${e.toString()}");
    }
  }

  Future<void> rateCaregiver(String bookingId, String caregiverId, double rating, String comment, Function(bool, String) onResult) async {
    try {
      final clientId = _auth.currentUser?.uid ?? "";
      final reviewId = const Uuid().v4();

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection("users").doc(caregiverId);
        final bookingRef = _firestore.collection("bookings").doc(bookingId);
        final reviewRef = _firestore.collection("reviews").doc(reviewId);

        final userSnap = await transaction.get(userRef);
        final currentRating = (userSnap.data()?['rating'] ?? 0.0) as double;
        final count = (userSnap.data()?['reviewCount'] ?? 0) as int;
        
        final newCount = count + 1;
        final newRating = ((currentRating * count) + rating) / newCount;

        transaction.update(bookingRef, {
          "isRated": true,
          "status": "COMPLETED",
          "isCaregiverAcceptedEnd": true,
        });

        transaction.update(userRef, {
          "rating": newRating,
          "reviewCount": newCount,
          "isBusy": false,
        });

        transaction.set(reviewRef, {
          "id": reviewId,
          "bookingId": bookingId,
          "caregiverId": caregiverId,
          "clientId": clientId,
          "rating": rating,
          "comment": comment,
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        });
      });

      onResult(true, "Review submitted successfully! Job is closed.");
    } catch (e) {
      onResult(false, "Error: ${e.toString()}");
    }
  }

  Future<void> requestCaregiverReplacement(String bookingId, String reason, Function(bool, String) onResult) async {
    try {
      await _firestore.collection("bookings").doc(bookingId).update({
        "replacementRequested": true,
        "replacementReason": reason,
        "status": "PENDING"
      });
      onResult(true, "Replacement requested.");
    } catch (e) {
      onResult(false, "Error: ${e.toString()}");
    }
  }

  Future<void> updateTaskWithProof(String bookingId, String taskName, bool isChecking, String base64Image, Booking currentBooking) async {
    _setUiState(_uiState.copyWith(isPhotoUploading: true));
    try {
      if (isChecking) {
        final newProof = TaskProof(taskName: taskName, photoUrl: base64Image);
        final updatedTasks = List<String>.from(currentBooking.completedTasks)..add(taskName);
        final updatedProofs = List<TaskProof>.from(currentBooking.taskProofs)..add(newProof);
        
        await _firestore.collection("bookings").doc(bookingId).update({
          "completedTasks": updatedTasks,
          "taskProofs": updatedProofs.map((e) => e.toMap()).toList()
        });
      } else {
        final updatedTasks = List<String>.from(currentBooking.completedTasks)..remove(taskName);
        final updatedProofs = List<TaskProof>.from(currentBooking.taskProofs)..removeWhere((e) => e.taskName == taskName);
        
        await _firestore.collection("bookings").doc(bookingId).update({
          "completedTasks": updatedTasks,
          "taskProofs": updatedProofs.map((e) => e.toMap()).toList()
        });
      }
    } catch (e) {
      debugPrint("Proof error: $e");
    } finally {
      _setUiState(_uiState.copyWith(isPhotoUploading: false));
    }
  }
}
