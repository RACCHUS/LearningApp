import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/providers/reminder_provider.dart';

class _FakeReminderService implements ReminderService {
  final List<Reminder> _items;
  bool shouldThrow = false;

  _FakeReminderService(this._items);

  @override
  Future<Reminder> createReminder(Reminder reminder) async {
    _items.add(reminder);
    return reminder;
  }

  @override
  Future<void> deleteReminder(String id) async {
    _items.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<Reminder>> getReminders() async {
    if (shouldThrow) throw Exception('load failed');
    return _items;
  }

  @override
  Future<void> scheduleLessonReminder({required lesson, required scheduledTime, String? customMessage}) async {}

  @override
  Future<void> scheduleReminderNotification(Reminder reminder) async {}

  @override
  Future<void> cancelScheduledNotification(String reminderId) async {}

  @override
  Future<Reminder> updateReminder(Reminder reminder) async {
    final index = _items.indexWhere((r) => r.id == reminder.id);
    if (index != -1) _items[index] = reminder;
    return reminder;
  }

  // Removed unused _calculateNextTrigger method
}

void main() {
  group('ReminderProvider Tests', () {
    late ProviderContainer container;
    late _FakeReminderService fakeService;

    setUp(() {
      fakeService = _FakeReminderService([
        Reminder(
          id: 'r1',
          userId: 'u1',
          timeOfDay: const TimeOfDay(hour: 9, minute: 0),
          title: 'Study',
          message: 'Time to study',
        )
      ]);

      container = ProviderContainer(
        overrides: [
          reminderProvider.overrideWith((ref) => ReminderNotifier(fakeService)),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial load resolves to data state', () async {
      // Wait until state.hasValue is true or timeout after 1 second
      AsyncValue<List<Reminder>> state;
      var waited = 0;
      do {
        await Future.delayed(const Duration(milliseconds: 10));
        state = container.read(reminderProvider);
        waited += 10;
      } while (!state.hasValue && waited < 1000);

      expect(state.hasValue, true);
      expect(state.value, isNotNull);
      expect(state.value!.length, 1);
    });

    test('addReminder appends data and schedules', () async {
      final notifier = container.read(reminderProvider.notifier);
      final newReminder = Reminder(
        id: 'r2',
        userId: 'u1',
        timeOfDay: const TimeOfDay(hour: 10, minute: 0),
        title: 'Another',
      );

      await notifier.addReminder(newReminder);
      final state = container.read(reminderProvider);

      expect(state.hasValue, true);
      expect(state.value!.any((r) => r.id == 'r2'), isTrue);
    });

    test('error state when service throws', () async {
      fakeService.shouldThrow = true;
      final notifier = container.read(reminderProvider.notifier);

      await notifier.loadReminders();
      final state = container.read(reminderProvider);

      expect(state.hasError, true);
    });
  });
}

