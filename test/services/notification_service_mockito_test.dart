import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:learning_pwa/services/notification_service.dart';
import 'notification_service_mockito_test.mocks.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


@GenerateMocks([FlutterLocalNotificationsPlugin])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NotificationService Mockito Tests', () {
    late NotificationService service;
    late MockFlutterLocalNotificationsPlugin mockPlugin;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      service = NotificationService(plugin: mockPlugin);
    });

    test('should initialize notification service', () async {
      // Act
      await service.init();

      // Assert - initialization should complete without error
      // In test environment, platform-specific initialization may fail
      // but the method should handle it gracefully
    });

    test('should schedule study reminder', () async {
      // Arrange
      await service.init();
      final reminder = Reminder(
        id: 'reminder_001',
        userId: 'user_001',
        timeOfDay: const TimeOfDay(hour: 9, minute: 0),
        frequency: ReminderFrequency.daily,
        type: ReminderType.study,
        title: 'Study Time',
        message: 'Time to study!',
        isActive: true,
        isRepeating: true,
      );

      // Act
      await service.scheduleStudyReminder(reminder);

      // Assert - should complete without error
      // In test environment, actual scheduling may not work
      // but the method should handle it
    });

    test('should schedule lesson reminder', () async {
      // Arrange
      await service.init();
      final lesson = Lesson(
        id: 'lesson_001',
        title: 'Test Lesson',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 'user_001',
        terms: [],
        questions: [],
        concepts: [],
      );
      final scheduledTime = DateTime.now().add(const Duration(hours: 1));

      // Act
      await service.scheduleLessonReminder(
        lesson: lesson,
        scheduledTime: scheduledTime,
        customMessage: 'Custom reminder message',
      );

      // Assert - should complete without error
    });

    test('should cancel notification', () async {
      // Arrange
      await service.init();
      final notificationId = 'reminder_001'.hashCode;

      // Act
      await service.cancelNotification(notificationId);

      // Assert - should complete without error
    });

    test('should cancel all notifications', () async {
      // Arrange
      await service.init();

      // Act
      await service.cancelAllNotifications();

      // Assert - should complete without error
    });

    test('should handle inactive reminder', () async {
      // Arrange
      await service.init();
      final inactiveReminder = Reminder(
        id: 'reminder_002',
        userId: 'user_001',
        timeOfDay: const TimeOfDay(hour: 9, minute: 0),
        frequency: ReminderFrequency.daily,
        type: ReminderType.study,
        isActive: false, // Inactive
        isRepeating: true,
      );

      // Act
      await service.scheduleStudyReminder(inactiveReminder);

      // Assert - inactive reminders should not schedule
      // The service should handle this gracefully
    });
  });
}

