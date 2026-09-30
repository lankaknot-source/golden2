import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

/// The home shortcut selects a real booking instead of reading bookings/active.
class ActiveTrackingScreen extends ConsumerWidget {
  const ActiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregiver =
        ref.watch(currentUserProvider)?.isCaregiverOrNurse ?? false;
    final provider =
        caregiver ? caregiverBookingsProvider : clientBookingsProvider;
    final bookings = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load your bookings. Please try again.'),
                  TextButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        data: (items) {
          final active =
              items
                  .where(
                    (b) =>
                        b.status == BookingStatus.inProgress ||
                        b.status == BookingStatus.accepted,
                  )
                  .toList()
                ..sort(
                  (a, b) => (b.status == BookingStatus.inProgress ? 1 : 0)
                      .compareTo(a.status == BookingStatus.inProgress ? 1 : 0),
                );
          if (active.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No active care sessions yet.\nLive tracking will be available when a caregiver is assigned.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: active.length,
            itemBuilder: (context, index) {
              final booking = active[index];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  booking.address.isEmpty ? 'Care session' : booking.address,
                ),
                subtitle: Text(
                  booking.status == BookingStatus.inProgress
                      ? 'Session in progress'
                      : 'Waiting for session to start',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/map/${booking.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
