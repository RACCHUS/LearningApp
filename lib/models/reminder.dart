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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'time_of_day': '${timeOfDay.hour}:${timeOfDay.minute}',
      'frequency': frequency,
      'mode': mode,
      'goal_count': goalCount,
      'is_active': isActive,
    };
  }

  Reminder copyWith({
    String? id,
    String? userId,
    TimeOfDay? timeOfDay,
    String? frequency,
    String? mode,
    int? goalCount,
    bool? isActive,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      frequency: frequency ?? this.frequency,
      mode: mode ?? this.mode,
      goalCount: goalCount ?? this.goalCount,
      isActive: isActive ?? this.isActive,
    );
  }
}
