import 'package:learning_pwa/models/lesson_progress.dart';

/// Progress statistics calculator utility
/// 
/// Provides static methods for calculating various progress metrics
/// from user progress data.
class ProgressStatistics {
  static const int dailyGoalMinutes = 30;
  
  /// Calculate comprehensive statistics from progress data
  static Map<String, dynamic> calculateStatistics(List<UserProgress> progress) {
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
    final daysActive = progress
        .map((p) => '${p.date.year}-${p.date.month}-${p.date.day}')
        .toSet()
        .length;
    
    return {
      'totalStudyTime': totalStudyTime,
      'totalSessions': progress.length,
      'totalQuestions': totalQuestions,
      'averageAccuracy': averageAccuracy,
      'daysActive': daysActive,
    };
  }
  
  /// Calculate learning streak from a list of dates
  static int calculateStreak(List<DateTime> dates) {
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
  
  /// Calculate daily goal progress percentage
  static double calculateDailyGoalProgress(Duration totalStudyTime) {
    return totalStudyTime.inMinutes / dailyGoalMinutes;
  }
}
