import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  factory NotificationService({FlutterLocalNotificationsPlugin? plugin}) =>
    plugin == null ? _instance : NotificationService._withPlugin(plugin);

  NotificationService._internal()
    : flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._withPlugin(FlutterLocalNotificationsPlugin? plugin)
    : flutterLocalNotificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'study_reminder_channel';
  static const String _channelName = 'Study Reminders';
  static const String _channelDescription = 'Reminders for study sessions and goals';

  /// Initialize the notification service
  Future<void> init() async {
    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Initialize notification plugin
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: false,
        requestBadgePermission: false,
        requestAlertPermission: false,
      );
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Create notification channel for Android 8.0+
      await _createNotificationChannel();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Create a notification channel for Android 8.0+
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Schedule a study reminder
  Future<void> scheduleStudyReminder(Reminder reminder) async {
    try {
      final id = reminder.id.hashCode;
      final time = reminder.timeOfDay;
      
      // Determine notification title based on reminder type
      String title;
      switch (reminder.type) {
        case ReminderType.lesson:
          title = 'Upcoming Lesson';
          break;
        case ReminderType.goal:
          title = 'Goal Reminder';
          break;
        case ReminderType.study:
        case ReminderType.custom:
          title = 'Time to Study!';
          break;
      }
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        reminder.message ?? 'Your scheduled study time is here!',
        _nextInstanceOfTime(time),
        _buildNotificationDetails(reminder),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode(reminder.toJson()),
      );
      
      debugPrint('Scheduled notification for ${time.hour}:${time.minute}');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      rethrow;
    }
  }

  /// Schedule a lesson reminder
  Future<void> scheduleLessonReminder({
    required Lesson lesson,
    required DateTime scheduledTime,
    String? customMessage,
  }) async {
    try {
      final id = '${lesson.id}_${scheduledTime.millisecondsSinceEpoch}'.hashCode;
      final message = customMessage ?? 'Time to study: ${lesson.title}';
      
      // Create the reminder
      final reminder = Reminder(
        id: id.toString(),
        userId: 'current_user', // This should be replaced with actual user ID
        title: 'Upcoming Lesson: ${lesson.title}',
        timeOfDay: TimeOfDay.fromDateTime(scheduledTime),
        message: message,
        type: ReminderType.lesson,
        frequency: ReminderFrequency.daily, // Using daily as a default since there's no 'once' frequency
        isActive: true,
        isRepeating: false,
      );
      
      // Schedule the notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        'Upcoming Lesson: ${lesson.title}',
        message,
        tz.TZDateTime.from(scheduledTime, tz.local),
        _buildNotificationDetails(reminder, sound: 'notification_sound'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({
          'type': 'lesson',
          'lessonId': lesson.id,
          'scheduledTime': scheduledTime.toIso8601String(),
        }),
      );
      
      debugPrint('Scheduled lesson reminder for ${scheduledTime.toIso8601String()}');
    } catch (e) {
      debugPrint('Error scheduling lesson reminder: $e');
      rethrow;
    }
  }

  /// Build notification details based on platform
  NotificationDetails _buildNotificationDetails(Reminder reminder, {String? sound}) {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''),
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: reminder.isRepeating,
    );

    final iOSDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.aiff',
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
  }

  /// Handle notification tap
  void _onNotificationResponse(NotificationResponse response) {
    try {
      if (response.payload != null) {
        final payload = jsonDecode(response.payload!);
        debugPrint('Notification tapped with payload: $payload');
        // Handle different notification types here
      }
    } catch (e) {
      debugPrint('Error handling notification response: $e');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Get the next instance of a specific time
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
