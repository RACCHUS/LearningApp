import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/reminder_provider.dart';

class ReminderScreen extends ConsumerWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Show a dialog to add a new reminder
            },
          ),
        ],
      ),
      body: reminders.when(
        data: (reminders) {
          return ListView.builder(
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              return ListTile(
                title: Text(
                    '${reminder.mode} reminder at ${reminder.timeOfDay.format(context)}'),
                subtitle: Text(
                    'Goal: ${reminder.goalCount}, Frequency: ${reminder.frequency}'),
                trailing: Switch(
                  value: reminder.isActive,
                  onChanged: (value) {
                    ref.read(reminderProvider.notifier).toggleReminder(reminder.id, value);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
