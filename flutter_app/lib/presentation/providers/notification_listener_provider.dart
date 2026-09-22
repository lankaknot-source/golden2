import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/global_notification_listener.dart';
import 'auth_provider.dart';

/// Keeps the in-app notification listener (care2 MainActivity parity) running
/// for the duration of an authenticated session. Recreated on login, disposed
/// on logout. Watch this somewhere always-mounted (see CareApp) to keep it alive.
final globalNotificationListenerProvider = Provider<void>((ref) {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return;

  final listener = GlobalNotificationListener(
    uid: auth.user.uid,
    role: auth.user.role,
  )..start();

  ref.onDispose(listener.dispose);
});
