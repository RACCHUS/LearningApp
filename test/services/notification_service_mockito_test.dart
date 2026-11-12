// NotificationService against a mocked FlutterLocalNotificationsPlugin
// (plan PR-4a). The previous version had no assertions at all and left
// `initialize` unstubbed, so init() always took its error path.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/services/notification_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service_mockito_test.mocks.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterLocalNotificationsPlugin plugin;
  late NotificationService service;

  Reminder reminder({
    String id = 'reminder_001',
    ReminderType type = ReminderType.study,
    String? message = 'Time to study!',
    bool isActive = true,
  }) =>
      Reminder(
        id: id,
        userId: 'user_001',
        timeOfDay: const TimeOfDay(hour: 9, minute: 0),
        frequency: ReminderFrequency.daily,
        type: type,
        title: 'Study Time',
        message: message,
        isActive: isActive,
        isRepeating: true,
      );

  /// Captures the single zonedSchedule call: [id, title, body, date, payload, match].
  List<dynamic> capturedSchedule() => verify(plugin.zonedSchedule(
        captureAny,
        captureAny,
        captureAny,
        captureAny,
        any,
        uiLocalNotificationDateInterpretation: anyNamed('uiLocalNotificationDateInterpretation'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: captureAnyNamed('payload'),
        matchDateTimeComponents: captureAnyNamed('matchDateTimeComponents'),
      )).captured;

  setUp(() async {
    plugin = MockFlutterLocalNotificationsPlugin();
    when(plugin.initialize(any, onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse')))
        .thenAnswer((_) async => true);
    // Non-Android platform: no Android-specific implementation to create a channel on.
    when(plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()).thenReturn(null);
    service = NotificationService(plugin: plugin);
    await service.init();
  });

  test('init initializes the plugin once', () {
    verify(plugin.initialize(any, onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse')))
        .called(1);
  });

  test('init swallows a plugin initialization failure', () async {
    final failing = MockFlutterLocalNotificationsPlugin();
    when(failing.initialize(any, onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse')))
        .thenThrow(StateError('no notification permission'));
    await expectLater(NotificationService(plugin: failing).init(), completes);
  });

  test('study reminder schedules a daily notification at the reminder time', () async {
    await service.scheduleStudyReminder(reminder());

    final c = capturedSchedule();
    expect(c[0], 'reminder_001'.hashCode);
    expect(c[1], 'Time to Study!');
    expect(c[2], 'Time to study!');
    final date = c[3] as tz.TZDateTime;
    expect((date.hour, date.minute), (9, 0));
    final now = tz.TZDateTime.now(tz.local);
    expect(date.isAfter(now), isTrue, reason: 'past times roll to the next day');
    expect(date.difference(now), lessThanOrEqualTo(const Duration(days: 1)));
    expect((jsonDecode(c[4] as String) as Map)['id'], 'reminder_001');
    expect(c[5], DateTimeComponents.time);
  });

  test('study reminder uses a default body when the reminder has no message', () async {
    await service.scheduleStudyReminder(reminder(message: null));
    expect(capturedSchedule()[2], 'Your scheduled study time is here!');
  });

  for (final (type, title) in [
    (ReminderType.lesson, 'Upcoming Lesson'),
    (ReminderType.goal, 'Goal Reminder'),
    (ReminderType.custom, 'Time to Study!'),
  ]) {
    test('${type.name} reminder title is "$title"', () async {
      await service.scheduleStudyReminder(reminder(type: type));
      expect(capturedSchedule()[1], title);
    });
  }

  test('scheduling does not filter inactive reminders; callers must (ReminderProvider does)', () async {
    await service.scheduleStudyReminder(reminder(isActive: false));
    expect(capturedSchedule()[0], 'reminder_001'.hashCode);
  });

  test('a scheduling failure is rethrown to the caller', () async {
    when(plugin.zonedSchedule(any, any, any, any, any,
            uiLocalNotificationDateInterpretation: anyNamed('uiLocalNotificationDateInterpretation'),
            androidScheduleMode: anyNamed('androidScheduleMode'),
            payload: anyNamed('payload'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents')))
        .thenThrow(StateError('exact alarms not permitted'));
    await expectLater(service.scheduleStudyReminder(reminder()), throwsStateError);
  });

  test('lesson reminder schedules a one-off notification with lesson payload', () async {
    final lesson = Lesson(
      id: 'lesson_001',
      title: 'Test Lesson',
      tags: const [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      userId: 'user_001',
      terms: const [],
      questions: const [],
      concepts: const [],
    );
    final at = DateTime.now().add(const Duration(hours: 1));

    await service.scheduleLessonReminder(lesson: lesson, scheduledTime: at, customMessage: 'Custom reminder message');

    final c = capturedSchedule();
    expect(c[0], 'lesson_001_${at.millisecondsSinceEpoch}'.hashCode);
    expect(c[1], 'Upcoming Lesson: Test Lesson');
    expect(c[2], 'Custom reminder message');
    expect((c[3] as tz.TZDateTime).millisecondsSinceEpoch, at.millisecondsSinceEpoch);
    expect(jsonDecode(c[4] as String), {
      'type': 'lesson',
      'lessonId': 'lesson_001',
      'scheduledTime': at.toIso8601String(),
    });
    expect(c[5], isNull, reason: 'lesson reminders do not repeat');
  });

  test('cancel and cancelAll reach the plugin', () async {
    await service.cancelNotification(42);
    await service.cancelAllNotifications();
    verify(plugin.cancel(42)).called(1);
    verify(plugin.cancelAll()).called(1);
  });
}
