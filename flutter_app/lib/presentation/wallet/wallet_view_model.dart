import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/model/data_models.dart';

class WalletUiState {
  final bool isLoading;
  final double balance;
  final List<WalletTransaction> transactions;
  final String? errorMessage;

  WalletUiState({
    this.isLoading = true,
    this.balance = 0.0,
    this.transactions = const [],
    this.errorMessage,
  });

  WalletUiState copyWith({
    bool? isLoading,
    double? balance,
    List<WalletTransaction>? transactions,
    String? errorMessage,
  }) {
    return WalletUiState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class WalletViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  WalletUiState _uiState = WalletUiState();
  WalletUiState get uiState => _uiState;

  WalletViewModel() {
    fetchWalletData();
  }

  void _setUiState(WalletUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void fetchWalletData() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection("users").doc(userId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final bal = snapshot.data()?['walletBalance']?.toDouble() ?? 0.0;
        _setUiState(_uiState.copyWith(balance: bal));
      }
    });

    _firestore.collection("transactions")
        .where("userId", isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) => WalletTransaction.fromMap(doc.data())).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _setUiState(_uiState.copyWith(isLoading: false, transactions: list));
    }, onError: (e) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: e.toString()));
    });
  }
}
