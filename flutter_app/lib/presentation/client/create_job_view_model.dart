import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/data_models.dart';

class CreateJobUiState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final List<ElderProfile> elders;
  final double selectedCaregiverRate;

  CreateJobUiState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.elders = const [],
    this.selectedCaregiverRate = 0.0,
  });

  CreateJobUiState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    List<ElderProfile>? elders,
    double? selectedCaregiverRate,
  }) {
    return CreateJobUiState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      elders: elders ?? this.elders,
      selectedCaregiverRate: selectedCaregiverRate ?? this.selectedCaregiverRate,
    );
  }
}

class CreateJobViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CreateJobUiState _uiState = CreateJobUiState();
  CreateJobUiState get uiState => _uiState;

  CreateJobViewModel() {
    fetchElders();
  }

  void _setUiState(CreateJobUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void fetchElders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    _firestore.collection("elders")
        .where("clientId", isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      final eldersList = snapshot.docs.map((doc) => ElderProfile.fromMap(doc.data())).toList();
      _setUiState(_uiState.copyWith(elders: eldersList));
    });
  }

  Future<void> fetchCaregiverRate(String? caregiverId) async {
    if (caregiverId == null || caregiverId.isEmpty) return;
    try {
      final doc = await _firestore.collection("users").doc(caregiverId).get();
      if (doc.exists) {
        final user = User.fromMap(doc.data()!);
        _setUiState(_uiState.copyWith(selectedCaregiverRate: user.hourlyRate));
      }
    } catch (e) {
      // Ignore error, fallback to 0.0
    }
  }

  Future<void> createJobRequest({
    required double lat,
    required double lng,
    required String description,
    required bool isEmergency,
    required String elderId,
    String? selectedCaregiverId,
    required int scheduledTimeMs,
    required String careCategory,
    required String serviceType,
    required String durationType,
    required List<String> requestedTasks,
    required int estimatedHours,
  }) async {
    _setUiState(_uiState.copyWith(isLoading: true, errorMessage: null, isSuccess: false));
    try {
      final clientId = _auth.currentUser?.uid;
      if (clientId == null) return;
      
      final jobId = const Uuid().v4();
      final totalAmount = estimatedHours * _uiState.selectedCaregiverRate;

      final newBooking = Booking(
        id: jobId,
        clientId: clientId,
        caregiverId: selectedCaregiverId ?? '',
        elderId: elderId,
        status: (selectedCaregiverId != null && selectedCaregiverId.isNotEmpty) ? "PENDING" : "BROADCASTED",
        locationLat: lat,
        locationLng: lng,
        jobDescription: description,
        isEmergency: isEmergency,
        requestedTime: DateTime.now().millisecondsSinceEpoch,
        scheduledTime: scheduledTimeMs,
        careCategory: careCategory,
        serviceType: serviceType,
        durationType: durationType,
        requestedTasks: requestedTasks,
        estimatedHours: estimatedHours,
        hourlyRate: _uiState.selectedCaregiverRate,
        totalAmount: totalAmount,
        isSubscriptionBooking: false,
        planName: '',
        allowedCaregivers: const [],
        isPaid: false,
      );

      await _firestore.collection("bookings").doc(jobId).set(newBooking.toMap());
      _setUiState(_uiState.copyWith(isLoading: false, isSuccess: true));
    } catch (e) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void resetSuccessState() {
    _setUiState(_uiState.copyWith(isSuccess: false));
  }
}
