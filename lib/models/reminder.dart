import 'package:flutter/material.dart';

enum ReminderFrequency { daily, weekly, monthly }
enum ReminderType { study, lesson, goal, custom }

class Reminder {
  final String id;
  final String userId;
  final TimeOfDay timeOfDay;
  final ReminderFrequency frequency;
  final ReminderType type;
  final String? lessonId;
  final String? title;
  final String? message;
  final bool isRepeating;
  final bool isActive;
  final DateTime? lastTriggered;
  final DateTime? nextTrigger;
  final Map<String, dynamic>? metadata;

  const Reminder({
    required this.id,
    required this.userId,
    required this.timeOfDay,
    this.frequency = ReminderFrequency.daily,
    this.type = ReminderType.study,
    this.lessonId,
    this.title,
    this.message,
    this.isRepeating = true,
    this.isActive = true,
    this.lastTriggered,
    this.nextTrigger,
    this.metadata,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final time = (json['time_of_day'] as String? ?? '12:00').split(':');
    return Reminder(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: json['user_id'],
      timeOfDay: TimeOfDay(
        hour: int.parse(time[0]),
        minute: int.parse(time[1]),
      ),
      frequency: _parseFrequency(json['frequency'] ?? 'daily'),
      type: _parseType(json['type'] ?? 'study'),
      lessonId: json['lesson_id'],
      title: json['title'],
      message: json['message'],
      isRepeating: json['is_repeating'] ?? true,
      isActive: json['is_active'] ?? true,
      lastTriggered: json['last_triggered'] != null
          ? DateTime.parse(json['last_triggered'])
          : null,
      nextTrigger: json['next_trigger'] != null
          ? DateTime.parse(json['next_trigger'])
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'time_of_day': '${timeOfDay.hour.toString().padLeft(2, '0')}:'
          '${timeOfDay.minute.toString().padLeft(2, '0')}',
      'frequency': _frequencyToString(frequency),
      'type': _typeToString(type),
      'lesson_id': lessonId,
      'title': title,
      'message': message,
      'is_repeating': isRepeating,
      'is_active': isActive,
      'last_triggered': lastTriggered?.toIso8601String(),
      'next_trigger': nextTrigger?.toIso8601String(),
      'metadata': metadata,
    };
  }

  static ReminderFrequency _parseFrequency(String value) {
    switch (value.toLowerCase()) {
      case 'weekly':
        return ReminderFrequency.weekly;
      case 'monthly':
        return ReminderFrequency.monthly;
      case 'daily':
      default:
        return ReminderFrequency.daily;
    }
  }

  static String _frequencyToString(ReminderFrequency frequency) {
    return frequency.toString().split('.').last;
  }

  static ReminderType _parseType(String value) {
    switch (value.toLowerCase()) {
      case 'lesson':
        return ReminderType.lesson;
      case 'goal':
        return ReminderType.goal;
      case 'custom':
        return ReminderType.custom;
      case 'study':
      default:
        return ReminderType.study;
    }
  }

  static String _typeToString(ReminderType type) {
    return type.toString().split('.').last;
  }

  Reminder copyWith({
    String? id,
    String? userId,
    TimeOfDay? timeOfDay,
    ReminderFrequency? frequency,
    ReminderType? type,
    String? lessonId,
    String? title,
    String? message,
    bool? isRepeating,
    bool? isActive,
    DateTime? lastTriggered,
    DateTime? nextTrigger,
    Map<String, dynamic>? metadata,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      frequency: frequency ?? this.frequency,
      type: type ?? this.type,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      message: message ?? this.message,
      isRepeating: isRepeating ?? this.isRepeating,
      isActive: isActive ?? this.isActive,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      nextTrigger: nextTrigger ?? this.nextTrigger,
      metadata: metadata ?? this.metadata,
    );
  }
}
