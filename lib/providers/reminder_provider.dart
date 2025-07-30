import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final reminderProvider = StateNotifierProvider<ReminderNotifier, AsyncValue<List<Reminder>>>((ref) {
  return ReminderNotifier();
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService();
});

class ReminderService {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();

  /// Get all reminders for the current user
  Future<List<Reminder>> getReminders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      final response = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', userId)
          .order('time_of_day', ascending: true);
          
      return (response as List).map((e) => Reminder.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
      rethrow;
    }
  }

  /// Create a new reminder
  Future<Reminder> createReminder(Reminder reminder) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      final reminderData = reminder.toJson()..['user_id'] = userId;
      final response = await _supabase
          .from('reminders')
          .insert(reminderData)
          .select()
          .single();
          
      return Reminder.fromJson(response);
    } catch (e) {
      debugPrint('Error creating reminder: $e');
      rethrow;
    }
  }

  /// Update an existing reminder
  Future<Reminder> updateReminder(Reminder reminder) async {
    try {
      final response = await _supabase
          .from('reminders')
          .update(reminder.toJson())
          .eq('id', reminder.id)
          .select()
          .single();
          
      return Reminder.fromJson(response);
    } catch (e) {
      debugPrint('Error updating reminder: $e');
      rethrow;
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String id) async {
    try {
      await _supabase
          .from('reminders')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      rethrow;
    }
  }

  /// Schedule a notification for a reminder
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    try {
      if (!reminder.isActive) return;
      
      await _notificationService.scheduleStudyReminder(reminder);
      
      // Update last scheduled time
      await updateReminder(reminder.copyWith(
        lastTriggered: DateTime.now(),
        nextTrigger: _calculateNextTrigger(reminder),
      ));
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
      await _notificationService.scheduleLessonReminder(
        lesson: lesson,
        scheduledTime: scheduledTime,
        customMessage: customMessage,
      );
    } catch (e) {
      debugPrint('Error scheduling lesson reminder: $e');
      rethrow;
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelScheduledNotification(String reminderId) async {
    try {
      await _notificationService.cancelNotification(reminderId.hashCode);
    } catch (e) {
      debugPrint('Error canceling notification: $e');
      rethrow;
    }
  }

  /// Calculate the next trigger time for a recurring reminder
  DateTime _calculateNextTrigger(Reminder reminder) {
    final now = DateTime.now();
    final time = reminder.timeOfDay;
    var nextTrigger = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for next occurrence
    if (nextTrigger.isBefore(now)) {
      nextTrigger = nextTrigger.add(const Duration(days: 1));
    }

    return nextTrigger;
  }
}

class ReminderNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  final ReminderService _reminderService;
  
  ReminderNotifier([ReminderService? reminderService]) 
      : _reminderService = reminderService ?? ReminderService(),
        super(const AsyncValue.loading()) {
    loadReminders();
  }

  Future<void> loadReminders() async {
    try {
      state = const AsyncValue.loading();
      final reminders = await _reminderService.getReminders();
      state = AsyncValue.data(reminders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Add a new reminder
  Future<void> addReminder(Reminder reminder) async {
    try {
      final newReminder = await _reminderService.createReminder(reminder);
      state.whenData((reminders) {
        state = AsyncValue.data([...reminders, newReminder]);
      });
      
      // Schedule the notification
      await _reminderService.scheduleReminderNotification(newReminder);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update an existing reminder
  Future<void> updateReminder(Reminder reminder) async {
    try {
      final updatedReminder = await _reminderService.updateReminder(reminder);
      state.whenData((reminders) {
        final index = reminders.indexWhere((r) => r.id == reminder.id);
        if (index != -1) {
          final newReminders = List<Reminder>.from(reminders);
          newReminders[index] = updatedReminder;
          state = AsyncValue.data(newReminders);
        }
      });
      
      // Reschedule the notification if active
      if (reminder.isActive) {
        await _reminderService.scheduleReminderNotification(updatedReminder);
      } else {
        await _reminderService.cancelScheduledNotification(reminder.id);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String id) async {
    try {
      await _reminderService.deleteReminder(id);
      state.whenData((reminders) {
        state = AsyncValue.data(reminders.where((r) => r.id != id).toList());
      });
      
      // Cancel any scheduled notifications
      await _reminderService.cancelScheduledNotification(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Toggle reminder active state
  Future<void> toggleReminder(String id, bool isActive) async {
    try {
      state.whenData((reminders) async {
        final reminder = reminders.firstWhere((r) => r.id == id);
        final updatedReminder = reminder.copyWith(isActive: isActive);
        
        await updateReminder(updatedReminder);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
      await _reminderService.scheduleLessonReminder(
        lesson: lesson,
        scheduledTime: scheduledTime,
        customMessage: customMessage,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
  
  /// Reschedule all active reminders
  Future<void> rescheduleAllReminders() async {
    try {
      final reminders = await _reminderService.getReminders();
      for (final reminder in reminders.where((r) => r.isActive)) {
        await _reminderService.scheduleReminderNotification(reminder);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
