import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/model/data_models.dart';

class MapUiState {
  final bool isLoading;
  final String role;
  final Booking? activeBooking;
  final double clientLat;
  final double clientLng;
  final double caregiverLat;
  final double caregiverLng;
  final double distanceInMeters;
  final String? errorMessage;

  MapUiState({
    this.isLoading = true,
    this.role = "CLIENT",
    this.activeBooking,
    this.clientLat = 0.0,
    this.clientLng = 0.0,
    this.caregiverLat = 0.0,
    this.caregiverLng = 0.0,
    this.distanceInMeters = 0.0,
    this.errorMessage,
  });

  MapUiState copyWith({
    bool? isLoading,
    String? role,
    Booking? activeBooking,
    double? clientLat,
    double? clientLng,
    double? caregiverLat,
    double? caregiverLng,
    double? distanceInMeters,
    String? errorMessage,
    bool clearActiveBooking = false,
  }) {
    return MapUiState(
      isLoading: isLoading ?? this.isLoading,
      role: role ?? this.role,
      activeBooking: clearActiveBooking ? null : (activeBooking ?? this.activeBooking),
      clientLat: clientLat ?? this.clientLat,
      clientLng: clientLng ?? this.clientLng,
      caregiverLat: caregiverLat ?? this.caregiverLat,
      caregiverLng: caregiverLng ?? this.caregiverLng,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class MapViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MapUiState _uiState = MapUiState();
  MapUiState get uiState => _uiState;

  MapViewModel() {
    loadMapData();
  }

  void _setUiState(MapUiState state) {
    _uiState = state;
    notifyListeners();
  }

  void loadMapData() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection("users").doc(userId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final role = doc.data()?['role'] ?? "CLIENT";
      final queryField = role == "CAREGIVER" || role == "NURSE" ? "caregiverId" : "clientId";

      _firestore.collection("bookings")
          .where(queryField, isEqualTo: userId)
          .where("status", whereIn: ["ACCEPTED", "IN_PROGRESS"])
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final booking = Booking.fromMap(snapshot.docs.first.data());

          if (role == "CLIENT") {
            if (booking.caregiverId?.isNotEmpty == true) {
              _firestore.collection("users").doc(booking.caregiverId).snapshots().listen((cgSnap) {
                final cgLat = cgSnap.data()?['locationLat']?.toDouble() ?? 0.0;
                final cgLng = cgSnap.data()?['locationLng']?.toDouble() ?? 0.0;
                final dist = _calculateDistance(booking.locationLat, booking.locationLng, cgLat, cgLng);

                _setUiState(_uiState.copyWith(
                  isLoading: false, role: role, activeBooking: booking,
                  clientLat: booking.locationLat, clientLng: booking.locationLng,
                  caregiverLat: cgLat, caregiverLng: cgLng, distanceInMeters: dist
                ));
              });
            }
          } else {
            final myLat = doc.data()?['locationLat']?.toDouble() ?? 0.0;
            final myLng = doc.data()?['locationLng']?.toDouble() ?? 0.0;
            final dist = _calculateDistance(booking.locationLat, booking.locationLng, myLat, myLng);

            _setUiState(_uiState.copyWith(
              isLoading: false, role: role, activeBooking: booking,
              clientLat: booking.locationLat, clientLng: booking.locationLng,
              caregiverLat: myLat, caregiverLng: myLng, distanceInMeters: dist
            ));
          }
        } else {
          final myLat = doc.data()?['locationLat']?.toDouble() ?? 0.0;
          final myLng = doc.data()?['locationLng']?.toDouble() ?? 0.0;
          _setUiState(_uiState.copyWith(
            isLoading: false, role: role, clearActiveBooking: true,
            caregiverLat: myLat, caregiverLng: myLng
          ));
        }
      });
    });
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    if (lat1 == 0.0 || lat2 == 0.0) return 0.0;
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
