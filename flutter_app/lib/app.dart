import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/services/notification_service.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/providers/location_tracking_provider.dart';
import 'presentation/providers/notification_listener_provider.dart';

class CareApp extends ConsumerStatefulWidget {
  const CareApp({super.key});

  @override
  ConsumerState<CareApp> createState() => _CareAppState();
}

class _CareAppState extends ConsumerState<CareApp> {
  StreamSubscription<String>? _routeSub;

  @override
  void initState() {
    super.initState();
    // Notification tap (FCM / local) -> navigate to the relevant screen.
    _routeSub = NotificationService.routeStream.listen((route) {
      if (route.isEmpty) return;
      ref.read(appRouterProvider).go(route);
    });
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    // Keep the in-app notification listener alive for the whole session.
    ref.watch(globalNotificationListenerProvider);
    // Publish caregiver live location while a job is in progress (iOS/Android).
    ref.watch(locationTrackingProvider);
    return MaterialApp.router(
      title: 'Golden Hand Caregivers',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
    );
  }
}
