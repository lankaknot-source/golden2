import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthState {
  final bool isLoading;
  final bool isSuccess;
  final bool needsRoleSelection;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isSuccess = false,
    this.needsRoleSelection = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isSuccess,
    bool? needsRoleSelection,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      needsRoleSelection: needsRoleSelection ?? this.needsRoleSelection,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthState _state = AuthState();
  AuthState get state => _state;

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (_auth.currentUser != null) {
        _setState(_state.copyWith(isSuccess: true, isLoading: false));
      }
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> loginWithGoogle(String idToken, String accessToken) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      await _auth.signInWithCredential(credential);
      final User? user = _auth.currentUser;

      if (user != null) {
        final DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _setState(_state.copyWith(isSuccess: true, isLoading: false));
        } else {
          _setState(_state.copyWith(needsRoleSelection: true, isLoading: false));
        }
      }
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> saveGoogleUserRole(String role) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userMap = {
          "id": user.uid,
          "name": user.displayName ?? "No Name",
          "email": user.email ?? "",
          "role": role,
          "isVerified": false,
          "walletBalance": 0.0,
        };
        await _firestore.collection('users').doc(user.uid).set(userMap);
        _setState(_state.copyWith(isSuccess: true, isLoading: false));
      }
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> signUp(String email, String password, String name, String role) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final User? user = _auth.currentUser;

      if (user != null) {
        final userMap = {
          "id": user.uid,
          "name": name,
          "email": email,
          "role": role,
          "isVerified": false,
          "walletBalance": 0.0,
        };
        await _firestore.collection('users').doc(user.uid).set(userMap);
        _setState(_state.copyWith(isSuccess: true, isLoading: false));
      }
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void logout() {
    _auth.signOut();
    _setState(AuthState());
  }

  Future<void> sendPasswordResetEmail(String email, Function(bool, String) onResult) async {
    if (email.isEmpty) {
      onResult(false, "කරුණාකර ඔබගේ ඊමේල් ලිපිනය ඇතුලත් කරන්න.");
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      onResult(true, "Password Reset ලින්ක් එක ඔබගේ ඊමේල් ගිණුමට යවන ලදී. කරුණාකර Inbox එක පරීක්ෂා කරන්න.");
    } catch (e) {
      onResult(false, e.toString());
    }
  }
}
