import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/progress_provider.dart';

class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressHistoryAsync = ref.watch(progressHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Dashboard'),
      ),
      body: progressHistoryAsync.when(
        data: (progressHistory) {
          final streak = _calculateStreak(progressHistory.map((e) => e.date).toList());
          return Column(
            children: [
              Text('Current Streak: $streak days'),
              Expanded(
                child: ListView.builder(
                  itemCount: progressHistory.length,
                  itemBuilder: (context, index) {
                    final progress = progressHistory[index];
                    return ListTile(
                      title: Text('Lesson ID: ${progress.lessonId}'),
                      subtitle: Text(
                          '${progress.questionsAnswered} questions answered, ${progress.correctCount} correct'),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
      ),
    );
  }

  int _calculateStreak(List<DateTime> dates) {
    if (dates.isEmpty) {
      return 0;
    }
    int streak = 0;
    if(dates.isNotEmpty){
      streak = 1;
      DateTime lastDate = dates[0];
      for (int i = 1; i < dates.length; i++) {
        if (lastDate.difference(dates[i]).inDays == 1) {
          streak++;
          lastDate = dates[i];
        } else if (lastDate.difference(dates[i]).inDays > 1) {
          break;
        }
      }
    }
    return streak;
  }
}
