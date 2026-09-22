class AppConstants {
  AppConstants._();

  // Firestore collection names (must match care2 exactly)
  static const String usersCollection = 'users';
  static const String bookingsCollection = 'bookings';
  static const String elderProfilesCollection = 'elders';
  static const String chatsCollection = 'chats';
  static const String reviewsCollection = 'reviews';
  static const String careLogsCollection = 'care_logs';
  static const String transactionsCollection = 'transactions';
  static const String leaveRequestsCollection = 'leave_requests';
  static const String subscriptionPlansCollection = 'subscription_plans';
  static const String sosAlertsCollection = 'sos_alerts';
  static const String alertsCollection = 'alerts';
  static const String settingsCollection = 'settings';

  // Realtime Database paths (location only)
  static const String rtdbLocations = 'locations';

  // Shared preferences keys (matches care2 KinaCarePrefs)
  static const String prefUserId = 'user_id';
  static const String prefUserRole = 'user_role';
  static const String prefIsSinhala = 'is_sinhala';
  static const String prefOnboarded = 'onboarded';

  // Notification channel IDs (matches care2)
  static const String channelMedicineId = 'medicine_reminders';
  static const String channelJobId = 'job_alerts';
  static const String channelSosId = 'sos_alerts';
  static const String channelKycId = 'kyc_status';
  static const String channelGeofenceId = 'geofence_alerts';
  static const String channelGeneralId = 'golden_hand_notifications';

  // Timeouts & limits
  static const int locationUpdateIntervalSeconds = 10;
  static const int chatMessagePageSize = 50;
  static const int bookingListPageSize = 20;
  static const int maxPhotoUploadSizeKb = 1024;
  static const double defaultMapZoom = 15.0;
  static const double geofenceRadiusMeters = 50.0;

  // Commission & payment
  static const double defaultCommissionRate = 15.0;

  // Acceptance timeout: caregiver must start job within this window after accepting
  static const int acceptanceTimeoutMs = 30 * 60 * 1000; // 30 minutes
}
