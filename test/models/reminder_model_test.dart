import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:learning_pwa/models/reminder.dart';

void main() {
  group('Reminder Model Tests', () {
    final testReminder = Reminder(
      id: 'reminder_001',
      userId: 'user_001',
      timeOfDay: const TimeOfDay(hour: 9, minute: 0),
      frequency: ReminderFrequency.daily,
      type: ReminderType.study,
      title: 'Study Time',
      message: 'Time to study!',
      isRepeating: true,
      isActive: true,
    );

    test('should create reminder with all fields', () {
      expect(testReminder.id, 'reminder_001');
      expect(testReminder.userId, 'user_001');
      expect(testReminder.timeOfDay.hour, 9);
      expect(testReminder.timeOfDay.minute, 0);
      expect(testReminder.frequency, ReminderFrequency.daily);
      expect(testReminder.type, ReminderType.study);
      expect(testReminder.isRepeating, true);
      expect(testReminder.isActive, true);
    });

    test('should serialize to JSON', () {
      final json = testReminder.toJson();
      
      expect(json['id'], 'reminder_001');
      expect(json['user_id'], 'user_001');
      expect(json['time_of_day'], '09:00');
      expect(json['frequency'], 'daily');
      expect(json['type'], 'study');
      expect(json['title'], 'Study Time');
      expect(json['message'], 'Time to study!');
      expect(json['is_repeating'], true);
      expect(json['is_active'], true);
    });

    test('should deserialize from JSON', () {
      final json = {
        'id': 'reminder_002',
        'user_id': 'user_002',
        'time_of_day': '14:30',
        'frequency': 'weekly',
        'type': 'lesson',
        'title': 'Lesson Reminder',
        'message': 'Study lesson now',
        'is_repeating': false,
        'is_active': true,
        'lesson_id': 'lesson_001',
      };
      
      final reminder = Reminder.fromJson(json);
      
      expect(reminder.id, 'reminder_002');
      expect(reminder.userId, 'user_002');
      expect(reminder.timeOfDay.hour, 14);
      expect(reminder.timeOfDay.minute, 30);
      expect(reminder.frequency, ReminderFrequency.weekly);
      expect(reminder.type, ReminderType.lesson);
      expect(reminder.lessonId, 'lesson_001');
    });

    test('should handle different reminder types', () {
      final studyReminder = Reminder(
        id: 'r1',
        userId: 'u1',
        timeOfDay: const TimeOfDay(hour: 10, minute: 0),
        type: ReminderType.study,
      );
      
      final lessonReminder = Reminder(
        id: 'r2',
        userId: 'u1',
        timeOfDay: const TimeOfDay(hour: 10, minute: 0),
        type: ReminderType.lesson,
        lessonId: 'lesson_001',
      );
      
      final goalReminder = Reminder(
        id: 'r3',
        userId: 'u1',
        timeOfDay: const TimeOfDay(hour: 10, minute: 0),
        type: ReminderType.goal,
      );
      
      expect(studyReminder.type, ReminderType.study);
      expect(lessonReminder.type, ReminderType.lesson);
      expect(goalReminder.type, ReminderType.goal);
    });

    test('should create copy with modified fields', () {
      final modified = testReminder.copyWith(
        title: 'Modified Title',
        isActive: false,
      );
      
      expect(modified.title, 'Modified Title');
      expect(modified.isActive, false);
      expect(modified.id, testReminder.id); // Unchanged
      expect(modified.timeOfDay, testReminder.timeOfDay); // Unchanged
    });

    test('should handle time formatting correctly', () {
      final reminder = Reminder(
        id: 'r1',
        userId: 'u1',
        timeOfDay: const TimeOfDay(hour: 5, minute: 5),
      );
      
      final json = reminder.toJson();
      expect(json['time_of_day'], '05:05');
    });
  });
}

