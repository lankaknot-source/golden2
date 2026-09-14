import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/data_models.dart';

class ElderProfileUiState {
  final bool isLoading;
  final List<ElderProfile> elders;
  final String? errorMessage;
  final bool isSaving;

  ElderProfileUiState({
    this.isLoading = true,
    this.elders = const [],
    this.errorMessage,
    this.isSaving = false,
  });

  ElderProfileUiState copyWith({
    bool? isLoading,
    List<ElderProfile>? elders,
    String? errorMessage,
    bool? isSaving,
  }) {
    return ElderProfileUiState(
      isLoading: isLoading ?? this.isLoading,
      elders: elders ?? this.elders,
      errorMessage: errorMessage ?? this.errorMessage,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class ElderProfileViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ElderProfileUiState _uiState = ElderProfileUiState();
  ElderProfileUiState get uiState => _uiState;

  ElderProfileViewModel() {
    fetchElders();
  }

  void _setUiState(ElderProfileUiState state) {
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
      _setUiState(_uiState.copyWith(isLoading: false, elders: eldersList));
    }, onError: (error) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: error.toString()));
    });
  }

  Future<void> addElder(String name, String age, String gender, String conditions, String contact, String language, Function(bool, String) onComplete) async {
    _setUiState(_uiState.copyWith(isSaving: true));
    try {
      final clientId = _auth.currentUser?.uid;
      if (clientId == null) {
        onComplete(false, "User not authenticated");
        return;
      }
      final id = const Uuid().v4();

      final conditionList = conditions.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final ageInt = int.tryParse(age) ?? 0;

      final elder = ElderProfile(
        id: id,
        clientId: clientId,
        name: name,
        age: ageInt,
        gender: gender,
        medicalConditions: conditionList,
        emergencyContact: contact,
        requiredLanguage: language,
        medicineList: const [],
      );

      await _firestore.collection("elders").doc(id).set(elder.toMap());
      _setUiState(_uiState.copyWith(isSaving: false));
      onComplete(true, "සාර්ථකව එකතු කරන ලදී!");
    } catch (e) {
      _setUiState(_uiState.copyWith(isSaving: false, errorMessage: e.toString()));
      onComplete(false, e.toString());
    }
  }

  Future<void> deleteElder(String id) async {
    try {
      await _firestore.collection("elders").doc(id).delete();
    } catch (e) {
      // Ignore
    }
  }

  Future<void> addMedicineReminderWithPhoto(
      String elderId, 
      List<MedicineReminder> currentList, 
      String timeStr, 
      String medName, 
      String base64Photo, 
      Function(bool) onResult) async {
    
    if (timeStr.trim().isEmpty || medName.trim().isEmpty) return;

    _setUiState(_uiState.copyWith(isSaving: true));
    try {
      final medId = const Uuid().v4();
      final newMed = MedicineReminder(id: medId, time: timeStr, name: medName, photoBase64: base64Photo);
      
      final updatedList = List<MedicineReminder>.from(currentList)..add(newMed);
      
      await _firestore.collection("elders").doc(elderId).update({
        "medicineList": updatedList.map((e) => e.toMap()).toList()
      });

      // TODO: Schedule local notification / alarm here using flutter_local_notifications

      _setUiState(_uiState.copyWith(isSaving: false));
      onResult(true);
    } catch (e) {
      _setUiState(_uiState.copyWith(isSaving: false));
      onResult(false);
    }
  }

  Future<void> removeMedicineReminder(String elderId, List<MedicineReminder> currentList, MedicineReminder reminderToRemove) async {
    final updatedList = List<MedicineReminder>.from(currentList)..removeWhere((e) => e.id == reminderToRemove.id);
    try {
      await _firestore.collection("elders").doc(elderId).update({
        "medicineList": updatedList.map((e) => e.toMap()).toList()
      });
      // TODO: Cancel local notification / alarm
    } catch (e) {
      // Ignore
    }
  }
}
