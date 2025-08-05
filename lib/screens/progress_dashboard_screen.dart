import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/progress_provider.dart';
import 'package:learning_pwa/providers/sync_provider.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:collection/collection.dart';

// Date formatting utility
String _formatDate(DateTime date) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[date.month - 1]} ${date.day}';
}

class ProgressDashboardScreen extends ConsumerStatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  ConsumerState<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends ConsumerState<ProgressDashboardScreen> {
  // Time range filter state (unused for now, will be implemented in a future update)
  // ignore: unused_field
  String _selectedTimeRange = 'week';
  static const List<String> _timeRanges = ['week', 'month', 'all'];
  
  // Daily goal constant (can be made configurable later)
  static const int dailyGoalMinutes = 30;
  
  @override
  void initState() {
    super.initState();
    // Pre-fetch progress data when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(progressHistoryProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressHistoryAsync = ref.watch(progressHistoryProvider);
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Progress'),
        actions: [
          // Manual sync button
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncProvider.notifier).syncData(),
            tooltip: 'Sync with server',
          ),
        ],
      ),
      // Show sync status at the bottom of the screen
      bottomNavigationBar: syncState.isLoading 
          ? const LinearProgressIndicator()
          : syncState.hasError
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.red[100],
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sync error: ${syncState.error}'.split('\n').first,
                          style: const TextStyle(color: Colors.red),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.read(syncProvider.notifier).syncData(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : null,
      body: progressHistoryAsync.when(
        data: (progressHistory) {
          final stats = _calculateStatistics(progressHistory);
          final streak = _calculateStreak(progressHistory.map((e) => e.date).toList());
          
          return RefreshIndicator(
            onRefresh: () => ref.refresh(progressHistoryProvider.future).then((_) {}),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Stats Overview Cards
                _buildStatsOverview(stats, streak),
                const SizedBox(height: 24),
                
                // Recent Activity
                _buildRecentActivity(progressHistory),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load progress data', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(progressHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Calculate statistics from progress data
  Map<String, dynamic> _calculateStatistics(List<UserProgress> progress) {
    if (progress.isEmpty) {
      return {
        'totalStudyTime': Duration.zero,
        'totalSessions': 0,
        'totalQuestions': 0,
        'averageAccuracy': 0.0,
        'daysActive': 0,
      };
    }
    
    final totalStudyTime = Duration(
      seconds: progress.fold(0, (sum, p) => sum + p.studyTimeSeconds),
    );
    
    final totalQuestions = progress.fold(0, (sum, p) => sum + p.questionsAnswered);
    final totalCorrect = progress.fold(0, (sum, p) => sum + p.correctCount);
    final averageAccuracy = totalQuestions > 0 ? totalCorrect / totalQuestions : 0;
    
    // Count unique days with activity
    final daysActive = progress.map((p) => '${p.date.year}-${p.date.month}-${p.date.day}').toSet().length;
    
    return {
      'totalStudyTime': totalStudyTime,
      'totalSessions': progress.length,
      'totalQuestions': totalQuestions,
      'averageAccuracy': averageAccuracy,
      'daysActive': daysActive,
    };
  }
  
  // Build stats overview cards
  Widget _buildStatsOverview(Map<String, dynamic> stats, int streak) {
    // Calculate daily goal progress
    final totalStudyMinutes = stats['totalStudyTime'].inMinutes;
    final dailyGoalProgress = totalStudyMinutes / dailyGoalMinutes;
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          'Study Time',
          '${stats['totalStudyTime'].inHours}h ${stats['totalStudyTime'].inMinutes.remainder(60)}m',
          Icons.timer,
          Colors.blue,
          subtitle: '${(dailyGoalProgress * 100).toStringAsFixed(0)}% of daily goal',
        ),
        _buildStatCard(
          'Sessions',
          '${stats['totalSessions']}',
          Icons.assignment_turned_in,
          Colors.green,
          subtitle: '${stats['daysActive']} active days',
        ),
        _buildStatCard(
          'Questions',
          '${stats['totalQuestions']}',
          Icons.quiz,
          Colors.orange,
          subtitle: '${(stats['averageAccuracy'] * 100).toStringAsFixed(0)}% accuracy',
        ),
        _buildStatCard(
          'Streak',
          '$streak ${streak == 1 ? 'day' : 'days'}' ,
          Icons.local_fire_department,
          Colors.red,
          subtitle: streak > 0 ? 'Keep it up!' : 'Start your streak today!',
        ),
      ],
    );
  }
  
  Widget _buildStatCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, {
    String? subtitle,
  }) {
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
                subtitle,
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
  
  // Build recent activity list
  Widget _buildRecentActivity(List<UserProgress> progress) {
    if (progress.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No recent activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Complete a lesson to see your progress here',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Group by date
    final groupedProgress = groupBy(progress, (p) => '${p.date.year}-${p.date.month}-${p.date.day}');
    final sortedDates = groupedProgress.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedTimeRange = value;
                    });
                  },
                  itemBuilder: (context) => _timeRanges
                      .map((range) => PopupMenuItem(
                            value: range,
                            child: Text(range[0].toUpperCase() + range.substring(1)),
                          ))
                      .toList(),
                  icon: const Icon(Icons.filter_alt, size: 20),
                  tooltip: 'Filter by time range',
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(5, sortedDates.length),
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final date = DateTime.parse(dateKey);
              final dailyProgress = groupedProgress[dateKey]!;
              
              final totalQuestions = dailyProgress.fold(0, (sum, p) => sum + p.questionsAnswered);
              final totalCorrect = dailyProgress.fold(0, (sum, p) => sum + p.correctCount);
              final totalTime = dailyProgress.fold(0, (sum, p) => sum + p.studyTimeSeconds);
              final accuracy = totalQuestions > 0 
                  ? (totalCorrect / totalQuestions * 100).round() 
                  : 0;
                  
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDate(date),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${dailyProgress.length} ${dailyProgress.length == 1 ? 'session' : 'sessions'}' ,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '$totalQuestions questions • ${totalTime ~/ 60}m',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$accuracy%',
                          style: TextStyle(
                            color: _getAccuracyColor(accuracy / 100),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'accuracy',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // TODO: Navigate to daily detail view
                    },
                  ),
                  if (index < min(5, sortedDates.length) - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            },
          ),
          if (progress.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () {
                  // TODO: Navigate to full activity log
                },
                child: const Text('View All Activity'),
              ),
            ),
        ],
      ),
    );
  }
  
  // Get color based on accuracy percentage
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }
  
  // Get icon for study mode (keeping for future use)
  // ignore: unused_element
  Icon _getStudyModeIcon(StudyMode mode) {
    switch (mode) {
      case StudyMode.flashcard:
        return const Icon(Icons.flash_on);
      case StudyMode.mcq:
        return const Icon(Icons.quiz);
      case StudyMode.concept:
        return const Icon(Icons.menu_book);
      case StudyMode.lesson:
        return const Icon(Icons.school);
    }
  }
  
  // Format time difference in a human-readable way (keeping for future use)
  // ignore: unused_element
  String _formatTimeDifference(Duration difference) {
    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    return 'Just now';
  }
  
  // Calculate streak
  int _calculateStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    
    // Sort dates in descending order
    dates.sort((a, b) => b.compareTo(a));
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    for (var date in dates) {
      // Reset time to compare only dates
      date = DateTime(date.year, date.month, date.day);
      final diff = currentDate.difference(date).inDays;
      
      if (diff == 0) {
        // Same day, continue
        continue;
      } else if (diff == 1) {
        // Consecutive day
        streak++;
        currentDate = date;
      } else if (diff > 1) {
        // Streak broken
        break;
      }
    }
    
    // If today's activity exists, add 1 to the streak
    final today = DateTime.now();
    final hasTodayActivity = dates.any((date) => 
      date.year == today.year && 
      date.month == today.month && 
      date.day == today.day
    );
    
    return hasTodayActivity ? streak + 1 : streak;
  }
}
