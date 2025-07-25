import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final reminderProvider = StateNotifierProvider<ReminderNotifier, AsyncValue<List<Reminder>>>((ref) {
  return ReminderNotifier();
});

class ReminderNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  ReminderNotifier() : super(const AsyncValue.loading()) {
    _getReminders();
  }

  final _supabase = Supabase.instance.client;

  Future<void> _getReminders() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', userId);
      final reminders = (response as List).map((e) => Reminder.fromJson(e)).toList();
      state = AsyncValue.data(reminders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    try {
      final response = await _supabase.from('reminders').insert(reminder.toJson()).select();
      final newReminder = Reminder.fromJson(response[0]);
      state.whenData((reminders) => state = AsyncValue.data([...reminders, newReminder]));
    } catch (e, st) {
      // handle error
    }
  }

  Future<void> toggleReminder(String reminderId, bool isActive) async {
    try {
      await _supabase
          .from('reminders')
          .update({'is_active': isActive})
          .eq('id', reminderId);
      state.whenData((reminders) {
        final index = reminders.indexWhere((element) => element.id == reminderId);
        final newReminders = [...reminders];
        newReminders[index] = newReminders[index].copyWith(isActive: isActive);
        state = AsyncValue.data(newReminders);
      });
    } catch (e, st) {
      // handle error
    }
  }
}
