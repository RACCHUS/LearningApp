import 'package:flutter/material.dart';

class Reminder {
  final String id;
  final String userId;
  final TimeOfDay timeOfDay;
  final String frequency;
  final String mode;
  final int goalCount;
  final bool isActive;

  Reminder({
    required this.id,
    required this.userId,
    required this.timeOfDay,
    required this.frequency,
    required this.mode,
    required this.goalCount,
    required this.isActive,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final time = json['time_of_day'].split(':');
    return Reminder(
      id: json['id'],
      userId: json['user_id'],
      timeOfDay: TimeOfDay(hour: int.parse(time[0]), minute: int.parse(time[1])),
      frequency: json['frequency'],
      mode: json['mode'],
      goalCount: json['goal_count'],
      isActive: json['is_active'],
    );
  }
}
