import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/progress_provider.dart';
import 'package:learning_pwa/models/user_progress.dart';

class ProgressDashboardScreen extends ConsumerWidget {
  static const int dailyGoal = 10;
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
          final today = DateTime.now();
          UserProgress? todayProgress;
          try {
            todayProgress = progressHistory.firstWhere(
              (p) => p.date.year == today.year && p.date.month == today.month && p.date.day == today.day,
            );
          } catch (_) {
            todayProgress = null;
          }
          final todayCount = todayProgress != null ? todayProgress.questionsAnswered : 0;
          return Column(
            children: [
              Text('Current Streak: $streak days'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Daily Goal: '),
                    Text('$todayCount/$dailyGoal',
                        style: TextStyle(
                          color: todayCount >= dailyGoal ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        )),
                    if (todayCount >= dailyGoal)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.check_circle, color: Colors.green),
                      ),
                  ],
                ),
              ),
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
