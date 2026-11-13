import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _workoutId = 0;
  static const int _restProgressId = 1;
  static const int _restFinishedId = 2;

  Future<void>? _initFuture;

  /// Safe to call many times; initialisation only happens once.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      );

      await _notifications.initialize(const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ));

      // Android 13+ requires a runtime permission for notifications.
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<void> showRestTimerNotification(
      int secondsRemaining, int totalSeconds) async {
    await init();
    final minutes = secondsRemaining ~/ 60;
    final seconds = secondsRemaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final androidDetails = AndroidNotificationDetails(
      'rest_timer_channel',
      'Rest Timer',
      channelDescription: 'Shows rest timer progress',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: false,
      autoCancel: true,
      onlyAlertOnce: true,
      showWhen: true,
      when: DateTime.now()
          .add(Duration(seconds: secondsRemaining))
          .millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      timeoutAfter: secondsRemaining * 1000,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    try {
      await _notifications.show(
        _restProgressId,
        'Resting',
        'Next set in $timeStr',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('Rest notification failed: $e');
    }
  }

  /// Schedules the "rest finished" alert for [end]. Using a scheduled
  /// notification means the alert still fires when the OS has suspended the
  /// app (Dart timers do not run in that case).
  Future<void> scheduleRestFinished(DateTime end) async {
    await init();
    await cancelScheduledRestFinished();
    if (!end.isAfter(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'rest_finished_channel',
      'Rest Finished',
      channelDescription: 'Alerts when rest timer finishes',
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    try {
      await _notifications.zonedSchedule(
        _restFinishedId,
        'Rest finished',
        'Time for your next set.',
        tz.TZDateTime.from(end, tz.UTC),
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Scheduling rest notification failed: $e');
    }
  }

  Future<void> cancelScheduledRestFinished() async {
    try {
      await _notifications.cancel(_restFinishedId);
    } catch (_) {}
  }

  Future<void> cancelRestTimerNotification() async {
    try {
      await _notifications.cancel(_restProgressId);
    } catch (_) {}
  }

  Future<void> showWorkoutNotification(
      String elapsedTime, int exerciseCount) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'workout_channel',
      'Active Workout',
      channelDescription: 'Shows active workout timer',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    try {
      await _notifications.show(
        _workoutId,
        'Workout in progress',
        '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'} • $elapsedTime',
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('Workout notification failed: $e');
    }
  }

  Future<void> cancelWorkoutNotification() async {
    try {
      await _notifications.cancel(_workoutId);
    } catch (_) {}
  }
}
