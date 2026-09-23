import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase_bootstrap.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase-backed Riverpod providers are created while the first widget
  // tree is built. Initialize Firebase before that tree exists; otherwise
  // iOS can render a blank/white screen with "No Firebase App [DEFAULT]".
  try {
    await ensureFirebaseInitialized().timeout(const Duration(seconds: 8));
  } catch (e, stackTrace) {
    debugPrint('Firebase startup error: $e\n$stackTrace');
  }

  runApp(const ProviderScope(child: CareApp()));

  // Do not block the first Flutter frame on iOS notification permission or
  // FCM setup. Those native calls can wait for user interaction and otherwise
  // leave the launch screen black before the Flutter UI is mounted.
  unawaited(_initializeServices());
}

Future<void> _initializeServices() async {
  try {
    await ensureFirebaseInitialized();
    await NotificationService().initialize();
  } catch (e, stackTrace) {
    debugPrint('Notification init error: $e\n$stackTrace');
  }
}
