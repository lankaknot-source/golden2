import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/data_models.dart';

class ProfileUiState {
  final bool isLoading;
  final User? userData;
  final String? errorMessage;
  final bool isSaving;
  final bool isSaveSuccess;
  final double registrationFee;

  ProfileUiState({
    this.isLoading = true,
    this.userData,
    this.errorMessage,
    this.isSaving = false,
    this.isSaveSuccess = false,
    this.registrationFee = 1000.0,
  });

  ProfileUiState copyWith({
    bool? isLoading,
    User? userData,
    String? errorMessage,
    bool? isSaving,
    bool? isSaveSuccess,
    double? registrationFee,
  }) {
    return ProfileUiState(
      isLoading: isLoading ?? this.isLoading,
      userData: userData ?? this.userData,
      errorMessage: errorMessage ?? this.errorMessage,
      isSaving: isSaving ?? this.isSaving,
      isSaveSuccess: isSaveSuccess ?? this.isSaveSuccess,
      registrationFee: registrationFee ?? this.registrationFee,
    );
  }
}

class ProfileViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProfileUiState _uiState = ProfileUiState();
  ProfileUiState get uiState => _uiState;

  ProfileViewModel() {
    fetchUserProfile();
    fetchSystemSettings();
  }

  void _setUiState(ProfileUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void fetchUserProfile() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    _firestore.collection("users").doc(userId).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        final user = User.fromMap(snapshot.data()!);
        _setUiState(_uiState.copyWith(isLoading: false, userData: user));

        final isCaregiverRole = user.role == "CAREGIVER" || user.role == "NURSE";
        if (isCaregiverRole && user.kycStatus == "APPROVED" && !user.isVerified) {
          await _firestore.collection("users").doc(userId).update({"isVerified": true});
        }
      }
    }, onError: (e) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: e.toString()));
    });
  }

  void fetchSystemSettings() {
    _firestore.collection("settings").doc("general").snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final fee = snapshot.data()?['registrationFee']?.toDouble() ?? 1000.0;
        _setUiState(_uiState.copyWith(registrationFee: fee));
      }
    });
  }

  Future<void> requestLeave(int dateMs, String reason, Function(bool, String) onResult) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userName = _uiState.userData?.name ?? "Caregiver";
      final dateStr = DateTime.fromMillisecondsSinceEpoch(dateMs).toIso8601String().split('T')[0];

      final leaveId = const Uuid().v4();
      final leaveReq = LeaveRequest(
        id: leaveId,
        caregiverId: userId,
        caregiverName: userName,
        dateMs: dateMs,
        dateString: dateStr,
        reason: reason,
        status: "PENDING",
        requestedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _firestore.collection("leave_requests").doc(leaveId).set(leaveReq.toMap());
      onResult(true, "නිවාඩු ඉල්ලීම යවන ලදී. Admin අනුමැතිය ලැබෙන තෙක් රැඳී සිටින්න.");
    } catch (e) {
      onResult(false, e.toString());
    }
  }

  Future<void> payRegistrationFee(Function(bool, String) onResult) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final currentFee = _uiState.registrationFee;

      await _firestore.collection("users").doc(userId).update({"isVerified": true});

      final txId = const Uuid().v4();
      await _firestore.collection("transactions").doc(txId).set({
        "id": txId,
        "userId": userId,
        "amount": currentFee,
        "type": "FEE",
        "description": "Client Registration Fee",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });

      onResult(true, "ගෙවීම සාර්ථකයි! ඔබගේ ගිණුම සම්පූර්ණයෙන්ම සක්‍රීය විය.");
    } catch (e) {
      onResult(false, e.toString());
    }
  }

  Future<void> updateProfileFull(String name, String phone, double hourlyRate, String profileImageBase64) async {
    _setUiState(_uiState.copyWith(isSaving: true, isSaveSuccess: false));
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final Map<String, dynamic> updates = {
        "name": name,
        "phone": phone,
        "hourlyRate": hourlyRate,
      };
      
      if (profileImageBase64.isNotEmpty) {
        updates["profileImageUrl"] = profileImageBase64;
      }

      await _firestore.collection("users").doc(userId).update(updates);
      _setUiState(_uiState.copyWith(isSaving: false, isSaveSuccess: true));
    } catch (e) {
      _setUiState(_uiState.copyWith(isSaving: false, errorMessage: e.toString()));
    }
  }

  void resetSaveSuccess() {
    _setUiState(_uiState.copyWith(isSaveSuccess: false));
  }
}
