import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/providers/reminder_provider.dart';
import 'package:learning_pwa/widgets/empty_state.dart';
import 'package:learning_pwa/screens/_reminder_card.dart';

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({super.key});

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  @override
  void initState() {
    super.initState();
    // Load reminders when the screen is first shown
    Future.microtask(() => ref.read(reminderProvider.notifier).loadReminders());
  }

  String _formatFrequency(ReminderFrequency frequency) {
    switch (frequency) {
      case ReminderFrequency.daily:
        return 'Daily';
      case ReminderFrequency.weekly:
        return 'Weekly';
      case ReminderFrequency.monthly:
        return 'Monthly';
    }
  }

  String _formatType(ReminderType type) {
    switch (type) {
      case ReminderType.study:
        return 'Study';
      case ReminderType.lesson:
        return 'Lesson';
      case ReminderType.goal:
        return 'Goal';
      case ReminderType.custom:
        return 'Custom';
    }
  }

  Future<void> _showAddReminderDialog(
    BuildContext context,
    Reminder? existingReminder,
  ) async {
    final isEdit = existingReminder != null;
    final titleController = TextEditingController(
      text: isEdit ? existingReminder.title : 'Study Reminder',
    );
    final messageController = TextEditingController(
      text: isEdit ? existingReminder.message : "Time to study! Don't forget your daily learning goal.",
    );
    
    TimeOfDay selectedTime = isEdit 
        ? existingReminder.timeOfDay 
        : TimeOfDay.now().replacing(minute: 0);
    
    ReminderFrequency selectedFrequency = isEdit 
        ? existingReminder.frequency 
        : ReminderFrequency.daily;
    
    ReminderType selectedType = isEdit 
        ? existingReminder.type 
        : ReminderType.study;
    
    bool isRepeating = isEdit ? existingReminder.isRepeating : true;
    bool isActive = isEdit ? existingReminder.isActive : true;

    final result = await showDialog<Reminder?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Reminder' : 'Add New Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Message
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  
                  // Time Picker
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setState(() => selectedTime = time);
                      }
                    },
                  ),
                  
                  // Frequency
                  ListTile(
                    leading: const Icon(Icons.repeat_rounded),
                    title: const Text('Frequency'),
                    subtitle: Text(_formatFrequency(selectedFrequency)),
                    onTap: () async {
                      final result = await showDialog<ReminderFrequency>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Select Frequency'),
                          children: ReminderFrequency.values.map((frequency) {
                            return SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, frequency),
                              child: Text(_formatFrequency(frequency)),
                            );
                          }).toList(),
                        ),
                      );
                      if (result != null) {
                        setState(() => selectedFrequency = result);
                      }
                    },
                  ),
                  
                  // Type
                  ListTile(
                    leading: const Icon(Icons.category_rounded),
                    title: const Text('Type'),
                    subtitle: Text(_formatType(selectedType)),
                    onTap: () async {
                      final result = await showDialog<ReminderType>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Select Type'),
                          children: ReminderType.values.map((type) {
                            return SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, type),
                              child: Text(_formatType(type)),
                            );
                          }).toList(),
                        ),
                      );
                      if (result != null) {
                        setState(() => selectedType = result);
                      }
                    },
                  ),
                  
                  // Toggles
                  SwitchListTile(
                    value: isRepeating,
                    onChanged: (value) => setState(() => isRepeating = value),
                    title: const Text('Repeating'),
                    subtitle: const Text('Repeat this reminder'),
                  ),
                  
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value),
                    title: const Text('Active'),
                    subtitle: Text(isActive ? 'Enabled' : 'Disabled'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final reminder = Reminder(
                    id: isEdit ? existingReminder.id : DateTime.now().toString(),
                    userId: isEdit ? existingReminder.userId : '',
                    timeOfDay: selectedTime,
                    frequency: selectedFrequency,
                    type: selectedType,
                    title: titleController.text,
                    message: messageController.text,
                    isRepeating: isRepeating,
                    isActive: isActive,
                    lastTriggered: isEdit ? existingReminder.lastTriggered : null,
                    nextTrigger: isEdit ? existingReminder.nextTrigger : null,
                    metadata: isEdit ? existingReminder.metadata : null,
                  );
                  Navigator.pop(context, reminder);
                },
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      if (isEdit) {
        await ref.read(reminderProvider.notifier).updateReminder(result);
      } else {
        await ref.read(reminderProvider.notifier).addReminder(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminders = ref.watch(reminderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddReminderDialog(context, null),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(reminderProvider.notifier).loadReminders(),
        child: reminders.when(
          data: (reminders) {
            if (reminders.isEmpty) {
              return EmptyState(
                icon: Icons.notifications_off_rounded,
                title: 'No Reminders',
                message: 'Add a reminder to get notified about your study sessions',
                action: FilledButton.icon(
                  onPressed: () => _showAddReminderDialog(context, null),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Reminder'),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                return ReminderCard(reminder: reminder);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load reminders',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(reminderProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Reminder'),
      ),
    );
  }
}
