import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

Future<void>? _initialization;

/// Initializes Firebase once without making the first Flutter frame wait on a
/// native plugin call. This is especially important on iOS where a stalled
/// Firebase configuration call otherwise leaves the launch screen black.
Future<void> ensureFirebaseInitialized() {
  return _initialization ??= _initialize();
}

Future<void> _initialize() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
