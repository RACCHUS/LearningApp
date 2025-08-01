import 'package:flutter/material.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/reminder_provider.dart';

class ReminderCard extends ConsumerWidget {
  final Reminder reminder;
  
  const ReminderCard({
    required this.reminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showEditReminderDialog(context, reminder, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getReminderIcon(),
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reminder.title ?? 'Study Reminder',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Switch(
                    value: reminder.isActive,
                    onChanged: (value) => ref
                        .read(reminderProvider.notifier)
                        .toggleReminder(reminder.id, value),
                    activeColor: colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (reminder.message?.isNotEmpty ?? false) ...{
                Text(
                  reminder.message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              },
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${reminder.timeOfDay.format(context)} • ${_formatFrequency(reminder.frequency)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const Spacer(),
                  if (reminder.nextTrigger != null) ...{
                    Text(
                      'Next: ${_formatNextTrigger(reminder.nextTrigger!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  },
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getReminderIcon() {
    switch (reminder.type) {
      case ReminderType.lesson:
        return Icons.menu_book_rounded;
      case ReminderType.goal:
        return Icons.flag_rounded;
      case ReminderType.custom:
        return Icons.notifications_active_rounded;
      case ReminderType.study:
        return Icons.school_rounded;
    }
  }

  String _formatNextTrigger(DateTime nextTrigger) {
    final now = DateTime.now();
    final difference = nextTrigger.difference(now);
    
    if (difference.inDays > 0) {
      return 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Now';
    }
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

  Future<void> _showEditReminderDialog(
    BuildContext context,
    Reminder reminder,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Reminder?>(
      context: context,
      builder: (context) => _ReminderDialog(reminder: reminder),
    );

    if (result != null) {
      await ref.read(reminderProvider.notifier).updateReminder(result);
    }
  }
}

class _ReminderDialog extends StatefulWidget {
  final Reminder reminder;

  const _ReminderDialog({required this.reminder});

  @override
  _ReminderDialogState createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late TimeOfDay _selectedTime;
  late ReminderFrequency _selectedFrequency;
  late ReminderType _selectedType;
  late bool _isRepeating;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _messageController = TextEditingController(text: widget.reminder.message);
    _selectedTime = widget.reminder.timeOfDay;
    _selectedFrequency = widget.reminder.frequency;
    _selectedType = widget.reminder.type;
    _isRepeating = widget.reminder.isRepeating;
    _isActive = widget.reminder.isActive;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reminder.id.isEmpty ? 'Add Reminder' : 'Edit Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.access_time_rounded),
              title: const Text('Time'),
              subtitle: Text(_selectedTime.format(context)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() => _selectedTime = time);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Frequency'),
              subtitle: Text(_formatFrequency(_selectedFrequency)),
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
                  setState(() => _selectedFrequency = result);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('Type'),
              subtitle: Text(_formatType(_selectedType)),
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
                  setState(() => _selectedType = result);
                }
              },
            ),
            SwitchListTile(
              value: _isRepeating,
              onChanged: (value) => setState(() => _isRepeating = value),
              title: const Text('Repeating'),
              subtitle: const Text('Repeat this reminder'),
            ),
            SwitchListTile(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text('Active'),
              subtitle: Text(_isActive ? 'Enabled' : 'Disabled'),
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
            final updatedReminder = widget.reminder.copyWith(
              title: _titleController.text,
              message: _messageController.text,
              timeOfDay: _selectedTime,
              frequency: _selectedFrequency,
              type: _selectedType,
              isRepeating: _isRepeating,
              isActive: _isActive,
            );
            Navigator.pop(context, updatedReminder);
          },
          child: Text(widget.reminder.id.isEmpty ? 'Add' : 'Save'),
        ),
      ],
    );
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
        return 'Study Session';
      case ReminderType.lesson:
        return 'Lesson';
      case ReminderType.goal:
        return 'Goal Check-in';
      case ReminderType.custom:
        return 'Custom';
    }
  }
}
