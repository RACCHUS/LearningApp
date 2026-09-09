import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/services/notification_service.dart';
import 'package:learning_pwa/models/reminder.dart';

class NotificationTestScreen extends ConsumerWidget {
  const NotificationTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationService = NotificationService();

    Future<void> scheduleTestNotification() async {
      final now = TimeOfDay.now();
      final inOneMinute = now.replacing(
        minute: (now.minute + 1) % 60,
        hour: now.hour + (now.minute + 1 >= 60 ? 1 : 0),
      );

      final reminder = Reminder(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'test_user',
        title: 'Test Notification',
        message: 'This is a test notification!',
        timeOfDay: inOneMinute,
        type: ReminderType.study,
        frequency: ReminderFrequency.daily,
        isActive: true,
        isRepeating: false,
      );

      try {
        await notificationService.scheduleStudyReminder(reminder);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test notification scheduled!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Testing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: scheduleTestNotification,
              child: const Text('Schedule Test Notification (1 min)'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Note: On web, notifications must be manually triggered\nand may require user interaction to show.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
