import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// Drives continuous caregiver location publishing while a job is IN_PROGRESS.
///
/// Mirrors care2's foreground location service, but in this app's "while the app
/// is alive" model: a Riverpod provider watches the caregiver's active bookings
/// and calls [startForCaregiver] / [stop]. iOS keeps delivering positions in the
/// background via [LocationService.positionStream] (AppleSettings background
/// updates); Android uses a foreground-service notification.
class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService _instance = LocationTrackingService._();
  factory LocationTrackingService() => _instance;

  final LocationService _location = LocationService();
  StreamSubscription<Position>? _sub;
  String? _caregiverId;
  bool _starting = false;

  bool get isTracking => _sub != null;

  /// Begins publishing this caregiver's live position. Idempotent: calling it
  /// again for the same caregiver while already tracking is a no-op.
  Future<void> startForCaregiver(String caregiverId) async {
    if (_caregiverId == caregiverId && (_sub != null || _starting)) return;
    if (_starting) return;
    _starting = true;
    try {
      await stop();
      final granted = await _location.requestAlwaysPermission();
      if (!granted) return;

      _caregiverId = caregiverId;
      // Push an immediate fix so the client map updates without waiting for the
      // first stream movement.
      final first = await _location.getCurrentPosition();
      if (first != null) {
        await _location.updateCaregiverLocation(
            caregiverId, first.latitude, first.longitude);
      }

      _sub = _location.positionStream().listen((pos) {
        final id = _caregiverId;
        if (id == null) return;
        _location.updateCaregiverLocation(id, pos.latitude, pos.longitude);
      }, onError: (_) {});
    } finally {
      _starting = false;
    }
  }

  /// Stops publishing and clears the last position from the client-visible path.
  Future<void> stop() async {
    final id = _caregiverId;
    await _sub?.cancel();
    _sub = null;
    _caregiverId = null;
    if (id != null) {
      try {
        await _location.clearCaregiverLocation(id);
      } catch (_) {}
    }
  }
}
