import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_hand_care/domain/models/booking_model.dart';
import 'package:golden_hand_care/presentation/providers/auth_provider.dart';
import 'package:golden_hand_care/presentation/providers/booking_provider.dart';
import 'package:golden_hand_care/presentation/screens/map/active_tracking_screen.dart';

Booking booking(String id, BookingStatus status) => Booking(
  id: id,
  clientId: 'client',
  elderId: 'elder',
  address: id,
  locationLat: 6.9,
  locationLng: 79.8,
  requestedTime: 1,
  status: status,
);

void main() {
  testWidgets(
    'empty bookings show guidance without requesting a fake booking',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            clientBookingsProvider.overrideWith((ref) => Stream.value([])),
            bookingDetailProvider.overrideWith(
              (ref, id) => throw StateError('Unexpected detail request: $id'),
            ),
          ],
          child: const MaterialApp(home: ActiveTrackingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No active care sessions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only trackable sessions appear and selection uses actual ID', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/map/active',
      routes: [
        GoRoute(
          path: '/map/active',
          builder: (_, _) => const ActiveTrackingScreen(),
        ),
        GoRoute(
          path: '/map/:id',
          builder:
              (_, state) => Scaffold(
                body: Text('Selected ${state.pathParameters['id']}'),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          clientBookingsProvider.overrideWith(
            (ref) => Stream.value([
              booking('finished', BookingStatus.completed),
              booking('pending', BookingStatus.pending),
              booking('real-booking', BookingStatus.inProgress),
            ]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('finished'), findsNothing);
    expect(find.text('pending'), findsNothing);
    await tester.tap(find.text('real-booking'));
    await tester.pumpAndSettle();
    expect(find.text('Selected real-booking'), findsOneWidget);
  });

  testWidgets('failed booking load can be retried', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          clientBookingsProvider.overrideWith((ref) {
            attempts++;
            return attempts == 1
                ? Stream.error(StateError('offline'))
                : Stream.value([]);
          }),
        ],
        child: const MaterialApp(home: ActiveTrackingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.textContaining('No active care sessions'), findsOneWidget);
  });
}
