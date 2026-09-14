import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/data_models.dart';

class FindCaregiverUiState {
  final bool isLoading;
  final List<User> caregivers;
  final String? errorMessage;

  FindCaregiverUiState({
    this.isLoading = true,
    this.caregivers = const [],
    this.errorMessage,
  });

  FindCaregiverUiState copyWith({
    bool? isLoading,
    List<User>? caregivers,
    String? errorMessage,
  }) {
    return FindCaregiverUiState(
      isLoading: isLoading ?? this.isLoading,
      caregivers: caregivers ?? this.caregivers,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FindCaregiverViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FindCaregiverUiState _uiState = FindCaregiverUiState();
  FindCaregiverUiState get uiState => _uiState;

  List<User> _allCaregivers = [];

  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  String _selectedCategory = "All";
  String get selectedCategory => _selectedCategory;

  List<Review> _reviewsState = [];
  List<Review> get reviewsState => _reviewsState;

  bool _isReviewsLoading = false;
  bool get isReviewsLoading => _isReviewsLoading;

  List<String> _favoriteCaregiverIds = [];
  List<String> get favoriteCaregiverIds => _favoriteCaregiverIds;

  FindCaregiverViewModel() {
    fetchCaregiversFromFirebase();
    fetchFavoriteCaregivers();
  }

  void _setUiState(FindCaregiverUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void fetchFavoriteCaregivers() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    _firestore.collection("users").doc(currentUserId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final user = User.fromMap(snapshot.data()!);
        _favoriteCaregiverIds = user.favoriteCaregivers;
        notifyListeners();
      }
    });
  }

  Future<void> toggleFavorite(String caregiverId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    
    final currentFavs = List<String>.from(_favoriteCaregiverIds);
    if (currentFavs.contains(caregiverId)) {
      currentFavs.remove(caregiverId);
    } else {
      currentFavs.add(caregiverId);
    }
    
    await _firestore.collection("users").doc(currentUserId).update({
      "favoriteCaregivers": currentFavs
    });
  }

  Future<void> fetchCaregiversFromFirebase() async {
    try {
      final snapshot = await _firestore.collection("users")
          .where("role", whereIn: ["CAREGIVER", "NURSE"])
          .get();

      final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

      _allCaregivers = snapshot.docs
          .map((doc) => User.fromMap(doc.data()))
          .where((it) => (it.isVerified || it.kycStatus == "APPROVED") && !it.isBusy && !it.onLeaveDates.contains(todayStr))
          .toList();

      _allCaregivers.sort((a, b) => b.rating.compareTo(a.rating));
      _applyFilters();

    } catch (e) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void updateCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void _applyFilters() {
    var filteredList = _allCaregivers;

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filteredList = filteredList.where((it) =>
          it.name.toLowerCase().contains(query) ||
          it.address.toLowerCase().contains(query)).toList();
    }

    if (_selectedCategory == "Caregiver") {
      filteredList = filteredList.where((it) => it.role == "CAREGIVER").toList();
    } else if (_selectedCategory == "Nurse") {
      filteredList = filteredList.where((it) => it.role == "NURSE").toList();
    }

    _setUiState(_uiState.copyWith(isLoading: false, caregivers: filteredList));
  }

  Future<void> fetchReviewsForCaregiver(String caregiverId) async {
    _isReviewsLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore.collection("reviews")
          .where("caregiverId", isEqualTo: caregiverId)
          .get();

      _reviewsState = snapshot.docs.map((doc) => Review.fromMap(doc.data())).toList();
      _reviewsState.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      _reviewsState = [];
    } finally {
      _isReviewsLoading = false;
      notifyListeners();
    }
  }

  void clearReviews() {
    _reviewsState = [];
    notifyListeners();
  }
}
