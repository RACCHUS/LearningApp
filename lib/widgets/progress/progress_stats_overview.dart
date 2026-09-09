import 'package:flutter/material.dart';
import 'progress_statistics.dart';

/// Progress stats overview widget
/// 
/// Displays key progress metrics in a grid of cards including
/// study time, sessions, questions answered, and learning streak.
class ProgressStatsOverview extends StatelessWidget {
  final Map<String, dynamic> statistics;
  final int streak;

  const ProgressStatsOverview({
    super.key,
    required this.statistics,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate daily goal progress
    final dailyGoalProgress = ProgressStatistics.calculateDailyGoalProgress(
      statistics['totalStudyTime']
    );
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        ProgressStatCard(
          title: 'Study Time',
          value: '${statistics['totalStudyTime'].inHours}h ${statistics['totalStudyTime'].inMinutes.remainder(60)}m',
          icon: Icons.timer,
          color: Colors.blue,
          subtitle: '${(dailyGoalProgress * 100).toStringAsFixed(0)}% of daily goal',
        ),
        ProgressStatCard(
          title: 'Sessions',
          value: '${statistics['totalSessions']}',
          icon: Icons.assignment_turned_in,
          color: Colors.green,
          subtitle: '${statistics['daysActive']} active days',
        ),
        ProgressStatCard(
          title: 'Questions',
          value: '${statistics['totalQuestions']}',
          icon: Icons.quiz,
          color: Colors.orange,
          subtitle: '${(statistics['averageAccuracy'] * 100).toStringAsFixed(0)}% accuracy',
        ),
        ProgressStatCard(
          title: 'Streak',
          value: '$streak ${streak == 1 ? 'day' : 'days'}',
          icon: Icons.local_fire_department,
          color: Colors.red,
          subtitle: streak > 0 ? 'Keep it up!' : 'Start your streak today!',
        ),
      ],
    );
  }
}

/// Individual progress stat card widget
class ProgressStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const ProgressStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10, 
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12, 
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
