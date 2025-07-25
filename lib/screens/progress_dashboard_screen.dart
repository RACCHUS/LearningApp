import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/progress_provider.dart';

class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressHistory = ref.watch(progressHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: progressHistory.when(
        data: (history) {
          final streak = _calculateStreak(history);
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Streak: $streak days',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  int _calculateStreak(List<dynamic> history) {
    if (history.isEmpty) {
      return 0;
    }

    int streak = 0;
    DateTime today = DateTime.now();
    DateTime lastDate = DateTime(today.year, today.month, today.day);

    for (var progress in history) {
      DateTime progressDate = DateTime(progress.date.year, progress.date.month, progress.date.day);
      if (progressDate == lastDate) {
        streak++;
        lastDate = lastDate.subtract(const Duration(days: 1));
      } else if (progressDate.isBefore(lastDate)) {
        break;
      }
    }

    return streak;
  }
}
