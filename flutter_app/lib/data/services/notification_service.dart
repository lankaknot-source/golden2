import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  // Firebase is already initialized by platform — nothing extra needed here
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Route navigation stream — listeners in app handle routing on notification tap
  static final _routeController = StreamController<String>.broadcast();
  static Stream<String> get routeStream => _routeController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();
    await _initLocalNotifications();
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS)) {
      await _initFcm();
    }
    _initialized = true;
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Emits a fresh FCM token whenever it is rotated (mirrors Android onNewToken).
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _routeController.add(response.payload!);
        }
      },
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final ch in _channels) {
        await androidPlugin?.createNotificationChannel(ch);
      }
    }
  }

  static const _channels = [
    AndroidNotificationChannel(
      'medicine_reminders',
      'Medicine Reminders',
      importance: Importance.max,
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      'job_alerts',
      'Job Alerts',
      importance: Importance.max,
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      'sos_alerts',
      'SOS Alerts',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'kyc_status',
      'KYC Status Updates',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'geofence_alerts',
      'Geofence Alerts',
      importance: Importance.high,
      enableVibration: true,
    ),
  ];

  Future<void> _initFcm() async {
    FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Foreground messages → local notification
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background tap → navigate
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final route = _routeFromData(msg.data);
      if (route != null) _routeController.add(route);
    });

    // Terminated app tap → navigate after delay
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final route = _routeFromData(initial.data);
      if (route != null) {
        Future.delayed(const Duration(milliseconds: 1200), () => _routeController.add(route));
      }
    }
  }

  String? _routeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;
    return switch (type) {
      'booking' => '/bookings',
      'job' => '/job-feed',
      'kyc' => '/caregiver-verification',
      'chat' when id != null => '/chat/$id',
      'map' when id != null => '/map/$id',
      'sos' => '/home',
      _ => null,
    };
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final channel = message.data['channel'] as String? ?? 'job_alerts';
    final route = _routeFromData(message.data);

    await _local.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          _channelName(channel),
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  String _channelName(String id) => switch (id) {
        'medicine_reminders' => 'Medicine Reminders',
        'job_alerts' => 'Job Alerts',
        'sos_alerts' => 'SOS Alerts',
        'kyc_status' => 'KYC Status Updates',
        'geofence_alerts' => 'Geofence Alerts',
        _ => 'Notifications',
      };

  Future<void> showGeofenceAlert(String message) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Caregiver Nearby',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'geofence_alerts',
          'Geofence Alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  /// Generic local notification used by the in-app Firestore listener
  /// (mirrors care2 MainActivity.sendNotification). [route] is delivered as the
  /// payload so tapping navigates to the right screen.
  Future<void> showNotification({
    required String channel,
    required String title,
    required String body,
    String? route,
  }) async {
    if (kIsWeb) return;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          _channelName(channel),
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) return;
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    await _local.zonedSchedule(
      id,
      'Medicine Reminder',
      'Time to take $medicineName — $dosage',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedules a daily-repeating local notification for one medicine at
  /// [hour]:[minute] in the device's local time. Mirrors care2's
  /// MedicineReminderWorker, but uses the OS scheduler so it fires on iOS +
  /// Android even when the app is closed. Re-using the same [id] overwrites it.
  Future<void> scheduleDailyMedicine({
    required int id,
    required String medicineName,
    required String elderName,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    final now = tz.TZDateTime.now(tz.local);
    var first =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    await _local.zonedSchedule(
      id,
      'Medicine Time! ⏰',
      elderName.isEmpty
          ? 'Time to give $medicineName'
          : 'Time to give $medicineName to $elderName',
      first,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedules "day before" + "morning of" reminders for an accepted job
  /// (mirrors care2 JobFeedViewModel.scheduleJobReminders). On-device, no server.
  Future<void> scheduleJobReminders({
    required String bookingId,
    required int scheduledTimeMs,
  }) async {
    if (kIsWeb || scheduledTimeMs <= 0) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final base = _stableId(bookingId);

    final oneDayBeforeMs =
        scheduledTimeMs - const Duration(days: 1).inMilliseconds;
    if (oneDayBeforeMs > nowMs) {
      await _scheduleOneShot(
        id: (base ^ 0x1111) & 0x7fffffff,
        whenMs: oneDayBeforeMs,
        title: 'Upcoming Job Reminder ⏰',
        body: 'You have a job scheduled for tomorrow. Be prepared.',
        route: '/bookings',
      );
    }

    final sched = DateTime.fromMillisecondsSinceEpoch(scheduledTimeMs);
    final morningMs =
        DateTime(sched.year, sched.month, sched.day, 6).millisecondsSinceEpoch;
    if (morningMs > nowMs && morningMs < scheduledTimeMs) {
      await _scheduleOneShot(
        id: (base ^ 0x2222) & 0x7fffffff,
        whenMs: morningMs,
        title: 'Today is your Job! 📅',
        body: "You have a job starting today. Don't be late!",
        route: '/bookings',
      );
    }
  }

  int _stableId(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  Future<void> _scheduleOneShot({
    required int id,
    required int whenMs,
    required String title,
    required String body,
    String? route,
  }) async {
    final when = tz.TZDateTime.from(
      DateTime.fromMillisecondsSinceEpoch(whenMs),
      tz.local,
    );
    await _local.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'job_alerts',
          _channelName('job_alerts'),
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: route,
    );
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC if the platform timezone cannot be resolved.
    }
  }

  Future<void> cancelReminder(int id) => _local.cancel(id);
  Future<void> cancelAllReminders() => _local.cancelAll();
}
