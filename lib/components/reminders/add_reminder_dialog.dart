import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/reminder.dart';

class AddReminderDialog extends ConsumerStatefulWidget {
  final Reminder? existingReminder;

  const AddReminderDialog({super.key, this.existingReminder});

  @override
  ConsumerState<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends ConsumerState<AddReminderDialog> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  TimeOfDay selectedTime = TimeOfDay.now().replacing(minute: 0);
  ReminderFrequency selectedFrequency = ReminderFrequency.daily;
  ReminderType selectedType = ReminderType.study;
  bool isRepeating = true;
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingReminder != null) {
      final reminder = widget.existingReminder!;
      titleController.text = reminder.title ?? '';
      messageController.text = reminder.message ?? '';
      selectedTime = reminder.timeOfDay;
      selectedFrequency = reminder.frequency;
      selectedType = reminder.type;
      isRepeating = reminder.isRepeating;
      isActive = reminder.isActive;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingReminder != null;

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
              id: isEdit ? widget.existingReminder!.id : DateTime.now().toString(),
              userId: isEdit ? widget.existingReminder!.userId : '',
              timeOfDay: selectedTime,
              frequency: selectedFrequency,
              type: selectedType,
              title: titleController.text,
              message: messageController.text,
              isRepeating: isRepeating,
              isActive: isActive,
              lastTriggered: isEdit ? widget.existingReminder!.lastTriggered : null,
              nextTrigger: isEdit ? widget.existingReminder!.nextTrigger : null,
              metadata: isEdit ? widget.existingReminder!.metadata : null,
            );
            Navigator.pop(context, reminder);
          },
          child: Text(isEdit ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
