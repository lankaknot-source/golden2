import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/booking_model.dart';

class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.bookingsCollection);

  Future<String> addBooking(Booking booking) async {
    final ref = await _col.add(booking.toMap());
    return ref.id;
  }

  Future<Booking?> getBooking(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Booking.fromMap(doc.data()!, doc.id);
  }

  Stream<Booking> streamBooking(String id) {
    return _col.doc(id).snapshots().map((doc) => Booking.fromMap(doc.data()!, doc.id));
  }

  Stream<List<Booking>> streamClientBookings(String clientId) {
    return _col
        .where('clientId', isEqualTo: clientId)
        .orderBy('requestedTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Booking.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<Booking>> streamCaregiverBookings(String caregiverId) {
    return _col
        .snapshots()
        .map((s) => s.docs
            .map((d) => Booking.fromMap(d.data(), d.id))
            .where((b) => b.caregiverId == caregiverId ||
                b.appliedCaregivers.contains(caregiverId) ||
                b.jobAcceptances.any((a) => a.caregiverId == caregiverId))
            .toList()
          ..sort((a, b) => b.requestedTime.compareTo(a.requestedTime)));
  }

  // Job feed: BROADCASTED + PENDING jobs for caregiver to browse
  Stream<List<Booking>> streamAvailableJobs(String caregiverId) {
    return _col
        .where('status', whereIn: ['PENDING', 'BROADCASTED'])
        .orderBy('isEmergency', descending: true)
        .orderBy('requestedTime', descending: true)
        .snapshots()
        .map((s) {
          return s.docs
              .map((d) => Booking.fromMap(d.data(), d.id))
              .where((b) {
                if (b.rejectedBy.contains(caregiverId)) return false;
                if (b.isSubscriptionBooking &&
                    b.allowedCaregivers.isNotEmpty &&
                    !b.allowedCaregivers.contains(caregiverId)) {
                  return false;
                }
                return true;
              })
              .toList();
        });
  }

  // Active/accepted bookings for caregiver
  Stream<List<Booking>> streamCaregiverActiveBookings(String caregiverId) {
    return _col
        .where('caregiverId', isEqualTo: caregiverId)
        .where('status', whereIn: ['ACCEPTED', 'IN_PROGRESS'])
        .snapshots()
        .map((s) => s.docs.map((d) => Booking.fromMap(d.data(), d.id)).toList());
  }

  Future<void> updateBooking(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> updateBookingStatus(String id, BookingStatus status) =>
      _col.doc(id).update({'status': status.firestoreValue});

  // Caregiver accepts a broadcasted job
  Future<void> acceptJob(String bookingId, String caregiverId, double hourlyRate) async {
    final current = await _col.doc(bookingId).get();
    if ((current.data()?['status'] as String?) == 'BROADCASTED') {
      await acceptBroadcastJob(bookingId, caregiverId, hourlyRate);
      return;
    }
    final code = _generateCode();
    await _col.doc(bookingId).update({
      'caregiverId': caregiverId,
      'status': 'ACCEPTED',
      'startCode': code,
      'hourlyRate': hourlyRate,
      'acceptedAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Set caregiver as busy
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(caregiverId)
        .update({'isBusy': true});
  }

  /// Atomically joins the Android/iOS broadcast queue (maximum four
  /// caregivers). The first caregiver is marked primary; the matching
  /// confirmation workers on the backend can later promote a backup.
  Future<void> acceptBroadcastJob(
    String bookingId,
    String caregiverId,
    double hourlyRate,
  ) async {
    final bookingRef = _col.doc(bookingId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(bookingRef);
      if (!snap.exists) throw StateError('Booking no longer exists');
      final data = snap.data()!;
      final status = data['status'] as String? ?? 'PENDING';
      if (status != 'PENDING' && status != 'BROADCASTED') {
        throw StateError('This job is no longer available');
      }
      final existing = (data['jobAcceptances'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (existing.any((e) => e['caregiverId'] == caregiverId)) {
        throw StateError('You have already accepted this job');
      }
      if (existing.length >= 4) throw StateError('All caregiver slots are full');

      final now = DateTime.now().millisecondsSinceEpoch;
      final acceptance = {
        'caregiverId': caregiverId,
        'acceptedAt': now,
        'acceptanceOrder': existing.length,
        'isPrimary': existing.isEmpty,
        'confirmationStatus': 'PENDING',
      };
      final updated = [...existing, acceptance];
      tx.update(bookingRef, {
        'jobAcceptances': updated,
        'appliedCaregivers': FieldValue.arrayUnion([caregiverId]),
        'hourlyRate': hourlyRate,
        'status': updated.length >= 4 ? 'BROADCAST_ACCEPTED' : 'BROADCASTED',
      });
    });
    await _firestore.collection(AppConstants.usersCollection).doc(caregiverId).update({
      'isBusy': true,
    });
  }

  /// Records the primary caregiver's attendance confirmation. The backend
  /// confirmation worker resolves the booking and generates the start code.
  Future<void> confirmPreJobAttendance(String bookingId, String caregiverId) async {
    final bookingRef = _col.doc(bookingId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(bookingRef);
      if (!snap.exists) throw StateError('Booking no longer exists');
      final entries = (snap.data()?['jobAcceptances'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final index = entries.indexWhere((e) => e['caregiverId'] == caregiverId);
      if (index < 0) throw StateError('You are not assigned to this job');
      entries[index]['confirmationStatus'] = 'CONFIRMED';
      tx.update(bookingRef, {'jobAcceptances': entries});
    });
  }

  // Caregiver rejects a PENDING (direct) job
  Future<void> rejectJob(String bookingId, String caregiverId, bool isBroadcasted) async {
    if (isBroadcasted) {
      await _col.doc(bookingId).update({
        'rejectedBy': FieldValue.arrayUnion([caregiverId]),
      });
    } else {
      await _col.doc(bookingId).update({'status': 'REJECTED'});
    }
  }

  Future<String> generateStartCode(String bookingId) async {
    final code = _generateCode();
    await _col.doc(bookingId).update({'startCode': code});
    return code;
  }

  // care2 format: [A-Z][0-9]{4}
  String _generateCode() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rng = Random();
    final letter = letters[rng.nextInt(letters.length)];
    final digits = (1000 + rng.nextInt(9000)).toString();
    return '$letter$digits';
  }

  Future<bool> verifyAndStartJob(String bookingId, String enteredCode) async {
    final doc = await _col.doc(bookingId).get();
    final stored = doc.data()?['startCode'] as String?;
    if (stored == null || stored != enteredCode) return false;
    await _col.doc(bookingId).update({
      'status': 'IN_PROGRESS',
      'startTime': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }

  Future<void> addTaskProof(String bookingId, TaskProofEntry proof) =>
      _col.doc(bookingId).update({
        'taskProofs': FieldValue.arrayUnion([proof.toMap()]),
        'completedTasks': FieldValue.arrayUnion([proof.taskName]),
      });

  Future<void> approveTask(String bookingId, String taskName) =>
      _col.doc(bookingId).update({
        'clientApprovedTasks': FieldValue.arrayUnion([taskName]),
      });

  Future<void> clientEndJob(String bookingId) =>
      _col.doc(bookingId).update({'isClientEnded': true});

  Future<void> caregiverAcceptEnd(String bookingId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final doc = await _col.doc(bookingId).get();
    final data = doc.data()!;
    final startMs = (data['startTime'] as num?)?.toInt() ?? now;
    final hourlyRate = (data['hourlyRate'] as num?)?.toDouble() ?? 0.0;
    final hours = (now - startMs) / (1000 * 60 * 60);

    // Read commission from settings/general
    double commission = AppConstants.defaultCommissionRate;
    try {
      final settings = await _firestore
          .collection(AppConstants.settingsCollection)
          .doc('general')
          .get();
      if (settings.exists) {
        commission = (settings.data()?['commissionRate'] as num?)?.toDouble() ??
            AppConstants.defaultCommissionRate;
      }
    } catch (_) {}

    final totalAmount = hours * hourlyRate;
    final netEarning = totalAmount * (1 - commission / 100);

    final caregiverId = data['caregiverId'] as String?;

    final batch = _firestore.batch();
    batch.update(_col.doc(bookingId), {
      'isCaregiverAcceptedEnd': true,
      'status': 'COMPLETED',
      'endTime': now,
      'totalAmount': totalAmount,
      'isPaid': true,
    });

    if (caregiverId != null) {
      final cgRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(caregiverId);
      batch.update(cgRef, {
        'walletBalance': FieldValue.increment(netEarning),
        'isBusy': false,
      });

      final txRef = _firestore
          .collection(AppConstants.transactionsCollection)
          .doc();
      batch.set(txRef, {
        'userId': caregiverId,
        'type': 'CREDIT',
        'amount': netEarning,
        'description': 'Job payment received',
        'timestamp': now,
        'receiptImageUrl': null,
      });
    }

    await batch.commit();
  }

  // ── Client-side lazy resolution (free-plan replacement for care2 workers) ────

  /// Auto-completes an overdue IN_PROGRESS booking (mirrors care2 AutoEndJobWorker)
  /// using the same payment logic as [caregiverAcceptEnd]. Idempotent via a status
  /// guard inside the transaction, so it can run repeatedly / on multiple devices
  /// without double-paying. Intended to run on the CAREGIVER's device (the wallet
  /// write is to the caregiver's own user doc).
  Future<void> autoCompleteOverdue(String bookingId) async {
    // Read commission outside the transaction.
    double commission = AppConstants.defaultCommissionRate;
    try {
      final settings = await _firestore
          .collection(AppConstants.settingsCollection)
          .doc('general')
          .get();
      if (settings.exists) {
        commission = (settings.data()?['commissionRate'] as num?)?.toDouble() ??
            AppConstants.defaultCommissionRate;
      }
    } catch (_) {}

    final bookingRef = _col.doc(bookingId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(bookingRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      if ((data['status'] as String?) != 'IN_PROGRESS') return; // already resolved
      final now = DateTime.now().millisecondsSinceEpoch;
      final startMs = (data['startTime'] as num?)?.toInt() ?? now;
      final hourlyRate = (data['hourlyRate'] as num?)?.toDouble() ?? 0.0;
      final hours = ((now - startMs) / (1000 * 60 * 60)).clamp(0.0, 24.0);
      final totalAmount = hours * hourlyRate;
      final netEarning = totalAmount * (1 - commission / 100);
      final caregiverId = data['caregiverId'] as String?;

      tx.update(bookingRef, {
        'status': 'COMPLETED',
        'endTime': now,
        'totalAmount': totalAmount,
        'isPaid': true,
        'isClientEnded': true,
        'isCaregiverAcceptedEnd': true,
      });

      if (caregiverId != null && caregiverId.isNotEmpty) {
        final cgRef =
            _firestore.collection(AppConstants.usersCollection).doc(caregiverId);
        tx.update(cgRef, {
          'walletBalance': FieldValue.increment(netEarning),
          'isBusy': false,
        });
        final txRef =
            _firestore.collection(AppConstants.transactionsCollection).doc();
        tx.set(txRef, {
          'userId': caregiverId,
          'type': 'CREDIT',
          'amount': netEarning,
          'description': 'Job payment (auto-completed)',
          'timestamp': now,
          'receiptImageUrl': null,
        });
      }
    });
  }

  /// Resets an ACCEPTED booking whose caregiver did not start within
  /// [AppConstants.acceptanceTimeoutMs] back to BROADCASTED so other caregivers
  /// can pick it up (mirrors care2 BroadcastConfirmTimeoutWorker, simplified to
  /// the Flutter booking model). Guarded + idempotent. Intended to run on the
  /// CAREGIVER's device (resets their own assignment + isBusy flag).
  Future<void> expireAcceptance(String bookingId) async {
    final bookingRef = _col.doc(bookingId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(bookingRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      if ((data['status'] as String?) != 'ACCEPTED') return;
      final acceptedAt = (data['acceptedAt'] as num?)?.toInt();
      if (acceptedAt == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - acceptedAt <= AppConstants.acceptanceTimeoutMs) return;
      final caregiverId = data['caregiverId'] as String?;

      tx.update(bookingRef, {
        'status': 'BROADCASTED',
        'caregiverId': null,
        'startCode': '',
        'acceptedAt': null,
        if (caregiverId != null && caregiverId.isNotEmpty)
          'rejectedBy': FieldValue.arrayUnion([caregiverId]),
      });

      if (caregiverId != null && caregiverId.isNotEmpty) {
        final cgRef =
            _firestore.collection(AppConstants.usersCollection).doc(caregiverId);
        tx.update(cgRef, {'isBusy': false});
      }
    });
  }

  Future<void> submitRating({
    required String bookingId,
    required String caregiverId,
    required String clientId,
    required double rating,
    required String comment,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _firestore.batch();

    batch.update(_col.doc(bookingId), {'isRated': true});

    final reviewRef =
        _firestore.collection(AppConstants.reviewsCollection).doc();
    batch.set(reviewRef, {
      'bookingId': bookingId,
      'caregiverId': caregiverId,
      'clientId': clientId,
      'rating': rating,
      'comment': comment,
      'timestamp': now,
    });

    await batch.commit();

    // Update caregiver rating average in a transaction
    await _firestore.runTransaction((tx) async {
      final cgRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(caregiverId);
      final cgDoc = await tx.get(cgRef);
      final data = cgDoc.data()!;
      final oldRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final oldCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
      final newCount = oldCount + 1;
      final newRating = ((oldRating * oldCount) + rating) / newCount;
      tx.update(cgRef, {'rating': newRating, 'reviewCount': newCount});
    });
  }
}
