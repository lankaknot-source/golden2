import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/booking_repository.dart';
import '../../domain/models/booking_model.dart';
import 'auth_provider.dart';

final bookingRepositoryProvider =
    Provider<BookingRepository>((_) => BookingRepository());

final clientBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).streamClientBookings(user.uid);
});

final caregiverBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).streamCaregiverBookings(user.uid);
});

final availableJobsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).streamAvailableJobs(user.uid);
});

final caregiverActiveBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).streamCaregiverActiveBookings(user.uid);
});

final bookingDetailProvider =
    StreamProvider.family<Booking, String>((ref, bookingId) {
  return ref.watch(bookingRepositoryProvider).streamBooking(bookingId);
});

class BookingNotifier extends StateNotifier<AsyncValue<void>> {
  final BookingRepository _repo;
  BookingNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<String?> createBooking(Booking booking) async {
    state = const AsyncValue.loading();
    try {
      final id = await _repo.addBooking(booking);
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateStatus(String id, BookingStatus status) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateBookingStatus(id, status);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptJob(
      String bookingId, String caregiverId, double hourlyRate) async {
    state = const AsyncValue.loading();
    try {
      await _repo.acceptJob(bookingId, caregiverId, hourlyRate);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> confirmPreJobAttendance(
      String bookingId, String caregiverId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.confirmPreJobAttendance(bookingId, caregiverId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectJob(
      String bookingId, String caregiverId, bool isBroadcasted) async {
    state = const AsyncValue.loading();
    try {
      await _repo.rejectJob(bookingId, caregiverId, isBroadcasted);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> generateStartCode(String bookingId) async {
    try {
      return await _repo.generateStartCode(bookingId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> verifyAndStartJob(String bookingId, String code) async {
    state = const AsyncValue.loading();
    try {
      final ok = await _repo.verifyAndStartJob(bookingId, code);
      state = const AsyncValue.data(null);
      return ok;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> addTaskProof(String bookingId, TaskProofEntry proof) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addTaskProof(bookingId, proof);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> approveTask(String bookingId, String taskName) async {
    try {
      await _repo.approveTask(bookingId, taskName);
    } catch (_) {}
  }

  Future<void> clientEndJob(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.clientEndJob(bookingId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> caregiverAcceptEnd(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.caregiverAcceptEnd(bookingId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submitRating({
    required String bookingId,
    required String caregiverId,
    required String clientId,
    required double rating,
    required String comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.submitRating(
        bookingId: bookingId,
        caregiverId: caregiverId,
        clientId: clientId,
        rating: rating,
        comment: comment,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final bookingNotifierProvider =
    StateNotifierProvider<BookingNotifier, AsyncValue<void>>(
  (ref) => BookingNotifier(ref.watch(bookingRepositoryProvider)),
);
