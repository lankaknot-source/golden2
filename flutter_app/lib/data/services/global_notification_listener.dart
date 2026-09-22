import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/booking_model.dart';
import '../../domain/models/user_model.dart';
import '../repositories/booking_repository.dart';
import 'notification_service.dart';

/// Mirrors care2 `MainActivity`'s in-app Firestore listeners.
///
/// While the app is alive (foreground/background) this watches Firestore and
/// raises local notifications for KYC status changes, new broadcasted jobs,
/// booking status changes and payments. No server / Cloud Functions required —
/// this is exactly how care2 works on the free plan.
///
/// (Geofence "caregiver 50m away" alerts are handled together with the live
/// location tracking work — see IOS_RELEASE_TODO.txt 2.3 / 4.3.)
class GlobalNotificationListener {
  GlobalNotificationListener({required this.uid, required this.role});

  final String uid;
  final UserRole role;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notif = NotificationService();
  final BookingRepository _repo = BookingRepository();

  final List<StreamSubscription<dynamic>> _subs = [];

  String? _lastKycStatus;
  bool _kycFirstRun = true;
  bool _myBookingsFirstRun = true;
  bool _newJobsFirstRun = true;

  void start() {
    _listenKyc();
    if (role == UserRole.client) {
      _listenClientBookings();
    } else {
      _listenCaregiverBookings();
      _listenNewJobs();
    }
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  // ── Client-side lazy resolution of stale bookings (free-plan replacement for
  //    care2's AutoEndJobWorker / BroadcastConfirmTimeoutWorker). Runs only on
  //    the caregiver device, which can write its own wallet / assignment. ───────
  void _resolveStale(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in docs) {
      final b = Booking.fromMap(d.data(), d.id);
      if (b.status == BookingStatus.inProgress) {
        final endMs = _expectedEndMs(b);
        if (endMs != null && now > endMs) {
          _repo.autoCompleteOverdue(b.id);
        }
      } else if (b.status == BookingStatus.accepted && b.isAcceptanceExpired) {
        _repo.expireAcceptance(b.id);
      }
    }
  }

  int? _expectedEndMs(Booking b) {
    if (b.endTime != null && b.endTime! > 0) return b.endTime;
    if (b.startTime != null && b.estimatedHours > 0) {
      return b.startTime! + b.estimatedHours * 3600 * 1000;
    }
    return null;
  }

  // ── KYC status (APPROVED / REJECTED) ───────────────────────────────────────
  void _listenKyc() {
    final sub = _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final status = data['kycStatus'] as String?;
      if (!_kycFirstRun && status != _lastKycStatus) {
        if (status == 'APPROVED') {
          _notif.showNotification(
            channel: AppConstants.channelKycId,
            title: 'Account Approved! 🎉',
            body: 'Your KYC has been approved. You can now accept jobs.',
            route: '/caregiver-verification',
          );
        } else if (status == 'REJECTED') {
          _notif.showNotification(
            channel: AppConstants.channelKycId,
            title: 'Account Rejected ❌',
            body: 'Your KYC was rejected. Please check the app for details.',
            route: '/caregiver-verification',
          );
        }
      }
      _lastKycStatus = status;
      _kycFirstRun = false;
    });
    _subs.add(sub);
  }

  // ── Client: their own bookings (accepted / completed / rejected) ───────────
  void _listenClientBookings() {
    final sub = _db
        .collection(AppConstants.bookingsCollection)
        .where('clientId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (_myBookingsFirstRun) {
        _myBookingsFirstRun = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;
        final data = change.doc.data();
        if (data == null) continue;
        final b = Booking.fromMap(data, change.doc.id);
        if (b.status == BookingStatus.accepted && !b.isClientEnded) {
          _notif.showNotification(
            channel: AppConstants.channelJobId,
            title: 'Job Accepted! ✅',
            body: 'A caregiver has accepted your request.',
            route: '/bookings',
          );
        } else if (b.status == BookingStatus.completed) {
          _notif.showNotification(
            channel: AppConstants.channelJobId,
            title: 'Job Completed! 🎉',
            body: 'Your service has been completed successfully.',
            route: '/bookings',
          );
        } else if (b.status == BookingStatus.rejected ||
            b.status == BookingStatus.declined) {
          _notif.showNotification(
            channel: AppConstants.channelJobId,
            title: 'Job Rejected ❌',
            body: 'The caregiver has rejected your request.',
            route: '/bookings',
          );
        }
      }
    });
    _subs.add(sub);
  }

  // ── Caregiver/Nurse: own job completed -> payment received ─────────────────
  void _listenCaregiverBookings() {
    final sub = _db
        .collection(AppConstants.bookingsCollection)
        .where('caregiverId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      // Resolve stale bookings on every snapshot (incl. first) so overdue jobs
      // auto-complete and lapsed acceptances re-broadcast even after app restart.
      _resolveStale(snap.docs);
      if (_myBookingsFirstRun) {
        _myBookingsFirstRun = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;
        final data = change.doc.data();
        if (data == null) continue;
        final b = Booking.fromMap(data, change.doc.id);
        if (b.status == BookingStatus.completed) {
          _notif.showNotification(
            channel: AppConstants.channelJobId,
            title: 'Payment Received! 💰',
            body: 'The job has ended. Earnings have been added to your wallet.',
            route: '/wallet',
          );
        }
      }
    });
    _subs.add(sub);
  }

  // ── Caregiver/Nurse: new broadcasted/pending jobs ──────────────────────────
  void _listenNewJobs() {
    final sub = _db
        .collection(AppConstants.bookingsCollection)
        .where('status', whereIn: ['BROADCASTED', 'PENDING'])
        .snapshots()
        .listen((snap) {
      if (_newJobsFirstRun) {
        _newJobsFirstRun = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        final b = Booking.fromMap(data, change.doc.id);
        // Skip jobs this caregiver already rejected.
        if (b.rejectedBy.contains(uid)) continue;
        // Honour jobs restricted to specific caregivers.
        if (b.allowedCaregivers.isNotEmpty &&
            !b.allowedCaregivers.contains(uid)) {
          continue;
        }
        if (b.isEmergency) {
          _notif.showNotification(
            channel: AppConstants.channelSosId,
            title: '🚨 EMERGENCY Job!',
            body: 'An urgent emergency request is available. Please respond now.',
            route: '/job-feed',
          );
        } else {
          _notif.showNotification(
            channel: AppConstants.channelJobId,
            title: 'New Job Request! 🚨',
            body: 'A new service request is available. Please check the app.',
            route: '/job-feed',
          );
        }
      }
    });
    _subs.add(sub);
  }
}
