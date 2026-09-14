import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/data_models.dart';

class HomeUiState {
  final bool isLoading;
  final User? userData;
  final List<User> topCaregivers;
  final Booking? activeBooking;
  final ElderProfile? activeElder;
  final String? errorMessage;
  final bool isBirthday;
  final List<ElderProfile> clientElders;

  HomeUiState({
    this.isLoading = true,
    this.userData,
    this.topCaregivers = const [],
    this.activeBooking,
    this.activeElder,
    this.errorMessage,
    this.isBirthday = false,
    this.clientElders = const [],
  });

  HomeUiState copyWith({
    bool? isLoading,
    User? userData,
    List<User>? topCaregivers,
    Booking? activeBooking,
    ElderProfile? activeElder,
    String? errorMessage,
    bool? isBirthday,
    List<ElderProfile>? clientElders,
    bool clearActiveData = false,
  }) {
    return HomeUiState(
      isLoading: isLoading ?? this.isLoading,
      userData: userData ?? this.userData,
      topCaregivers: topCaregivers ?? this.topCaregivers,
      activeBooking: clearActiveData ? null : (activeBooking ?? this.activeBooking),
      activeElder: clearActiveData ? null : (activeElder ?? this.activeElder),
      errorMessage: errorMessage ?? this.errorMessage,
      isBirthday: isBirthday ?? this.isBirthday,
      clientElders: clientElders ?? this.clientElders,
    );
  }
}

class HomeViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  HomeUiState _uiState = HomeUiState();
  HomeUiState get uiState => _uiState;

  List<Review> _reviewsState = [];
  List<Review> get reviewsState => _reviewsState;

  bool _isReviewsLoading = false;
  bool get isReviewsLoading => _isReviewsLoading;

  List<SubscriptionPlan> _subscriptionPlans = [];
  List<SubscriptionPlan> get subscriptionPlans => _subscriptionPlans;

  HomeViewModel() {
    fetchUserData();
    fetchSubscriptionPlans();
  }

  void _setUiState(HomeUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void _setReviewsState(List<Review> reviews) {
    _reviewsState = reviews;
    notifyListeners();
  }

  void _setReviewsLoading(bool loading) {
    _isReviewsLoading = loading;
    notifyListeners();
  }

  void _setSubscriptionPlans(List<SubscriptionPlan> plans) {
    _subscriptionPlans = plans;
    notifyListeners();
  }

  void fetchSubscriptionPlans() {
    _firestore.collection('subscription_plans').snapshots().listen((snapshot) {
      final plans = snapshot.docs.map((doc) => SubscriptionPlan.fromMap(doc.data())).toList();
      _setSubscriptionPlans(plans);
    });
  }

  void fetchUserData() {
    _setUiState(_uiState.copyWith(isLoading: true));
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: "Not logged in"));
      return;
    }

    _firestore.collection('users').doc(userId).snapshots().listen((document) async {
      if (document.exists) {
        final user = User.fromMap(document.data()!);

        // Auto-verify Caregivers/Nurses if KYC is APPROVED
        bool isCaregiverRole = user.role == "CAREGIVER" || user.role == "NURSE";
        if (isCaregiverRole && user.kycStatus == "APPROVED" && !user.isVerified) {
          await _firestore.collection('users').doc(userId).update({"isVerified": true});
        }

        bool isUserBirthday = false;
        if (user.dob.isNotEmpty) {
          try {
            final parts = user.dob.replaceAll("/", "-").split("-");
            if (parts.length >= 3) {
              int? month;
              int? day;
              if (parts[0].length == 4) {
                month = int.tryParse(parts[1]);
                day = int.tryParse(parts[2]);
              } else {
                day = int.tryParse(parts[0]);
                month = int.tryParse(parts[1]);
              }

              final now = DateTime.now();
              if (month == now.month && day == now.day) {
                isUserBirthday = true;
              }
            }
          } catch (_) {}
        }

        if (user.role == "CLIENT") {
          _firestore.collection("elders").where("clientId", isEqualTo: userId).snapshots().listen((snap) {
            final elders = snap.docs.map((doc) => ElderProfile.fromMap(doc.data())).toList();
            _setUiState(_uiState.copyWith(clientElders: elders));
          });

          try {
            final caregiversSnapshot = await _firestore.collection("users")
                .where("role", whereIn: ["CAREGIVER", "NURSE"])
                .get();

            final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
            
            var caregiversList = caregiversSnapshot.docs
                .map((doc) => User.fromMap(doc.data()))
                .where((it) => (it.isVerified || it.kycStatus == "APPROVED") && !it.isBusy && !it.onLeaveDates.contains(todayStr))
                .toList();

            caregiversList.sort((a, b) => b.rating.compareTo(a.rating));
            if (caregiversList.length > 5) caregiversList = caregiversList.sublist(0, 5);

            _setUiState(_uiState.copyWith(isLoading: false, userData: user, topCaregivers: caregiversList, isBirthday: isUserBirthday));
          } catch (e) {
            _setUiState(_uiState.copyWith(isLoading: false, userData: user, isBirthday: isUserBirthday));
          }
        } else if (user.role == "CAREGIVER" || user.role == "NURSE") {
          _firestore.collection("bookings")
              .where("caregiverId", isEqualTo: userId)
              .where("status", whereIn: ["ACCEPTED", "IN_PROGRESS"])
              .snapshots()
              .listen((snap) async {
            if (snap.docs.isNotEmpty) {
              final booking = Booking.fromMap(snap.docs.first.data());
              _setUiState(_uiState.copyWith(activeBooking: booking));
              if (booking.elderId.isNotEmpty) {
                final elderDoc = await _firestore.collection("elders").doc(booking.elderId).get();
                if (elderDoc.exists) {
                  _setUiState(_uiState.copyWith(activeElder: ElderProfile.fromMap(elderDoc.data()!)));
                }
              }
            } else {
              _setUiState(_uiState.copyWith(clearActiveData: true));
            }
          });
          _setUiState(_uiState.copyWith(isLoading: false, userData: user, isBirthday: isUserBirthday));
        }
      } else {
        _setUiState(_uiState.copyWith(isLoading: false, errorMessage: "User data not found"));
      }
    }, onError: (e) {
      _setUiState(_uiState.copyWith(isLoading: false, errorMessage: e.toString()));
    });
  }

  void dismissBirthdayPopup() {
    _setUiState(_uiState.copyWith(isBirthday: false));
  }

  Future<void> purchaseSubscriptionPlan(SubscriptionPlan plan, String elderId, Function(bool, String) onResult) async {
    try {
      final clientId = _auth.currentUser?.uid;
      if (clientId == null) return;
      final jobId = const Uuid().v4();

      final newBooking = Booking(
        id: jobId,
        clientId: clientId,
        caregiverId: '',
        elderId: elderId,
        status: "BROADCASTED",
        isEmergency: true,
        requestedTime: DateTime.now().millisecondsSinceEpoch,
        jobDescription: "Premium Package: ${plan.title}\n\n${plan.description}",
        isSubscriptionBooking: true,
        planName: plan.title,
        allowedCaregivers: plan.assignedCaregivers,
        totalAmount: plan.price,
        isPaid: true,
      );

      await _firestore.collection("bookings").doc(jobId).set(newBooking.toMap());

      final txId = const Uuid().v4();
      final txData = {
        "id": txId,
        "userId": clientId,
        "amount": plan.price,
        "type": "PACKAGE_FEE",
        "description": "Purchased Package: ${plan.title}",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };
      await _firestore.collection("transactions").doc(txId).set(txData);

      onResult(true, "සාර්ථකව මිලදී ගන්නා ලදී! Admin අනුයුක්ත කළ සේවකයින්ට පණිවිඩය යවන ලදී.");
    } catch (e) {
      onResult(false, "දෝෂයකි: $e");
    }
  }

  Future<void> fetchReviewsForCaregiver(String caregiverId) async {
    _setReviewsLoading(true);
    try {
      final snapshot = await _firestore.collection("reviews").where("caregiverId", isEqualTo: caregiverId).get();
      final reviews = snapshot.docs.map((doc) => Review.fromMap(doc.data())).toList();
      reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _setReviewsState(reviews);
    } catch (e) {
      _setReviewsState([]);
    } finally {
      _setReviewsLoading(false);
    }
  }

  void clearReviews() {
    _setReviewsState([]);
  }

  void logout() {
    _auth.signOut();
  }
}
