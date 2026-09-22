import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Foreground (while-in-use) permission — enough to show the map / one-shot fix.
  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Escalates to "Always" so location keeps publishing during an active job
  /// even when the app is backgrounded (caregiver live-tracking + geofence).
  /// On iOS this is a separate prompt that can only follow a granted
  /// while-in-use grant, so we request that first.
  Future<bool> requestAlwaysPermission() async {
    final whileInUse = await requestPermission();
    if (!whileInUse) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// A continuous position stream configured for background delivery on each
  /// platform. iOS needs [AppleSettings.allowBackgroundLocationUpdates]; Android
  /// needs a foreground-service notification to keep emitting when backgrounded.
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(locationSettings: _backgroundSettings());
  }

  LocationSettings _backgroundSettings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          activityType: ActivityType.otherNavigation,
          pauseLocationUpdatesAutomatically: false,
          // Shows the blue status-bar indicator while tracking in the background.
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          forceLocationManager: false,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Golden Hand — Job in progress',
            notificationText: 'Sharing your live location with the client.',
            enableWakeLock: true,
          ),
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        );
    }
  }

  /// Publishes the caregiver's live position to the exact paths the client's
  /// live-tracking map reads: RTDB `locations/{caregiverId}` (primary) and the
  /// Firestore user doc (fallback, also mirrors the Kotlin app).
  Future<void> updateCaregiverLocation(
    String caregiverId,
    double lat,
    double lng,
  ) async {
    await _rtdb.ref('${AppConstants.rtdbLocations}/$caregiverId').set({
      'lat': lat,
      'lng': lng,
      'updatedAt': ServerValue.timestamp,
    });
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(caregiverId)
        .set({
      'locationLat': lat,
      'locationLng': lng,
      'lastLocationAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  /// Clears the published location when a job ends so stale coordinates don't
  /// linger on the client map.
  Future<void> clearCaregiverLocation(String caregiverId) async {
    await _rtdb.ref('${AppConstants.rtdbLocations}/$caregiverId').remove();
  }
}
