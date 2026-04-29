import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  Future<void> showRestTimerNotification(
      int secondsRemaining, int totalSeconds) async {
    final minutes = secondsRemaining ~/ 60;
    final seconds = secondsRemaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Calculate progress for progress bar
    final progress = totalSeconds > 0
        ? (secondsRemaining / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    final androidDetails = AndroidNotificationDetails(
      'rest_timer_channel',
      'Rest Timer',
      channelDescription: 'Shows rest timer progress',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      showProgress: true,
      maxProgress: totalSeconds,
      progress: secondsRemaining,
      // This makes it show as a heads-up notification
      usesChronometer: true,
      chronometerCountDown: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'Rest Timer',
      'Time remaining: $timeStr',
      details,
    );
  }

  Future<void> cancelRestTimerNotification() async {
    await _notifications.cancel(1);
  }

  Future<void> showWorkoutNotification(
      String elapsedTime, int exerciseCount) async {
    final androidDetails = AndroidNotificationDetails(
      'workout_channel',
      'Active Workout',
      channelDescription: 'Shows active workout timer',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      usesChronometer: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Workout in Progress',
      '$exerciseCount exercises • $elapsedTime',
      details,
    );
  }

  Future<void> cancelWorkoutNotification() async {
    await _notifications.cancel(0);
  }
}
