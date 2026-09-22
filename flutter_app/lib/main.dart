import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const ProviderScope(child: CareApp()));

  // Do not block the first Flutter frame on iOS notification permission or
  // FCM setup. Those native calls can wait for user interaction and otherwise
  // leave the launch screen black before the Flutter UI is mounted.
  unawaited(_initializeNotifications());
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService().initialize();
  } catch (e, stackTrace) {
    debugPrint('Notification init error: $e\n$stackTrace');
  }
}
