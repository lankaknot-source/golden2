import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/location_tracking_service.dart';
import '../../domain/models/booking_model.dart';
import 'auth_provider.dart';
import 'booking_provider.dart';

/// Keeps caregiver live-location publishing in sync with their active job.
///
/// While a caregiver has an IN_PROGRESS booking, this starts continuous
/// (background-capable) location tracking; when none is active it stops and
/// clears the published location. Watch it once for the whole session
/// (see app.dart) so it stays alive alongside the global notification listener.
final locationTrackingProvider = Provider<void>((ref) {
  // Location plugins aren't available on web; tracking is a mobile concern.
  if (kIsWeb) return;

  final tracker = LocationTrackingService();
  final user = ref.watch(currentUserProvider);

  if (user == null || !user.isCaregiverOrNurse) {
    tracker.stop();
    return;
  }

  final hasActiveJob = ref.watch(caregiverActiveBookingsProvider).maybeWhen(
        data: (bookings) =>
            bookings.any((b) => b.status == BookingStatus.inProgress),
        orElse: () => false,
      );

  if (hasActiveJob) {
    tracker.startForCaregiver(user.uid);
  } else {
    tracker.stop();
  }
});
